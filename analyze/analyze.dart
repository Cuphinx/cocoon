// Copyright 2020 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as path;

const FileSystem fs = LocalFileSystem();

// Cocoon's root is the parent of the current working directory,
final Directory cocoonRoot = fs.currentDirectory.parent;

Future<void> main(List<String> arguments) async {
  print('STARTING ANALYSIS');
  print('cocoonRoot: ${cocoonRoot.path}');
  await run(arguments);
  print('Analysis successful.');
}

Future<void> run(List<String> arguments) async {
  var assertsEnabled = false;
  assert(() {
    assertsEnabled = true;
    return true;
  }());
  if (!assertsEnabled) {
    exitWithError(<String>[
      'The analyze.dart script must be run with --enable-asserts.',
    ]);
  }

  print('Executable allowlist...');
  await _checkForNewExecutables();

  print('Proto analysis...');
  await verifyProtos(cocoonRoot);
}

// TESTS

Future<void> verifyProtos(Directory workingDirectory) async {
  final errors = <String>[];
  final protos =
      await _allFiles(
        workingDirectory.path,
        'proto',
        minimumMatches: 1,
      ).toList();
  for (final proto in protos) {
    final content = proto.readAsStringSync();
    if (!content.contains(RegExp(r'package\ \w+;'))) {
      errors.add(
        '${proto.path} requires a package (https://protobuf.dev/programming-guides/proto2/#packages)',
      );
    }
  }

  if (errors.isNotEmpty) {
    exitWithError(<String>[
      'The following files are missing package declarations:',
      ...errors,
    ]);
  }
}

// UTILITY FUNCTIONS

Future<List<File>> _gitFiles(
  String workingDirectory, {
  bool runSilently = true,
}) async {
  final evalResult = await _evalCommand(
    'git',
    <String>['ls-files', '-z'],
    workingDirectory: workingDirectory,
    runSilently: runSilently,
  );
  if (evalResult.exitCode != 0) {
    exitWithError(<String>[
      'git ls-files failed with exit code ${evalResult.exitCode}',
      'stdout:',
      evalResult.stdout,
      'stderr:',
      evalResult.stderr,
    ]);
  }
  final filenames = evalResult.stdout.split('\x00');
  assert(filenames.last.isEmpty); // git ls-files gives a trailing blank 0x00
  filenames.removeLast();
  return filenames
      .map<File>(
        (String filename) => fs.file(path.join(workingDirectory, filename)),
      )
      .toList();
}

Stream<File> _allFiles(
  String workingDirectory,
  String? extension, {
  required int minimumMatches,
}) async* {
  final gitFileNamesSet = <String>{};
  gitFileNamesSet.addAll(
    (await _gitFiles(
      workingDirectory,
    )).map((File f) => path.canonicalize(f.absolute.path)),
  );

  assert(
    extension == null || !extension.startsWith('.'),
    'Extension argument should not start with a period.',
  );
  final pending = <FileSystemEntity>{fs.directory(workingDirectory)};
  var matches = 0;
  while (pending.isNotEmpty) {
    final entity = pending.first;
    pending.remove(entity);
    if (path.extension(entity.path) == '.tmpl') continue;
    if (entity is File) {
      if (!gitFileNamesSet.contains(path.canonicalize(entity.absolute.path))) {
        continue;
      }
      if (path.basename(entity.path) == 'flutter_export_environment.sh') {
        continue;
      }
      if (path.basename(entity.path) == 'gradlew.bat') continue;
      if (path.basename(entity.path) == '.DS_Store') continue;
      if (extension == null || path.extension(entity.path) == '.$extension') {
        matches += 1;
        yield entity;
      }
    } else if (entity is Directory) {
      if (fs.file(path.join(entity.path, '.dartignore')).existsSync()) continue;
      if (path.basename(entity.path) == '.git') continue;
      if (path.basename(entity.path) == '.idea') continue;
      if (path.basename(entity.path) == '.gradle') continue;
      if (path.basename(entity.path) == '.dart_tool') continue;
      if (path.basename(entity.path) == '.idea') continue;
      if (path.basename(entity.path) == 'build') continue;
      pending.addAll(entity.listSync());
    }
  }
  assert(
    matches >= minimumMatches,
    'Expected to find at least $minimumMatches files with extension ".$extension" in "$workingDirectory", but only found $matches.',
  );
}

class EvalResult {
  EvalResult({required this.stdout, required this.stderr, this.exitCode = 0});

  final String stdout;
  final String stderr;
  final int exitCode;
}

