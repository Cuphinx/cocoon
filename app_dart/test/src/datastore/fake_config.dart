// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:appengine/appengine.dart';
import 'package:cocoon_service/cocoon_service.dart';
import 'package:cocoon_service/src/model/appengine/key_helper.dart';
import 'package:cocoon_service/src/service/bigquery.dart';
import 'package:cocoon_service/src/service/github_service.dart';
import 'package:cocoon_service/src/service/luci_build_service/cipd_version.dart';
import 'package:github/github.dart' as gh;
import 'package:graphql/client.dart';

import '../request_handling/fake_dashboard_authentication.dart';
import '../service/fake_github_service.dart';
import 'fake_datastore.dart';

// ignore: must_be_immutable
// TODO(matanlurey): Make this *not* a mess. See https://github.com/flutter/flutter/issues/164646.
class FakeConfig implements Config {
  FakeConfig({
    this.githubClient,
    this.maxTaskRetriesValue,
    this.maxLuciTaskRetriesValue,
    this.maxFilesChangedForSkippingEnginePhaseValue,
    this.keyHelperValue,
    this.oauthClientIdValue,
    this.githubOAuthTokenValue,
    this.mergeConflictPullRequestMessageValue =
        'default mergeConflictPullRequestMessageValue',
    this.missingTestsPullRequestMessageValue =
        'default missingTestsPullRequestMessageValue',
    this.wrongBaseBranchPullRequestMessageValue,
    this.wrongHeadBranchPullRequestMessageValue,
    this.releaseBranchPullRequestMessageValue,
    this.webhookKeyValue,
    this.loggingServiceValue,
    this.githubService,
    this.bigqueryService,
    this.firestoreService,
    this.githubGraphQLClient,
    this.rollerAccountsValue,
    this.flutterBuildValue,
    this.flutterBuildDescriptionValue,
    this.maxRecordsValue,
    this.flutterGoldPendingValue,
    this.flutterGoldSuccessValue,
    this.flutterGoldChangesValue,
    this.flutterGoldAlertConstantValue,
    this.flutterGoldInitialAlertValue,
    this.flutterGoldFollowUpAlertValue,
    this.flutterGoldDraftChangeValue,
    this.flutterGoldStalePRValue,
    this.releaseBranchesValue,
    this.releaseCandidateBranchPathValue,
    this.postsubmitSupportedReposValue,
    this.supportedBranchesValue,
    this.supportedReposValue,
    this.batchSizeValue,
    this.backfillerTargetLimitValue,
    this.backfillerCommitLimitValue,
    this.issueAndPRLimitValue,
    this.githubRequestDelayValue,
    FakeDatastoreDB? dbValue,
  }) : dbValue = dbValue ?? FakeDatastoreDB();

  gh.GitHub? githubClient;
  GraphQLClient? githubGraphQLClient;
  BigqueryService? bigqueryService;
  FirestoreService? firestoreService;
  GithubService? githubService;
  FakeDatastoreDB dbValue;
  int? maxTaskRetriesValue;
  int? maxFilesChangedForSkippingEnginePhaseValue;
  int? maxLuciTaskRetriesValue;
  int? batchSizeValue;
  FakeKeyHelper? keyHelperValue;
  String? oauthClientIdValue;
  String? githubOAuthTokenValue;
  String mergeConflictPullRequestMessageValue;
  String missingTestsPullRequestMessageValue;
  String? wrongBaseBranchPullRequestMessageValue;
  String? wrongHeadBranchPullRequestMessageValue;
  String? releaseBranchPullRequestMessageValue;
  String? webhookKeyValue;
  String? flutterBuildValue;
  String? flutterBuildDescriptionValue;
  Logging? loggingServiceValue;
  String? waitingForTreeToGoGreenLabelNameValue;
  List<String>? releaseBranchesValue;
  String? releaseCandidateBranchPathValue;
  Set<String>? rollerAccountsValue;
  int? maxRecordsValue;
  int? backfillerTargetLimitValue;
  int? backfillerCommitLimitValue;
  int? issueAndPRLimitValue;
  String? flutterGoldPendingValue;
  String? flutterGoldSuccessValue;
  String? flutterGoldChangesValue;
  String? flutterGoldAlertConstantValue;
  String? flutterGoldInitialAlertValue;
  String? flutterGoldFollowUpAlertValue;
  String? flutterGoldDraftChangeValue;
  String? flutterGoldStalePRValue;
  List<String>? supportedBranchesValue;
  Set<gh.RepositorySlug>? supportedReposValue;
  Set<gh.RepositorySlug>? postsubmitSupportedReposValue;
  Duration? githubRequestDelayValue;

  @override
  Future<bool> get useLegacyDatastore async => true;

  @override
  Future<gh.GitHub> createGitHubClient({
    gh.PullRequest? pullRequest,
    gh.RepositorySlug? slug,
  }) async => githubClient!;

  @override
  gh.GitHub createGitHubClientWithToken(String token) => githubClient!;

  @override
  Future<GraphQLClient> createGitHubGraphQLClient() async =>
      githubGraphQLClient!;

  @override
  Future<BigqueryService> createBigQueryService() async => bigqueryService!;

  @override
  Future<FirestoreService> createFirestoreService() async => firestoreService!;

