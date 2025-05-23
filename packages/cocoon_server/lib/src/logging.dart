// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cocoon_common/cocoon_common.dart';
// ignore: invalid_use_of_internal_member, implementation_imports
import 'package:cocoon_common/src/internal.dart' as internal;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// A root application logger using the interface in `package:logging`.
///
/// This is being migrated to [log], which uses a new interface. See
/// [#164652](https://github.com/flutter/flutter/issues/164652).
final _rootLegacyLogger = Logger.root..level = Level.ALL;

/// A root application logger using the interface in `package:cocoon_common`.
LogSink get log => _log;
LogSink _log = const DuringMigrationLogSink();

/// Changes the default implementation of [log].
///
/// This can all be called in a testing environment.
void overrideLog2ForTesting(LogSink logSink) {
  if (!internal.assertionsEnabled) {
    throw StateError('Can only use in a test or local development');
  }
  _log = logSink;
}

/// A narrow shim on top of [LogSink] that delegates to [log].
///
/// Used as the default implementation of [log]. See
/// [#164652](https://github.com/flutter/flutter/issues/164652).
@visibleForTesting
final class DuringMigrationLogSink with LogSink {
  const DuringMigrationLogSink();

  static Level _toLevel(Severity severity) {
    return switch (severity) {
      Severity.unknown || Severity.debug => Level.FINE,
      Severity.info || Severity.notice => Level.INFO,
      Severity.warning => Level.WARNING,
      Severity.error ||
      Severity.critical ||
      Severity.alert ||
      Severity.emergency => Level.SEVERE,
    };
  }

  @override
  void log(
    String message, {
    Severity severity = Severity.info,
    Object? error,
    StackTrace? trace,
  }) {
    _rootLegacyLogger.log(_toLevel(severity), message, error, trace);
  }
}