Future<EvalResult> _evalCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  Map<String, String>? environment,
  bool allowNonZeroExit = false,
  bool runSilently = false,
}) async {
  final commandDescription =
      '${path.relative(executable, from: workingDirectory)} ${arguments.join(' ')}';
  final relativeWorkingDir = path.relative(workingDirectory);

  if (!runSilently) {
    print('RUNNING $relativeWorkingDir $commandDescription');
  }

  final time = Stopwatch()..start();
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );

  final savedStdout = process.stdout.toList();
  final savedStderr = process.stderr.toList();
  final exitCode = await process.exitCode;
  final result = EvalResult(
    stdout: utf8.decode(
      (await savedStdout).expand<int>((List<int> ints) => ints).toList(),
    ),
    stderr: utf8.decode(
      (await savedStderr).expand<int>((List<int> ints) => ints).toList(),
    ),
    exitCode: exitCode,
  );

  if (!runSilently) {
    print(
      'ELAPSED TIME: ${time.elapsed} for $commandDescription in $relativeWorkingDir',
    );
  }

  if (exitCode != 0 && !allowNonZeroExit) {
    stderr.write(result.stderr);
    exitWithError(<String>[
      'ERROR: Last command exited with $exitCode.',
      'Command: $commandDescription',
      'Relative working directory: $relativeWorkingDir',
    ]);
  }

  return result;
}

// These files legitimately require executable permissions
const Set<String> kExecutableAllowlist = <String>{
  'app_dart/tool/build.sh',
  'cipd_packages/codesign/tool/build.sh',
  'cipd_packages/device_doctor/tool/build.sh',
  'cipd_packages/doxygen/tool/build.sh',
  'cloud_build/dashboard_build.sh',
  'cloud_build/deploy_app_dart.sh',
  'cloud_build/deploy_auto_submit.sh',
  'cloud_build/deploy_cron_jobs.sh',
  'cloud_build/get_docker_image_provenance.sh',
  'cloud_build/verify_provenance.sh',
  'dev/provision_salt.sh',
  'dev/prs_to_main.sh',
  'packages/buildbucket-dart/tool/regenerate.sh',
  'test_utilities/bin/analyze.sh',
  'test_utilities/bin/code_health_check.sh',
  'test_utilities/bin/config_test_runner.sh',
  'test_utilities/bin/dart_test_runner.sh',
  'test_utilities/bin/flutter_test_runner.sh',
  'test_utilities/bin/licenses.sh',
  'test_utilities/bin/prepare_environment.sh',
};

const String kShebangRegex = r'#!/usr/bin/env (bash|sh)';

Future<void> _checkForNewExecutables() async {
  // 0b001001001
  const executableBitMask = 0x49;
  final files = await _gitFiles(cocoonRoot.path);
  final relativePaths =
      files.map<String>((File file) {
        return path.relative(file.path, from: cocoonRoot.path);
      }).toList();
  for (var allowed in kExecutableAllowlist) {
    if (!relativePaths.contains(allowed)) {
      throw Exception(
        'File $allowed in kExecutableAllowlist in analyze/analyze.dart '
        'does not exist. Please fix path or remove from kExecutableAllowlist.',
      );
    }
  }
  var unexpectedExecutableCount = 0;
  var unexpectedShebangShellCount = 0;
  for (final file in files) {
    final relativePath = path.relative(file.path, from: cocoonRoot.path);
    final stat = file.statSync();
    final isExecutable = stat.mode & executableBitMask != 0x0;
    final inAllowList = kExecutableAllowlist.contains(relativePath);
    if (isExecutable && !inAllowList) {
      unexpectedExecutableCount += 1;
      print(
        '$relativePath is executable: ${(stat.mode & 0x1FF).toRadixString(2)}',
      );
    }
    if (inAllowList && file.path.endsWith('.sh')) {
      final shebang = file.readAsLinesSync().first;
      if (!shebang.startsWith(RegExp(kShebangRegex))) {
        unexpectedShebangShellCount += 1;
        print(
          "$relativePath has the initial line of $shebang, which doesn't match '$kShebangRegex'",
        );
      }
    }
  }
  if (unexpectedExecutableCount > 0) {
    throw Exception(
      'found $unexpectedExecutableCount unexpected executable file'
      '${unexpectedExecutableCount == 1 ? '' : 's'}! If this was intended, you '
      'must add this file to kExecutableAllowlist in analyze/analyze.dart',
    );
  }
  if (unexpectedShebangShellCount > 0) {
    throw Exception(
      'found $unexpectedShebangShellCount unexpected shell #! line'
      '${unexpectedShebangShellCount == 1 ? '' : 's'}! If this was intended, you '
      'must modify kShebangRegex in analyze/analyze.dart',
    );
  }
}

void exitWithError(List<String> messages) {
  final line = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  print(line);
  messages.forEach(print);
  print(line);
  exit(1);
}
