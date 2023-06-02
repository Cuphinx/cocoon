// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cocoon_service/cocoon_service.dart';
import 'package:cocoon_service/src/model/appengine/commit.dart';
import 'package:cocoon_service/src/model/appengine/task.dart';
import 'package:cocoon_service/src/model/luci/buildbucket.dart';
import 'package:cocoon_service/src/model/luci/push_message.dart' as push;
import 'package:cocoon_service/src/service/datastore.dart';
import 'package:gcloud/db.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../src/datastore/fake_config.dart';
import '../src/request_handling/fake_authentication.dart';
import '../src/request_handling/fake_http.dart';
import '../src/request_handling/subscription_tester.dart';
import '../src/utilities/entity_generators.dart';
import '../src/utilities/mocks.dart';

void main() {
  late DartInternalSubscription handler;
  late FakeConfig config;
  late FakeHttpRequest request;
  late MockBuildBucketClient buildBucketClient;
  late SubscriptionTester tester;
  late Commit commit;
  final DateTime startTime = DateTime(2023, 1, 1, 0, 0, 0);
  final DateTime endTime = DateTime(2023, 1, 1, 0, 14, 23);
  const String project = "flutter";
  const String bucket = "try";
  const String builder = "Mac amazing_builder_tests";
  const int buildId = 123456;

  setUp(() async {
    config = FakeConfig();
    buildBucketClient = MockBuildBucketClient();
    handler = DartInternalSubscription(
      cache: CacheService(inMemory: true),
      config: config,
      authProvider: FakeAuthenticationProvider(),
      buildBucketClient: buildBucketClient,
      datastoreProvider: (DatastoreDB db) => DatastoreService(config.db, 5),
    );
    request = FakeHttpRequest();

    tester = SubscriptionTester(
      request: request,
    );

    commit = generateCommit(
      1,
      sha: "HASH12345",
      branch: "test-branch",
      owner: "flutter",
      repo: "flutter",
      timestamp: 0,
    );

    final Build fakeBuild = Build(
      builderId:
          const BuilderId(project: project, bucket: bucket, builder: builder),
      number: buildId,
      id: 'fake-build-id',
      status: Status.success,
      startTime: startTime,
      endTime: endTime,
      input: const Input(
        gitilesCommit: GitilesCommit(
          project: "flutter/flutter",
          hash: "HASH12345",
          ref: "refs/heads/test-branch",
        ),
      ),
    );
    when(
      buildBucketClient.getBuild(
        any,
        buildBucketUri:
            "https://cr-buildbucket.appspot.com/prpc/buildbucket.v2.Builds",
      ),
    ).thenAnswer((_) => Future<Build>.value(fakeBuild));

    final List<Commit> datastoreCommit = <Commit>[commit];
    await config.db.commit(inserts: datastoreCommit);
  });

  test('runs successfully', () async {
    tester.message = push.PushMessage(data: "'${buildId.toString()}'");

    await tester.post(handler);

    verify(
      buildBucketClient.getBuild(any),
    ).called(1);

    // This is used for testing to pull the data out of the "datastore" so that
    // we can verify what was saved.
    final List<Task> tasksInDb = [];
    late Commit commitInDb;
    config.db.values.forEach((k, v) {
      if (v is Task) {
        tasksInDb.add(v);
      }
      if (v is Commit) {
        commitInDb = v;
      }
    });

    expect(
      tasksInDb.length,
      equals(1),
    );

    final Task taskInDb = tasksInDb[0];

    // Ensure the task has the correct parent and commit key
    expect(
      commitInDb.id,
      equals(taskInDb.commitKey?.id),
    );

    expect(
      commitInDb.id,
      equals(taskInDb.parentKey?.id),
    );

    // Ensure the task in the db is exactly what we are looking for
    final Task expectedTask = Task(
      attempts: 1,
      buildNumber: 123456,
      buildNumberList: "123456".toString(),
      builderName: builder,
      commitKey: commitInDb.key,
      createTimestamp: startTime.millisecondsSinceEpoch,
      endTimestamp: endTime.millisecondsSinceEpoch,
      luciBucket: bucket,
      name: builder,
      stageName: "dart-internal",
      startTimestamp: startTime.millisecondsSinceEpoch,
      status: "Succeeded",
      key: commit.key.append(Task),
      timeoutInMinutes: 0,
      reason: '',
      requiredCapabilities: [],
      reservedForAgentId: ''
    );

    print(taskInDb.toString());

    expect(
      taskInDb.toString(),
      equals(expectedTask.toString()),
    );
  });
}
