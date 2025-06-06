// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:cocoon_common/core_extensions.dart';
import 'package:cocoon_common/task_status.dart';
import 'package:cocoon_server/logging.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';

import '../../../cocoon_service.dart';
import '../../model/ci_yaml/ci_yaml.dart';
import '../../model/firestore/task.dart' as fs;
import '../../request_handling/exceptions.dart';
import '../../service/firestore/commit_and_tasks.dart';
import '../../service/luci_build_service/pending_task.dart';
import '../../service/scheduler/ci_yaml_fetcher.dart';
import '../../service/scheduler/policy.dart';
import 'backfill_grid.dart';
import 'backfill_strategy.dart';

/// Cron request handler for scheduling targets when capacity becomes available.
///
/// Targets that have a [BatchPolicy] need to have backfilling enabled to ensure that ToT is always being tested.
@immutable
final class BatchBackfiller extends RequestHandler {
  /// Creates a subscription for sending BuildBucket requests.
  const BatchBackfiller({
    required super.config,
    required CiYamlFetcher ciYamlFetcher,
    required LuciBuildService luciBuildService,
    required FirestoreService firestore,
    BackfillStrategy backfillerStrategy = const DefaultBackfillStrategy(),
    @visibleForTesting DateTime Function() now = DateTime.now,
  }) : _ciYamlFetcher = ciYamlFetcher,
       _luciBuildService = luciBuildService,
       _backfillerStrategy = backfillerStrategy,
       _firestore = firestore,
       _now = now;

  final LuciBuildService _luciBuildService;
  final CiYamlFetcher _ciYamlFetcher;
  final BackfillStrategy _backfillerStrategy;
  final FirestoreService _firestore;
  final DateTime Function() _now;

  @override
  Future<Response> get(Request request) async {
    log.debug('Finding all branches eligible for backfilling');
    final branches = <(RepositorySlug, String)>{};
    for (final repo in config.supportedRepos) {
      // Always include the default branch.
      final defaultBranch = Config.defaultBranch(repo);
      branches.add((repo, defaultBranch));

      // Look for any branch that has received a commit in the last 7 days.
      final commits = await _firestore.queryRecentCommits(
        slug: repo,
        limit: null,
        created: TimeRange.after(_now().subtract(const Duration(days: 7))),
      );
      for (final commit in commits) {
        branches.add((repo, commit.branch));
      }
    }

    log.debug(
      'Found ${branches.length} branches eligible for backfilling:\n'
      '${branches.join('\n')}',
    );

    await Future.forEach(branches, (branch) async {
      final (slug, branchName) = branch;
      log.debug('Backfilling ${slug.fullName} -> $branchName');
      await _doBackfillFrom(
        slug,
        await _firestore.queryRecentCommitsAndTasks(
          slug,
          commitLimit: config.flags.backfillerCommitLimit,
          branch: branchName,
        ),
      );
    });
    return Response.json({
      'branches': [...branches.map((e) => '$e')],
    });
  }

  Future<void> _doBackfillFrom(
    RepositorySlug slug,
    List<CommitAndTasks> fsGrid, {
    bool forceLowPriority = false,
  }) async {
    if (fsGrid.isEmpty) {
      log.info('No commits to backfill');
      return;
    }

    // Fetch and build a "grid" of List<(OpaqueCommit, List<OpaqueTask>>).
    final BackfillGrid grid;
    {
      log.debug(
        'Fetched ${fsGrid.length} commits and '
        '${fsGrid.map((i) => i.tasks).expand((i) => i).length} tasks',
      );

      // Download the current commits targets.
      final currentCiYaml = await _ciYamlFetcher.getCiYamlByCommit(
        fsGrid.first.commit,
        postsubmit: true,
      );
      final currentTargets = [
        ...currentCiYaml.postsubmitTargets(),
        if (currentCiYaml.isFusion)
          ...currentCiYaml.postsubmitTargets(type: CiType.fusionEngine),
      ];
      if (currentTargets.isEmpty) {
        log.warn('Did not fetch any targets. Backfill will do nothing!');
      } else {
        log.debug('Fetched ${currentTargets.length} targets');
      }

      grid = BackfillGrid.from([
        for (final CommitAndTasks(:commit, :tasks) in fsGrid)
          (commit, [...tasks.map((t) => t.toRef())]),
      ], postsubmitTargets: currentTargets);
    }
    log.debug('Built a grid of ${grid.eligibleTasks.length} target columns');

    // Produce a list of tasks, ordered from highest to lowest, to backfill.
    // ... but only take the top N tasks, at most.
    final toBackfillTasks = _backfillerStrategy.determineBackfill(grid);
    final beforePruning = toBackfillTasks.length;

    // Reduce the list to at most the backfill capacity.
    ///
    // Note this doesn't do exactly what it seems - it just means *per API call*
    // we at most consider this many targets, not that we limit ourselves to
    // that many targets running at once. For example, even with a capacity of
    // 75, we can run 150+ targets, the first API call will be 75, the next one
    // 75 more, and so on.
    toBackfillTasks.length = min(
      toBackfillTasks.length,
      config.backfillerTargetLimit,
    );
    log.debug(
      'Backfilling ${toBackfillTasks.length} tasks (pruned from $beforePruning)',
    );

    if (forceLowPriority) {
      log.debug('Overriding ${toBackfillTasks.length} tasks to low priority');
      for (var i = 0; i < toBackfillTasks.length; i++) {
        toBackfillTasks[i] = toBackfillTasks[i].copyWith(
          priority: LuciBuildService.kBackfillPriority,
        );
      }
    }

    // Update the database first before we schedule builds.
    await _updateFirestore(toBackfillTasks, grid.skippableTasks);
    log.info('Wrote updates to ${toBackfillTasks.length} tasks for backfill');

    await _scheduleWithRetries(toBackfillTasks);
    log.info('Scheduled ${toBackfillTasks.length} tasks with LUCI');
  }