  @override
  Future<GithubService> createGithubService(gh.RepositorySlug slug) async =>
      githubService ?? FakeGithubService();

  @override
  GithubService createGithubServiceWithToken(String token) => githubService!;

  @override
  FakeDatastoreDB get db => dbValue;

  @override
  Duration get githubRequestDelay => githubRequestDelayValue ?? Duration.zero;

  /// Size of the shards to send to buildBucket when scheduling builds.
  @override
  int get schedulingShardSize => 5;

  @override
  int get backfillerTargetLimit => backfillerTargetLimitValue ?? 50;

  @override
  int get backfillerCommitLimit => backfillerCommitLimitValue ?? 50;

  @override
  int get issueAndPRLimit => issueAndPRLimitValue ?? 2;

  @override
  int get batchSize => batchSizeValue ?? 5;

  @override
  int get maxFilesChangedForSkippingEnginePhase =>
      maxFilesChangedForSkippingEnginePhaseValue!;

  @override
  int get maxLuciTaskRetries => maxLuciTaskRetriesValue!;

  @override
  int get maxRecords => maxRecordsValue!;

  @override
  String get flutterGoldPending => flutterGoldPendingValue!;

  @override
  String get flutterGoldSuccess => flutterGoldSuccessValue!;

  @override
  String get flutterGoldChanges => flutterGoldChangesValue!;

  @override
  String get flutterGoldDraftChange => flutterGoldDraftChangeValue!;

  @override
  String get flutterGoldStalePR => flutterGoldStalePRValue!;

  @override
  String flutterGoldInitialAlert(String url) => flutterGoldInitialAlertValue!;

  @override
  String flutterGoldFollowUpAlert(String url) => flutterGoldFollowUpAlertValue!;

  @override
  String flutterGoldAlertConstant(gh.RepositorySlug slug) =>
      flutterGoldAlertConstantValue!;

  @override
  String flutterGoldCommentID(gh.PullRequest pr) =>
      'PR ${pr.number}, at ${pr.head!.sha}';

  @override
  Future<String> get frobWebhookKey async => 'frob-webhook-key';

  @override
  int get commitNumber => 30;

  @override
  KeyHelper get keyHelper => keyHelperValue!;

  @override
  Future<String> get oauthClientId async => oauthClientIdValue!;

  @override
  Future<String> get githubOAuthToken async => githubOAuthTokenValue ?? 'token';

  @override
  String get mergeConflictPullRequestMessage =>
      mergeConflictPullRequestMessageValue;

  @override
  String get missingTestsPullRequestMessage =>
      missingTestsPullRequestMessageValue;

  @override
  String get wrongBaseBranchPullRequestMessage =>
      wrongBaseBranchPullRequestMessageValue!;

  @override
  String wrongHeadBranchPullRequestMessage(String branch) =>
      wrongHeadBranchPullRequestMessageValue!;

  @override
  String get releaseBranchPullRequestMessage =>
      releaseBranchPullRequestMessageValue!;

  @override
  Future<String> get webhookKey async => webhookKeyValue!;

  @override
  String get flutterBuild => flutterBuildValue!;

  @override
  String get flutterTreeStatusRed =>
      flutterBuildDescriptionValue ??
      'Tree is currently broken. Please do not merge this '
          'PR unless it contains a fix for the tree.';
  @override
  String get flutterTreeStatusEmergency =>
      'The tree is currently broken; however, this PR is marked as `emergency` and will be allowed to merge.';

  @override
  Logging get loggingService => loggingServiceValue!;

  @override
  String get waitingForTreeToGoGreenLabelName =>
      waitingForTreeToGoGreenLabelNameValue!;

  @override
  Set<String> get rollerAccounts => rollerAccountsValue!;

  @override
  Future<String> generateGithubToken(gh.RepositorySlug slug) {
    throw UnimplementedError();
  }

  @override
  Future<String> generateJsonWebToken() {
    throw UnimplementedError();
  }

  @override
  Future<String> get githubAppId => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> get githubAppInstallations =>
      throw UnimplementedError();

  @override
  Future<String> get githubPrivateKey => throw UnimplementedError();

  @override
  Future<String> get githubPublicKey => throw UnimplementedError();

  @override
  Future<GithubService> createDefaultGitHubService() async => githubService!;

  @override
  CipdVersion get defaultRecipeBundleRef => const CipdVersion(branch: 'main');

  @override
  List<String> get releaseBranches => releaseBranchesValue!;

  @override
  String get releaseCandidateBranchPath => releaseCandidateBranchPathValue!;

  @override
  Future<List<String>> get releaseAccounts async => <String>[
    'dart-flutter-releaser',
  ];

  @override
  Set<gh.RepositorySlug> get supportedRepos =>
      supportedReposValue ??
      <gh.RepositorySlug>{
        Config.flutterSlug,
        Config.cocoonSlug,
        Config.packagesSlug,
      };

  @override
  Set<gh.RepositorySlug> get postsubmitSupportedRepos =>
      postsubmitSupportedReposValue ?? <gh.RepositorySlug>{Config.packagesSlug};

  @override
  String get autosubmitBot => 'auto-submit[bot]';

  static const String revertOfLabel = 'revert of';

  @override
  Future<String> get discordTreeStatusWebhookUrl async =>
      'https://discord.com/api/webhooks/1234/abcd';
}
