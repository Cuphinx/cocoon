// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'backfill_strategy.dart';
library;

import 'dart:collection';
import 'dart:convert';

import 'package:cocoon_common/task_status.dart';
import 'package:meta/meta.dart';

import '../../model/ci_yaml/target.dart';
import '../../model/commit_ref.dart';
import '../../model/task_ref.dart';
import '../../service/luci_build_service/pending_task.dart';
import '../../service/scheduler/policy.dart';

/// An indexed grid-like mutable view of the last recent N commits and M tasks.
///
/// It is the primary input to [BackfillStrategy].
///
/// Some common tasks are performed for every grid, independent of a strategy:
/// - Tasks (& targets) are removed that do not exist at tip-of-tree[^1];
/// - Tasks (& targets) are removed that do not use backfilling ([BatchPolicy]);
///
/// [^1]: The latest commit in the default branch of the current repository.
final class BackfillGrid {
  /// Creates an indexed data structure from the provided `(commit, [tasks])`.
  ///
  /// Some automatic filtering is applied, removing targets/tasks where:
  /// - [postsubmitTargets] that does not use [BatchPolicy];
  /// - [postsubmitTargets] without a task;
  /// - task that does have a matching [postsubmitTargets].
  factory BackfillGrid.from(
    Iterable<(CommitRef, List<TaskRef>)> grid, {
    required Iterable<Target> postsubmitTargets,
  }) {
    final totTargetsByName = {for (final t in postsubmitTargets) t.name: t};
    final commitsByName = <String, CommitRef>{};
    final tasksByName = <String, List<TaskRef>>{};
    for (final (commit, tasks) in grid) {
      commitsByName[commit.sha] = commit;
      for (final task in tasks) {
        (tasksByName[task.name] ??= []).add(task);
        // Must exist at ToT (in this Map) and must be BatchPolicy.
        if (totTargetsByName[task.name]?.schedulerPolicy is! BatchPolicy) {
          // Even if it existed, let's remove it at this point because it is no
          // longer relevant to the BackfillGrid, and if there are future API
          // changes to the class it shouldn't show up.
          totTargetsByName.remove(task.name);
          continue;
        }
      }
    }

    // Final filtering step: remove empty targets/tasks.
    tasksByName.removeWhere((_, tasks) => tasks.isEmpty);
    totTargetsByName.removeWhere((name, _) => !tasksByName.containsKey(name));

    return BackfillGrid._(commitsByName, totTargetsByName, tasksByName);
  }

  BackfillGrid._(
    this._commitsBySha, //
    this._targetsByName,
    this._tasksByName,
  );

  final Map<String, CommitRef> _commitsBySha;
  final Map<String, List<TaskRef>> _tasksByName;
  final Map<String, Target> _targetsByName;

  /// Returns the cooresponding commit for the given [task].
  CommitRef getCommit(TaskRef task) {
    final commit = _commitsBySha[task.commitSha];
    if (commit == null) {
      throw ArgumentError.value(
        task,
        'task',
        'No commit for task "${task.name}',
      );
    }
    return commit;
  }

  /// Returns a [BackfillTask] with the provided LUCI scheduling [priority].
  ///
  /// If [task] does not originate from [eligibleTasks] the behavior is undefined.
  @useResult
  BackfillTask createBackfillTask(TaskRef task, {required int priority}) {
    final target = _targetsByName[task.name];
    if (target == null) {
      throw ArgumentError.value(
        task,
        'task',
        'No target for task "${task.name}',
      );
    }
    final commit = _commitsBySha[task.commitSha];
    if (commit == null) {
      throw ArgumentError.value(
        task,
        'task',
        'No commit for task "${task.name}',
      );
    }
    return BackfillTask._from(
      task,
      target: target,
      commit: commit,
      priority: priority,
    );
  }

  /// Removes a task column from the grid for which [predicate] returns `true`.
  void removeColumnWhere(bool Function(List<TaskRef>) predicate) {
    return _tasksByName.removeWhere((_, tasks) {
      return predicate(UnmodifiableListView(tasks));
    });
  }

  @useResult
  Target? _validateColumnAndTarget(String name, List<TaskRef> column) {
    if (column.isEmpty) {
      throw StateError('A target ("$name") should never have 0 tasks');
    }
    return _targetsByName[name];
  }

  /// Each task, ordered by column (task by task).
  ///
  /// Returned [TaskRef]s are eligible to be used in [createBackfillTask].
  Iterable<(Target, List<TaskRef>)> get eligibleTasks sync* {
    for (final MapEntry(key: name, value: column) in _tasksByName.entries) {
      final target = _validateColumnAndTarget(name, column);
      if (target != null && target.backfill) {
        yield (target, column);
      }
    }
  }

  /// Each task, ordered by column (task by task).
  ///
  /// Returned tasks are not to be backfilled, and should be marked skipped.
  Iterable<SkippableTask> get skippableTasks sync* {
    for (final MapEntry(key: name, value: column) in _tasksByName.entries) {
      final target = _validateColumnAndTarget(name, column);
      if (target?.backfill == true) {
        continue;
      }
      for (final task in column) {
        if (task.status != TaskStatus.waitingForBackfill) {
          continue;
        }
        final commit = _commitsBySha[task.commitSha];
        if (commit == null) {
          throw StateError(
            'A commit ("${task.commitSha}") should have existed in the grid',
          );
        }
        yield SkippableTask._from(task, commit: commit);
      }
    }
  }

  @override
  String toString() {
    return 'BackfillGrid ${const JsonEncoder.withIndent('  ').convert({
      'eligibleTasks': '${[...eligibleTasks]}', //
      'skippableTasks': '${[...skippableTasks]}',
    })}';
  }
}

/// A proposed task to be scheduled as part of the backfill process.
@immutable
final class BackfillTask {
  const BackfillTask._from(
    this.task, {
    required this.target,
    required this.commit,
    required this.priority,
  });

  /// The task itself.
  final TaskRef task;

  /// Which [Target] (originating from `.ci.yaml`) defined this task.
  final Target target;

  /// The commit this task is associated with.
  final CommitRef commit;

  /// The LUCI scheduling priority of backfilling this task.
  final int priority;

  /// Creates a copy of `this` with the provided properties replaced.
  @useResult
  BackfillTask copyWith({int? priority}) {
    return BackfillTask._from(
      task,
      target: target,
      commit: commit,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() {
    return 'BackfillTask ${const JsonEncoder.withIndent('  ').convert({
      'task': '$task', //
      'target': '$target',
      'commit': '$commit',
      'priority': priority,
    })}';
  }

  /// Converts to a [PendingTask].
  PendingTask toPendingTask() {
    return PendingTask(
      target: target,
      taskName: task.name,
      priority: priority,
      currentAttempt: task.currentAttempt,
    );
  }
}

/// A proposed task to be skipped as part of the backfill process.
@immutable
final class SkippableTask {
  const SkippableTask._from(this.task, {required this.commit});

  /// The task itself.
  final TaskRef task;

  /// The commit this task is associated with.
  final CommitRef commit;

  @override
  String toString() {
    return 'SkippableTask ${const JsonEncoder.withIndent('  ').convert({
      'task': '$task', //
      'commit': '$commit',
    })}';
  }
}