  Future<void> _updateFirestore(
    Iterable<BackfillTask> schedule,
    Iterable<SkippableTask> skip,
  ) async {
    log.debug('Querying ${schedule.length} tasks in Firestore...');
    await _firestore.writeViaTransaction([
      ...schedule.map((toUpdate) {
        final BackfillTask(:task) = toUpdate;
        return fs.Task.patchStatus(
          fs.TaskId(
            commitSha: task.commitSha,
            taskName: task.name,
            currentAttempt: task.currentAttempt,
          ),
          TaskStatus.inProgress,
        );
      }),
      ...skip.map((toSkip) {
        final SkippableTask(:task) = toSkip;
        return fs.Task.patchStatus(
          fs.TaskId(
            commitSha: task.commitSha,
            taskName: task.name,
            currentAttempt: task.currentAttempt,
          ),
          TaskStatus.skipped,
        );
      }),
    ]);
    log.debug('Wrote to Firestore for backfill');
  }

  /// Schedules tasks with retry when hitting pub/sub server errors.
  Future<void> _scheduleWithRetries(List<BackfillTask> backfill) async {
    const retryOptions = Config.schedulerRetry;
    try {
      await retryOptions.retry(() async {
        if (await Future.wait(_backfillRequestList(backfill))
            case final pendingTasks
            when pendingTasks.any((pending) => pending.isNotEmpty)) {
          final didNotBackfill = pendingTasks.where(
            (element) => element.isNotEmpty,
          );
          log.info(
            'Backfill fails and retry backfilling ${didNotBackfill.length} targets.',
          );
          backfill = _updateBackfill(backfill, pendingTasks);
          throw InternalServerError(
            'Failed to backfill ${backfill.length} targets.',
          );
        }
      }, retryIf: (e) => e is InternalServerError);
    } catch (e, s) {
      log.error(
        'Failed to backfill ${backfill.length} targets due to error',
        e,
        s,
      );
      rethrow;
    }
  }

  /// Updates the [backfill] list with those that fail to get scheduled.
  ///
  /// [tupleLists] maintains the same tuple order as those in [backfill].
  /// Each element from [backfill] is encapsulated as a list in [tupleLists] to prepare for
  /// [scheduler.luciBuildService.schedulePostsubmitBuilds].
  List<BackfillTask> _updateBackfill(
    List<BackfillTask> backfill,
    List<List<PendingTask>> tupleLists,
  ) {
    final updatedBackfill = <BackfillTask>[];
    for (var i = 0; i < tupleLists.length; i++) {
      if (tupleLists[i].isNotEmpty) {
        updatedBackfill.add(backfill[i]);
      }
    }
    return updatedBackfill;
  }

  /// Creates a list of backfill requests.
  @useResult
  List<Future<List<PendingTask>>> _backfillRequestList(
    List<BackfillTask> backfill,
  ) {
    return [
      for (final item in backfill)
        _luciBuildService.schedulePostsubmitBuilds(
          commit: item.commit,
          toBeScheduled: [item.toPendingTask()],
        ),
    ];
  }
}
