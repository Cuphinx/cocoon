#!/usr/bin/env bash
# Copyright 2019 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Runner for dart tests. It expects a single parameter with the full
# path to the start folder where tests will be run.

set -euo pipefail

echo "###### dart_test_runner #######"
echo "Directory: $1"

if [ -z "$1" ]; then
  echo "ERROR: no package directory supplied."
  echo "usage: $0 PACKAGE_DIR_TO_TEST"
  exit 1
fi

# Setup.
pushd "$1" >/dev/null
flutter clean
dart pub get

# TODO(drewroengoogle): Validate proto code has been generated. https://github.com/flutter/flutter/issues/115473

echo "######### dart format #########"
dart format --set-exit-if-changed .

echo "########### analyze ###########"
dart analyze --fatal-infos

# Only try tests if test folder exist.
if [ -d 'test' ]; then
  echo "############ tests ############"
  dart test --test-randomize-ordering-seed=random --reporter expanded
fi

INTEGRATION_TEST_DIR="$PWD/integration_test/"
# Only try tests if integration test folder exist.
if [ -d "$INTEGRATION_TEST_DIR" ]; then
  echo "###### integration tests ######"
  dart test --test-randomize-ordering-seed=random --reporter expanded "$INTEGRATION_TEST_DIR"
fi

echo "###############################"

popd >/dev/null
