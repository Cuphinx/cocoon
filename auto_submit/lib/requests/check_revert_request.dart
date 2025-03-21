// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:cocoon_server/logging.dart';
import 'package:shelf/shelf.dart';

import '../request_handling/pubsub.dart';
import '../service/approver_service.dart';
import '../service/revert_request_validation_service.dart';
import 'check_request.dart';
import 'github_pull_request_event.dart';

/// Handler for processing pull requests with 'revert' label.
///
/// For pull requests where an 'revert' label was added in pubsub,
/// check if the revert request is mergable.
class CheckRevertRequest extends CheckRequest {
  const CheckRevertRequest({
    required super.config,
    required super.cronAuthProvider,
    super.approverProvider = ApproverService.defaultProvider,
    super.pubsub = const PubSub(),
  });

  @override
  Future<Response> get() async {
    /// Currently this is unused and cannot be called.
    return process(
      config.pubsubRevertRequestSubscription,
      config.kPubsubPullNumber,
      config.kPullMesssageBatchSize,
    );
  }

  /// Process pull request messages from Pubsub.
  Future<Response> process(
    String pubSubSubscription,
    int pubSubPulls,
    int pubSubBatchSize,
  ) async {
    final processingLog = <int>{};
    final messageList = await pullMessages(
      pubSubSubscription,
      pubSubPulls,
      pubSubBatchSize,
    );
    if (messageList.isEmpty) {
      log.info('No messages are pulled.');
      return Response.ok('No messages are pulled.');
    }

    log.info('Processing ${messageList.length} messages');

    final validationService = RevertRequestValidationService(config);

    final futures = <Future<void>>[];

    for (var message in messageList) {
      log.info('${message.toJson()}');
      assert(message.message != null);
      assert(message.message!.data != null);
      final messageData = message.message!.data!;

      final rawBody =
          json.decode(String.fromCharCodes(base64.decode(messageData)))
              as Map<String, dynamic>;

      final githubPullRequestEvent = GithubPullRequestEvent.fromJson(rawBody);
      final pullRequest = githubPullRequestEvent.pullRequest!;

      log.info('Processing message ackId: ${message.ackId}');
      log.info('Processing mesageId: ${message.message!.messageId}');
      log.info('Processing PR: $rawBody');
      if (processingLog.contains(pullRequest.number) ||
          githubPullRequestEvent.action != 'labeled') {
        // Ack duplicate.
        log.info('Ack the duplicated message : ${message.ackId!}.');
        log.info('duplicate pull request #${pullRequest.number}');
        await pubsub.acknowledge(pubSubSubscription, message.ackId!);
        continue;
      } else {
        // Use the auto approval as we do not want to allow non bot reverts to
        // be processed throught the service.
        log.info('new pull request #${pullRequest.number}');
        if (pullRequest.labels!.any((element) => element.name == 'revert of')) {
          final approver = approverProvider(config);
          log.info(
            'Checking auto approval of "revert of" pull request: $rawBody',
          );
          await approver.autoApproval(pullRequest);
        } else {
          // These should be closed requests that do not need to be reviewed.
          log.info('Processing "revert" request : ${pullRequest.number}.');
        }
        processingLog.add(pullRequest.number!);
      }

      futures.add(
        validationService.processMessage(
          githubPullRequestEvent,
          message.ackId!,
          pubsub,
        ),
      );
    }
    await Future.wait(futures);
    return Response.ok('Finished processing changes');
  }
}
