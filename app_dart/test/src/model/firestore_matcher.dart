// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cocoon_service/src/model/firestore/base.dart';
import 'package:cocoon_service/src/model/firestore/build_status_snapshot.dart';
import 'package:cocoon_service/src/model/firestore/ci_staging.dart';
import 'package:cocoon_service/src/model/firestore/commit.dart';
import 'package:cocoon_service/src/model/firestore/content_aware_hash_builds.dart';
import 'package:cocoon_service/src/model/firestore/github_build_status.dart';
import 'package:cocoon_service/src/model/firestore/github_gold_status.dart';
import 'package:cocoon_service/src/model/firestore/pr_check_runs.dart';
import 'package:cocoon_service/src/model/firestore/task.dart';
import 'package:cocoon_service/src/model/firestore/tree_status_change.dart';
import 'package:googleapis/firestore/v1.dart' as g;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

part '_build_status_snapshot.dart';
part '_ci_staging.dart';
part '_commit.dart';
part '_content_aware_hash_builds.dart';
part '_github_build_status.dart';
part '_github_gold_status.dart';
part '_pr_check_run.dart';
part '_task.dart';
part '_tree_status_change.dart';

/// Matches a Firestore model, or raw document, of type [Commit].
const isCommit = CommitMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [CiStaging].
const isCiStaging = CiStagingMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [Task].
const isTask = TaskMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [GithubBuildStatus].
const isGithubBuildStatus = GithubBuildStatusMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [GithubGoldStatus].
const isGithubGoldStatus = GithubGoldStatusMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [PrCheckRuns].
const isPrCheckRun = PrCheckRunsMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [BuildStatusSnapshot].
const isBuildStatusSnapshot = BuildStatusSnapshotMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [ContentAwareHashBuilds].
const isContentAwareHashBuilds = ContentAwareHashBuildsMatcher._(TypeMatcher());

/// Matches a Firestore model, or raw document, of type [TreeStatusChange].
const isTreeStatusChange = TreeStatusChangeMatcher._(TypeMatcher());

/// Returns whether the document is a path to the collection [metadata].
bool isDocumentA(g.Document document, AppDocumentMetadata<void> metadata) {
  // Check if the document name is a path to the collection.
  final collection = p.posix.basename(p.posix.dirname(document.name ?? ''));
  return metadata.collectionId == collection;
}

/// Matches a Firestore document model, or raw document, of type [T].
@immutable
abstract final class ModelMatcher<T extends AppDocument<T>> extends Matcher {
  const ModelMatcher._(this._delegate);
  final TypeMatcher<T> _delegate;

  /// Describes the [AppDocument] type.
  @protected
  AppDocumentMetadata<T> get metadata;

  @override
  @nonVirtual
  Description describe(Description description) {
    description = description.add('a $T document where ');
    return _delegate.describe(description);
  }

  static bool _isPathTo(
    String documentName,
    AppDocumentMetadata<void> metadata,
  ) {
    // Check if the document name is a path to the collection.
    final collection = p.posix.basename(p.posix.dirname(documentName));
    return metadata.collectionId == collection;
  }

  @override
  @nonVirtual
  bool matches(Object? item, _) {
    // Check if the item is a Document.
    if (item is! g.Document) {
      return false;
    }

    // Check if the document has the path to the collection.
    if (item.name == null || !_isPathTo(item.name!, metadata)) {
      return false;
    }

    return _delegate.matches(
      item is T ? item : metadata.fromDocument(item),
      {},
    );
  }

  @override
  @nonVirtual
  Description describeMismatch(Object? item, Description description, _, _) {
    // Not a document and not the wrapped type.
    if (item is! g.Document) {
      return description.add('not a Document');
    }

    // Not a saved document (does not have a name).
    if (item.name == null) {
      return description.add('not a saved Document (missing "name")');
    }

    // Not a document of the expected type.
    if (!_isPathTo(item.name!, metadata)) {
      final collection = p.posix.basename(p.posix.dirname(item.name!));
      return description.add('not a $T, belongs to collection "$collection"');
    }

    return _delegate.describeMismatch(item, description, {}, false);
  }
}
