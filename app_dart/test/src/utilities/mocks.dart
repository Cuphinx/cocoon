// Copyright 2020 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:cocoon_service/src/foundation/github_checks_util.dart';
import 'package:cocoon_service/src/request_handlers/github/webhook_subscription.dart';
import 'package:cocoon_service/src/service/access_token_provider.dart';
import 'package:cocoon_service/src/service/big_query.dart';
import 'package:cocoon_service/src/service/branch_service.dart';
import 'package:cocoon_service/src/service/build_bucket_client.dart';
import 'package:cocoon_service/src/service/commit_service.dart';
import 'package:cocoon_service/src/service/config.dart';
import 'package:cocoon_service/src/service/discord_service.dart';
import 'package:cocoon_service/src/service/github_checks_service.dart';
import 'package:cocoon_service/src/service/github_service.dart';
import 'package:cocoon_service/src/service/luci_build_service.dart';
import 'package:github/github.dart';
import 'package:googleapis/bigquery/v2.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:graphql/client.dart';
import 'package:mockito/annotations.dart';
import 'package:neat_cache/neat_cache.dart';
import 'package:process/process.dart';

import '../../service/cache_service_test.dart';

export 'mocks.mocks.dart';

@GenerateMocks(
  <Type>[
    AccessTokenService,
    BigQueryService,
    BranchService,
    BuildBucketClient,
    CommitService,
    Config,
    DiscordService,
    FakeEntry,
    IssuesService,
    GithubChecksService,
    GithubChecksUtil,
    GithubService,
    GitService,
    GraphQLClient,
    HttpClient,
    HttpClientRequest,
    HttpClientResponse,
    LuciBuildService,
    ProcessManager,
    SearchService,
    TabledataResource,
    UsersService,
    ProjectsDatabasesDocumentsResource,
    BeginTransactionResponse,
    PullRequestLabelProcessor,
  ],
  customMocks: [
    MockSpec<Cache<Uint8List>>(),
    // MockSpec<GitHub>(
    //   fallbackGenerators: <Symbol, Function>{
    //     #postJSON: postJsonShim,
    //   },
    // ),
  ],
)
void main() {}

// ignore: unreachable_from_main
class ThrowingGitHub implements GitHub {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw AssertionError();
}
