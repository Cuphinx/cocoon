// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cocoon_service/src/model/luci/buildbucket.dart';
import 'package:gcloud/db.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';
import 'package:retry/retry.dart';

import '../../cocoon_service.dart';
import '../model/appengine/task.dart';
import '../model/appengine/commit.dart';
import '../request_handling/exceptions.dart';
import '../request_handling/subscription_handler.dart';
import '../service/datastore.dart';
import '../service/exceptions.dart';
import '../service/logging.dart';

/// An endpoint for listening to build updates for dart-internal builds and
/// saving the results to the datastore.
///
/// The PubSub subscription is set up here:
/// https://console.cloud.google.com/cloudpubsub/subscription/detail/dart-internal-build-results-sub?project=flutter-dashboard
@immutable
class DartInternalSubscription extends SubscriptionHandler {
  /// Creates an endpoint for listening for dart-internal build results.
  /// The message should contain a single buildbucket id
  const DartInternalSubscription({
    required super.cache,
    required super.config,
    super.authProvider,
    required this.buildBucketClient,
    @visibleForTesting
        this.datastoreProvider = DatastoreService.defaultProvider,
    this.retryOptions = Config.buildbucketRetry,
  }) : super(subscriptionName: 'dart-internal-build-results-sub');

  final BuildBucketClient buildBucketClient;
  final DatastoreServiceProvider datastoreProvider;
  final RetryOptions retryOptions;

  @override
  Future<Body> post() async {
    final DatastoreService datastore = datastoreProvider(config.db);

    log.info("Converting message data to non nullable int");

    final int buildbucketId = int.parse(message.data.toString().replaceAll("'", ""));

    log.info("Creating build request object");
    final GetBuildRequest request = GetBuildRequest(id: buildbucketId.toString());

    log.info(
      "Calling buildbucket api to get build data for build $buildbucketId",
    );
    late Build build;
    try {
      build = await retryOptions.retry(
        () async {
          return _getBuildFromBuildbucket(request);
        },
        retryIf: (Exception e) => e is UnfinishedBuildException,
      );
    } catch (e) {
      if (e is! UnfinishedBuildException)
      {
        log.severe(
        "Failed to get build data for build $buildbucketId with the exception: ${e.toString()}",
        );
        throw InternalServerError(
          'Failed to get build number $buildbucketId from Buildbucket. Error: $e',
        );

      }
    }

    log.info("Creating Task from Buildbucket result");
    final Task task = await _createTaskFromBuildbucketResult(build, datastore);

    log.fine(task.toString());
    log.info("Inserting Task into the datastore");
    // TODO(drewroengoogle): Uncomment this once we are completely
    // ready to publish the task into the datastore.
    // await datastore.insert(<Task>[task]);

    return Body.forJson(task.toString());
  }

  Future<Build> _getBuildFromBuildbucket(
    GetBuildRequest request,
  ) async {
    late Build build;
    build = await buildBucketClient.getBuild(request);

    if (build.endTime == null)
    {
      log.info(
        "Build is not yet complete",
      );
      throw UnfinishedBuildException("Build is not yet complete",);
    }
    return build;
  }

  Future<Task> _createTaskFromBuildbucketResult(
    Build build,
    DatastoreService datastore,
  ) async {
    log.fine("Build Result: ${build.toString()}");

    final String repository =
        build.input!.gitilesCommit!.project!.split('/')[1];
    log.fine("Repository: $repository");

    final String branch = build.input!.gitilesCommit!.ref!.split('/')[2];
    log.fine("Branch: $branch");

    final String hash = build.input!.gitilesCommit!.hash!;
    log.fine("Hash: $hash");

    final RepositorySlug slug = RepositorySlug("flutter", repository);
    log.fine("Slug: ${slug.toString()}");

    final int startTime = build.startTime != null ? build.startTime!.millisecondsSinceEpoch : 0;
    final int endTime = build.endTime != null ? build.endTime!.millisecondsSinceEpoch : 0;
    log.fine("Start/end time (ms): $startTime, $endTime");

    final Key<String> key = Commit.createKey(
      db: datastore.db,
      slug: slug,
      gitBranch: branch,
      sha: hash,
    );

    final String id = 'flutter/${slug.name}/$branch/$hash';
    final Key<String> commitKey =
        datastore.db.emptyKey.append<String>(Commit, id: id);
    final Commit commit = await config.db.lookupValue<Commit>(commitKey);
    final task = Task(
      buildNumber: build.number,
      buildNumberList: build.number.toString(),
      builderName: build.builderId.builder,
      commitKey: key,
      createTimestamp: startTime,
      endTimestamp: endTime,
      luciBucket: build.builderId.bucket,
      name: build.builderId.builder,
      stageName: "dart-internal",
      startTimestamp: startTime,
      status: _convertStatusToString(build.status!),
      key: commit.key.append(Task),
    );
    return task;
  }

  String _convertStatusToString(Status status) {
    switch (status) {
      case Status.success:
        return Task.statusSucceeded;
      case Status.canceled:
        return Task.statusCancelled;
      case Status.infraFailure:
        return Task.statusInfraFailure;
      default:
        return Task.statusFailed;
    }
  }
}
