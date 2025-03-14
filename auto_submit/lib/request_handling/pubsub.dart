// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:cocoon_server/logging.dart';
import 'package:googleapis/pubsub/v1.dart' as pubsub;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';

import '../foundation/providers.dart';
import '../foundation/typedefs.dart';
import '../service/config.dart';

/// Service class for interacting with PubSub.
class PubSub {
  const PubSub({this.httpClientProvider = Providers.freshHttpClient});

  final HttpClientProvider httpClientProvider;

  /// Adds one message to the topic.
  Future<void> publish(String topic, dynamic json) async {
    final Client httpClient = await clientViaApplicationDefaultCredentials(
      scopes: <String>[pubsub.PubsubApi.pubsubScope],
    );
    final pubsubApi = pubsub.PubsubApi(httpClient);
    final messageData = jsonEncode(json);
    final List<int> messageBytes = utf8.encode(messageData);
    final messageBase64 = base64Encode(messageBytes);
    final request = pubsub.PublishRequest(
      messages: <pubsub.PubsubMessage>[
        pubsub.PubsubMessage(data: messageBase64),
      ],
    );
    final fullTopicName = '${Config.pubsubTopicsPrefix}/$topic';
    final response = await pubsubApi.projects.topics.publish(
      request,
      fullTopicName,
    );
    log.info('pubsub response messageId=${response.messageIds}');
  }

  /// Pulls messages from the server.
  Future<pubsub.PullResponse> pull(String subscription, int maxMessages) async {
    final Client httpClient = await clientViaApplicationDefaultCredentials(
      scopes: <String>[pubsub.PubsubApi.pubsubScope],
    );
    final pubsubApi = pubsub.PubsubApi(httpClient);
    final pullRequest = pubsub.PullRequest(maxMessages: maxMessages);
    final pullResponse = await pubsubApi.projects.subscriptions.pull(
      pullRequest,
      '${Config.pubsubSubscriptionsPrefix}/$subscription',
    );
    return pullResponse;
  }

  /// Acknowledges the messages associated with the `ack_ids` in the `AcknowledgeRequest`.
  ///
  /// The PubSub system can remove the relevant messages from the subscription.
  Future<void> acknowledge(String subscription, String ackId) async {
    final Client httpClient = await clientViaApplicationDefaultCredentials(
      scopes: <String>[pubsub.PubsubApi.pubsubScope],
    );
    final pubsubApi = pubsub.PubsubApi(httpClient);
    final ackIds = <String>[ackId];
    final acknowledgeRequest = pubsub.AcknowledgeRequest(ackIds: ackIds);
    await pubsubApi.projects.subscriptions.acknowledge(
      acknowledgeRequest,
      '${Config.pubsubSubscriptionsPrefix}/$subscription',
    );
  }
}
