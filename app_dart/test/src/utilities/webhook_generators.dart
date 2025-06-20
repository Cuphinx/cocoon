// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:cocoon_service/protos.dart' as pb;
import 'package:cocoon_service/src/model/github/checks.dart';
import 'package:cocoon_service/src/model/luci/pubsub_message.dart';
import 'package:cocoon_service/src/service/config.dart';
import 'package:github/github.dart';
import 'package:github/hooks.dart';
import 'package:test/test.dart';

PushMessage generateGithubWebhookMessage({
  String event = 'pull_request',
  String action = 'merged',
  int number = 123,
  String? baseRef,
  String baseSha = '4cd12fc8b7d4cc2d8609182e1c4dea5cddc86890',
  String headSha = 'be6ff099a4ee56e152a5fa2f37edd10f79d1269a',
  String login = 'dash',
  String headRef = 'abc',
  bool isDraft = false,
  bool merged = false,
  bool mergeable = true,
  String mergeCommitSha = 'fd6b46416c18de36ce87d0241994b2da180cab4c',
  RepositorySlug? slug,
  bool includeChanges = false,
  bool withAutosubmit = false,
  bool withRevertOf = false,
  DateTime? closedAt,
  Iterable<String> additionalLabels = const [],
}) {
  final data =
      (pb.GithubWebhookMessage.create()
            ..event = event
            ..payload = _generatePullRequestEvent(
              action,
              number,
              baseRef,
              baseSha: baseSha,
              headSha: headSha,
              login: login,
              headRef: headRef,
              isDraft: isDraft,
              merged: merged,
              isMergeable: mergeable,
              slug: slug,
              mergeCommitSha: mergeCommitSha,
              includeChanges: includeChanges,
              withAutosubmit: withAutosubmit,
              withRevertOf: withRevertOf,
              closedAt: closedAt,
              additionalLabels: additionalLabels,
            ))
          .writeToJson();
  return PushMessage(data: data, messageId: 'abc123');
}

String _generatePullRequestEvent(
  String action,
  int number,
  String? baseRef, {
  RepositorySlug? slug,
  String login = 'flutter',
  String baseSha = '4cd12fc8b7d4cc2d8609182e1c4dea5cddc86890',
  String headRef = 'wait_for_reassemble',
  required String headSha,
  bool includeCqLabel = false,
  bool isDraft = false,
  bool merged = false,
  bool isMergeable = true,
  String mergeCommitSha = 'fd6b46416c18de36ce87d0241994b2da180cab4c',
  bool includeChanges = false,
  DateTime? closedAt,
  required bool withAutosubmit,
  required bool withRevertOf,
  Iterable<String> additionalLabels = const [],
}) {
  slug ??= Config.flutterSlug;
  baseRef ??= Config.defaultBranch(slug);

  var labelId = 1000;
  Map<String, Object?> generateLabel(String name) {
    labelId++;
    return {
      'id': labelId,
      'node_id': base64Encode('$labelId'.codeUnits),
      'url': 'https://api.github.com/repos/${slug!.fullName}/labels/$name',
      'name': name,
      'color': '207de5',
      'default': false,
    };
  }

  final labels = [
    if (includeCqLabel) generateLabel('cla: yes'),
    if (withAutosubmit) generateLabel('autosubmit'),
    if (withRevertOf) generateLabel('revert of'),

    // This matches the behavior of this function before refactoring to have a
    // more structured way to add test labels. It would be nice to refactor
    // these out.
    generateLabel('framework'),
    generateLabel('tool'),
    ...additionalLabels.map(generateLabel),
  ];

  return '''{
  "action": "$action",
  "number": $number,
  "pull_request": {
    "url": "https://api.github.com/repos/${slug.fullName}/pulls/$number",
    "id": 294034,
    "node_id": "MDExOlB1bGxSZXF1ZXN0Mjk0MDMzODQx",
    "html_url": "https://github.com/${slug.fullName}/pull/$number",
    "diff_url": "https://github.com/${slug.fullName}/pull/$number.diff",
    "patch_url": "https://github.com/${slug.fullName}/pull/$number.patch",
    "issue_url": "https://api.github.com/repos/${slug.fullName}/issues/$number",
    "number": $number,
    "state": "open",
    "locked": false,
    "title": "Defer reassemble until reload is finished",
    "user": {
      "login": "$login",
      "id": 862741,
      "node_id": "MDQ6VXNlcjg2MjA3NDE=",
      "avatar_url": "https://avatars3.githubusercontent.com/u/8620741?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/flutter",
      "html_url": "https://github.com/flutter",
      "followers_url": "https://api.github.com/users/flutter/followers",
      "following_url": "https://api.github.com/users/flutter/following{/other_user}",
      "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
      "organizations_url": "https://api.github.com/users/flutter/orgs",
      "repos_url": "https://api.github.com/users/flutter/repos",
      "events_url": "https://api.github.com/users/flutter/events{/privacy}",
      "received_events_url": "https://api.github.com/users/flutter/received_events",
      "type": "User",
      "site_admin": false
    },
    "draft" : "$isDraft",
    "body": "The body",
    "created_at": "2019-07-03T07:14:35Z",
    "updated_at": "2019-07-03T16:34:53Z",
    "closed_at": ${closedAt == null ? 'null' : '"${closedAt.toUtc().toIso8601String()}"'},
    "merged_at": "2019-07-03T16:34:53Z",
    "merge_commit_sha": "$mergeCommitSha",
    "assignee": null,
    "assignees": [],
    "requested_reviewers": [],
    "requested_teams": [],
    "labels": ${const JsonEncoder.withIndent('  ').convert(labels)},
    "milestone": null,
    "commits_url": "https://api.github.com/repos/${slug.fullName}/pulls/$number/commits",
    "review_comments_url": "https://api.github.com/repos/${slug.fullName}/pulls/$number/comments",
    "review_comment_url": "https://api.github.com/repos/${slug.fullName}/pulls/comments{/number}",
    "comments_url": "https://api.github.com/repos/${slug.fullName}/issues/$number/comments",
    "statuses_url": "https://api.github.com/repos/${slug.fullName}/statuses/be6ff099a4ee56e152a5fa2f37edd10f79d1269a",
    "head": {
      "label": "$login:$headRef",
      "ref": "$headRef",
      "sha": "$headSha",
      "user": {
        "login": "$login",
        "id": 8620741,
        "node_id": "MDQ6VXNlcjg2MjA3NDE=",
        "avatar_url": "https://avatars3.githubusercontent.com/u/8620741?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/flutter",
        "html_url": "https://github.com/flutter",
        "followers_url": "https://api.github.com/users/flutter/followers",
        "following_url": "https://api.github.com/users/flutter/following{/other_user}",
        "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
        "organizations_url": "https://api.github.com/users/flutter/orgs",
        "repos_url": "https://api.github.com/users/flutter/repos",
        "events_url": "https://api.github.com/users/flutter/events{/privacy}",
        "received_events_url": "https://api.github.com/users/flutter/received_events",
        "type": "User",
        "site_admin": false
      },
      "repo": {
        "id": 131232406,
        "node_id": "MDEwOlJlcG9zaXRvcnkxMzEyMzI0MDY=",
        "name": "${slug.name}",
        "full_name": "${slug.fullName}",
        "private": false,
        "owner": {
          "login": "flutter",
          "id": 8620741,
          "node_id": "MDQ6VXNlcjg2MjA3NDE=",
          "avatar_url": "https://avatars3.githubusercontent.com/u/8620741?v=4",
          "gravatar_id": "",
          "url": "https://api.github.com/users/flutter",
          "html_url": "https://github.com/flutter",
          "followers_url": "https://api.github.com/users/flutter/followers",
          "following_url": "https://api.github.com/users/flutter/following{/other_user}",
          "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
          "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
          "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
          "organizations_url": "https://api.github.com/users/flutter/orgs",
          "repos_url": "https://api.github.com/users/flutter/repos",
          "events_url": "https://api.github.com/users/flutter/events{/privacy}",
          "received_events_url": "https://api.github.com/users/flutter/received_events",
          "type": "User",
          "site_admin": false
        },
        "html_url": "https://github.com/${slug.fullName}",
        "description": "Flutter makes it easy and fast to build beautiful mobile apps.",
        "fork": true,
        "url": "https://api.github.com/repos/${slug.fullName}",
        "forks_url": "https://api.github.com/repos/${slug.fullName}/forks",
        "keys_url": "https://api.github.com/repos/${slug.fullName}/keys{/key_id}",
        "collaborators_url": "https://api.github.com/repos/${slug.fullName}/collaborators{/collaborator}",
        "teams_url": "https://api.github.com/repos/${slug.fullName}/teams",
        "hooks_url": "https://api.github.com/repos/${slug.fullName}/hooks",
        "issue_events_url": "https://api.github.com/repos/${slug.fullName}/issues/events{/number}",
        "events_url": "https://api.github.com/repos/${slug.fullName}/events",
        "assignees_url": "https://api.github.com/repos/${slug.fullName}/assignees{/user}",
        "branches_url": "https://api.github.com/repos/${slug.fullName}/branches{/branch}",
        "tags_url": "https://api.github.com/repos/${slug.fullName}/tags",
        "blobs_url": "https://api.github.com/repos/${slug.fullName}/git/blobs{/sha}",
        "git_tags_url": "https://api.github.com/repos/${slug.fullName}/git/tags{/sha}",
        "git_refs_url": "https://api.github.com/repos/${slug.fullName}/git/refs{/sha}",
        "trees_url": "https://api.github.com/repos/${slug.fullName}/git/trees{/sha}",
        "statuses_url": "https://api.github.com/repos/${slug.fullName}/statuses/{sha}",
        "languages_url": "https://api.github.com/repos/${slug.fullName}/languages",
        "stargazers_url": "https://api.github.com/repos/${slug.fullName}/stargazers",
        "contributors_url": "https://api.github.com/repos/${slug.fullName}/contributors",
        "subscribers_url": "https://api.github.com/repos/${slug.fullName}/subscribers",
        "subscription_url": "https://api.github.com/repos/${slug.fullName}/subscription",
        "commits_url": "https://api.github.com/repos/${slug.fullName}/commits{/sha}",
        "git_commits_url": "https://api.github.com/repos/${slug.fullName}/git/commits{/sha}",
        "comments_url": "https://api.github.com/repos/${slug.fullName}/comments{/number}",
        "issue_comment_url": "https://api.github.com/repos/${slug.fullName}/issues/comments{/number}",
        "contents_url": "https://api.github.com/repos/${slug.fullName}/contents/{+path}",
        "compare_url": "https://api.github.com/repos/${slug.fullName}/compare/{base}...{head}",
        "merges_url": "https://api.github.com/repos/${slug.fullName}/merges",
        "archive_url": "https://api.github.com/repos/${slug.fullName}/{archive_format}{/ref}",
        "downloads_url": "https://api.github.com/repos/${slug.fullName}/downloads",
        "issues_url": "https://api.github.com/repos/${slug.fullName}/issues{/number}",
        "pulls_url": "https://api.github.com/repos/${slug.fullName}/pulls{/number}",
        "milestones_url": "https://api.github.com/repos/${slug.fullName}/milestones{/number}",
        "notifications_url": "https://api.github.com/repos/${slug.fullName}/notifications{?since,all,participating}",
        "labels_url": "https://api.github.com/repos/${slug.fullName}/labels{/name}",
        "releases_url": "https://api.github.com/repos/${slug.fullName}/releases{/id}",
        "deployments_url": "https://api.github.com/repos/${slug.fullName}/deployments",
        "created_at": "2018-04-27T02:03:08Z",
        "updated_at": "2019-06-27T06:56:59Z",
        "pushed_at": "2019-07-03T19:40:11Z",
        "git_url": "git://github.com/${slug.fullName}.git",
        "ssh_url": "git@github.com:${slug.fullName}.git",
        "clone_url": "https://github.com/${slug.fullName}.git",
        "svn_url": "https://github.com/${slug.fullName}",
        "homepage": "https://flutter.io",
        "size": 94508,
        "stargazers_count": 1,
        "watchers_count": 1,
        "language": "Dart",
        "has_issues": false,
        "has_projects": true,
        "has_downloads": true,
        "has_wiki": true,
        "has_pages": false,
        "forks_count": 0,
        "mirror_url": null,
        "archived": false,
        "disabled": false,
        "open_issues_count": 0,
        "license": {
          "key": "other",
          "name": "Other",
          "spdx_id": "NOASSERTION",
          "url": null,
          "node_id": "MDc6TGljZW5zZTA="
        },
        "forks": 0,
        "open_issues": 0,
        "watchers": 1,
        "default_branch": "$kDefaultBranchName"
      }
    },
    "base": {
      "label": "flutter:$baseRef",
      "ref": "$baseRef",
      "sha": "$baseSha",
      "user": {
        "login": "flutter",
        "id": 14101776,
        "node_id": "MDEyOk9yZ2FuaXphdGlvbjE0MTAxNzc2",
        "avatar_url": "https://avatars3.githubblahblahblah",
        "gravatar_id": "",
        "url": "https://api.github.com/users/flutter",
        "html_url": "https://github.com/flutter",
        "followers_url": "https://api.github.com/users/flutter/followers",
        "following_url": "https://api.github.com/users/flutter/following{/other_user}",
        "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
        "organizations_url": "https://api.github.com/users/flutter/orgs",
        "repos_url": "https://api.github.com/users/flutter/repos",
        "events_url": "https://api.github.com/users/flutter/events{/privacy}",
        "received_events_url": "https://api.github.com/users/flutter/received_events",
        "type": "Organization",
        "site_admin": false
      },
      "repo": {
        "id": 31792824,
        "node_id": "MDEwOlJlcG9zaXRvcnkzMTc5MjgyNA==",
        "name": "${slug.name}",
        "full_name": "${slug.fullName}",
        "private": false,
        "owner": {
          "login": "flutter",
          "id": 14101776,
          "node_id": "MDEyOk9yZ2FuaXphdGlvbjE0MTAxNzc2",
          "avatar_url": "https://avatars3.githubblahblahblah",
          "gravatar_id": "",
          "url": "https://api.github.com/users/flutter",
          "html_url": "https://github.com/flutter",
          "followers_url": "https://api.github.com/users/flutter/followers",
          "following_url": "https://api.github.com/users/flutter/following{/other_user}",
          "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
          "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
          "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
          "organizations_url": "https://api.github.com/users/flutter/orgs",
          "repos_url": "https://api.github.com/users/flutter/repos",
          "events_url": "https://api.github.com/users/flutter/events{/privacy}",
          "received_events_url": "https://api.github.com/users/flutter/received_events",
          "type": "Organization",
          "site_admin": false
        },
        "html_url": "https://github.com/${slug.fullName}",
        "description": "Flutter makes it easy and fast to build beautiful mobile apps.",
        "fork": false,
        "url": "https://api.github.com/repos/${slug.fullName}",
        "forks_url": "https://api.github.com/repos/${slug.fullName}/forks",
        "keys_url": "https://api.github.com/repos/${slug.fullName}/keys{/key_id}",
        "collaborators_url": "https://api.github.com/repos/${slug.fullName}/collaborators{/collaborator}",
        "teams_url": "https://api.github.com/repos/${slug.fullName}/teams",
        "hooks_url": "https://api.github.com/repos/${slug.fullName}/hooks",
        "issue_events_url": "https://api.github.com/repos/${slug.fullName}/issues/events{/number}",
        "events_url": "https://api.github.com/repos/${slug.fullName}/events",
        "assignees_url": "https://api.github.com/repos/${slug.fullName}/assignees{/user}",
        "branches_url": "https://api.github.com/repos/${slug.fullName}/branches{/branch}",
        "tags_url": "https://api.github.com/repos/${slug.fullName}/tags",
        "blobs_url": "https://api.github.com/repos/${slug.fullName}/git/blobs{/sha}",
        "git_tags_url": "https://api.github.com/repos/${slug.fullName}/git/tags{/sha}",
        "git_refs_url": "https://api.github.com/repos/${slug.fullName}/git/refs{/sha}",
        "trees_url": "https://api.github.com/repos/${slug.fullName}/git/trees{/sha}",
        "statuses_url": "https://api.github.com/repos/${slug.fullName}/statuses/{sha}",
        "languages_url": "https://api.github.com/repos/${slug.fullName}/languages",
        "stargazers_url": "https://api.github.com/repos/${slug.fullName}/stargazers",
        "contributors_url": "https://api.github.com/repos/${slug.fullName}/contributors",
        "subscribers_url": "https://api.github.com/repos/${slug.fullName}/subscribers",
        "subscription_url": "https://api.github.com/repos/${slug.fullName}/subscription",
        "commits_url": "https://api.github.com/repos/${slug.fullName}/commits{/sha}",
        "git_commits_url": "https://api.github.com/repos/${slug.fullName}/git/commits{/sha}",
        "comments_url": "https://api.github.com/repos/${slug.fullName}/comments{/number}",
        "issue_comment_url": "https://api.github.com/repos/${slug.fullName}/issues/comments{/number}",
        "contents_url": "https://api.github.com/repos/${slug.fullName}/contents/{+path}",
        "compare_url": "https://api.github.com/repos/${slug.fullName}/compare/{base}...{head}",
        "merges_url": "https://api.github.com/repos/${slug.fullName}/merges",
        "archive_url": "https://api.github.com/repos/${slug.fullName}/{archive_format}{/ref}",
        "downloads_url": "https://api.github.com/repos/${slug.fullName}/downloads",
        "issues_url": "https://api.github.com/repos/${slug.fullName}/issues{/number}",
        "pulls_url": "https://api.github.com/repos/${slug.fullName}/pulls{/number}",
        "milestones_url": "https://api.github.com/repos/${slug.fullName}/milestones{/number}",
        "notifications_url": "https://api.github.com/repos/${slug.fullName}/notifications{?since,all,participating}",
        "labels_url": "https://api.github.com/repos/${slug.fullName}/labels{/name}",
        "releases_url": "https://api.github.com/repos/${slug.fullName}/releases{/id}",
        "deployments_url": "https://api.github.com/repos/${slug.fullName}/deployments",
        "created_at": "2015-03-06T22:54:58Z",
        "updated_at": "2019-07-04T02:08:44Z",
        "pushed_at": "2019-07-04T02:03:04Z",
        "git_url": "git://github.com/${slug.fullName}.git",
        "ssh_url": "git@github.com:${slug.fullName}.git",
        "clone_url": "https://github.com/${slug.fullName}.git",
        "svn_url": "https://github.com/${slug.fullName}",
        "homepage": "https://flutter.dev",
        "size": 65507,
        "stargazers_count": 68944,
        "watchers_count": 68944,
        "language": "Dart",
        "has_issues": true,
        "has_projects": true,
        "has_downloads": true,
        "has_wiki": true,
        "has_pages": false,
        "forks_count": 7987,
        "mirror_url": null,
        "archived": false,
        "disabled": false,
        "open_issues_count": 6536,
        "license": {
          "key": "other",
          "name": "Other",
          "spdx_id": "NOASSERTION",
          "url": null,
          "node_id": "MDc6TGljZW5zZTA="
        },
        "forks": 7987,
        "open_issues": 6536,
        "watchers": 68944,
        "default_branch": "$kDefaultBranchName"
      }
    },
    "_links": {
      "self": {
        "href": "https://api.github.com/repos/${slug.fullName}/pulls/$number"
      },
      "html": {
        "href": "https://github.com/${slug.fullName}/pull/$number"
      },
      "issue": {
        "href": "https://api.github.com/repos/${slug.fullName}/issues/$number"
      },
      "comments": {
        "href": "https://api.github.com/repos/${slug.fullName}/issues/$number/comments"
      },
      "review_comments": {
        "href": "https://api.github.com/repos/${slug.fullName}/pulls/$number/comments"
      },
      "review_comment": {
        "href": "https://api.github.com/repos/${slug.fullName}/pulls/comments{/number}"
      },
      "commits": {
        "href": "https://api.github.com/repos/${slug.fullName}/pulls/$number/commits"
      },
      "statuses": {
        "href": "https://api.github.com/repos/${slug.fullName}/statuses/deadbeef"
      }
    },
    "author_association": "MEMBER",
    "draft" : $isDraft,
    "merged": $merged,
    "mergeable": $isMergeable,
    "rebaseable": true,
    "mergeable_state": "draft",
    "merged_by": null,
    "comments": 1,
    "review_comments": 0,
    "maintainer_can_modify": true,
    "commits": 5,
    "additions": 55,
    "deletions": 36,
    "changed_files": 5
  },
  ${includeChanges ? '''
  "changes": {
      "base": {
        "ref": {
          "from": "master"
        },
        "sha": {
          "from": "b3af5d64d3e6e2110b07d71909fc432537339659"
        }
      }
  },''' : ''}
  "repository": {
    "id": 1868532,
    "node_id": "MDEwOlJlcG9zaXRvcnkxODY4NTMwMDI=",
    "name": "${slug.name}",
    "full_name": "${slug.fullName}",
    "private": false,
    "owner": {
      "login": "flutter",
      "id": 21031067,
      "node_id": "MDQ6VXNlcjIxMDMxMDY3",
      "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/flutter",
      "html_url": "https://github.com/flutter",
      "followers_url": "https://api.github.com/users/flutter/followers",
      "following_url": "https://api.github.com/users/flutter/following{/other_user}",
      "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
      "organizations_url": "https://api.github.com/users/flutter/orgs",
      "repos_url": "https://api.github.com/users/flutter/repos",
      "events_url": "https://api.github.com/users/flutter/events{/privacy}",
      "received_events_url": "https://api.github.com/users/flutter/received_events",
      "type": "User",
      "site_admin": false
    },
    "html_url": "https://github.com/${slug.fullName}",
    "description": null,
    "fork": false,
    "url": "https://api.github.com/repos/${slug.fullName}",
    "forks_url": "https://api.github.com/repos/${slug.fullName}/forks",
    "keys_url": "https://api.github.com/repos/${slug.fullName}/keys{/key_id}",
    "collaborators_url": "https://api.github.com/repos/${slug.fullName}/collaborators{/collaborator}",
    "teams_url": "https://api.github.com/repos/${slug.fullName}/teams",
    "hooks_url": "https://api.github.com/repos/${slug.fullName}/hooks",
    "issue_events_url": "https://api.github.com/repos/${slug.fullName}/issues/events{/number}",
    "events_url": "https://api.github.com/repos/${slug.fullName}/events",
    "assignees_url": "https://api.github.com/repos/${slug.fullName}/assignees{/user}",
    "branches_url": "https://api.github.com/repos/${slug.fullName}/branches{/branch}",
    "tags_url": "https://api.github.com/repos/${slug.fullName}/tags",
    "blobs_url": "https://api.github.com/repos/${slug.fullName}/git/blobs{/sha}",
    "git_tags_url": "https://api.github.com/repos/${slug.fullName}/git/tags{/sha}",
    "git_refs_url": "https://api.github.com/repos/${slug.fullName}/git/refs{/sha}",
    "trees_url": "https://api.github.com/repos/${slug.fullName}/git/trees{/sha}",
    "statuses_url": "https://api.github.com/repos/${slug.fullName}/statuses/{sha}",
    "languages_url": "https://api.github.com/repos/${slug.fullName}/languages",
    "stargazers_url": "https://api.github.com/repos/${slug.fullName}/stargazers",
    "contributors_url": "https://api.github.com/repos/${slug.fullName}/contributors",
    "subscribers_url": "https://api.github.com/repos/${slug.fullName}/subscribers",
    "subscription_url": "https://api.github.com/repos/${slug.fullName}/subscription",
    "commits_url": "https://api.github.com/repos/${slug.fullName}/commits{/sha}",
    "git_commits_url": "https://api.github.com/repos/${slug.fullName}/git/commits{/sha}",
    "comments_url": "https://api.github.com/repos/${slug.fullName}/comments{/number}",
    "issue_comment_url": "https://api.github.com/repos/${slug.fullName}/issues/comments{/number}",
    "contents_url": "https://api.github.com/repos/${slug.fullName}/contents/{+path}",
    "compare_url": "https://api.github.com/repos/${slug.fullName}/compare/{base}...{head}",
    "merges_url": "https://api.github.com/repos/${slug.fullName}/merges",
    "archive_url": "https://api.github.com/repos/${slug.fullName}/{archive_format}{/ref}",
    "downloads_url": "https://api.github.com/repos/${slug.fullName}/downloads",
    "issues_url": "https://api.github.com/repos/${slug.fullName}/issues{/number}",
    "pulls_url": "https://api.github.com/repos/${slug.fullName}/pulls{/number}",
    "milestones_url": "https://api.github.com/repos/${slug.fullName}/milestones{/number}",
    "notifications_url": "https://api.github.com/repos/${slug.fullName}/notifications{?since,all,participating}",
    "labels_url": "https://api.github.com/repos/${slug.fullName}/labels{/name}",
    "releases_url": "https://api.github.com/repos/${slug.fullName}/releases{/id}",
    "deployments_url": "https://api.github.com/repos/${slug.fullName}/deployments",
    "created_at": "2019-05-15T15:19:25Z",
    "updated_at": "2019-05-15T15:19:27Z",
    "pushed_at": "2019-05-15T15:20:32Z",
    "git_url": "git://github.com/${slug.fullName}.git",
    "ssh_url": "git@github.com:${slug.fullName}.git",
    "clone_url": "https://github.com/${slug.fullName}.git",
    "svn_url": "https://github.com/${slug.fullName}",
    "homepage": null,
    "size": 0,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": null,
    "has_issues": true,
    "has_projects": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": true,
    "forks_count": 0,
    "mirror_url": null,
    "archived": false,
    "disabled": false,
    "open_issues_count": 2,
    "license": null,
    "forks": 0,
    "open_issues": 2,
    "watchers": 0,
    "default_branch": "$kDefaultBranchName"
  },
  "sender": {
    "login": "$login",
    "id": 21031067,
    "node_id": "MDQ6VXNlcjIxMDMxMDY3",
    "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/flutter",
    "html_url": "https://github.com/flutter",
    "followers_url": "https://api.github.com/users/flutter/followers",
    "following_url": "https://api.github.com/users/flutter/following{/other_user}",
    "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
    "organizations_url": "https://api.github.com/users/flutter/orgs",
    "repos_url": "https://api.github.com/users/flutter/repos",
    "events_url": "https://api.github.com/users/flutter/events{/privacy}",
    "received_events_url": "https://api.github.com/users/flutter/received_events",
    "type": "User",
    "site_admin": false
  }
}''';
}

PushMessage generateCheckRunEvent({
  String action = 'created',
  int numberOfPullRequests = 1,
}) {
  var data = '''{
  "action": "$action",
  "check_run": {
    "id": 128620228,
    "node_id": "MDg6Q2hlY2tSdW4xMjg2MjAyMjg=",
    "head_sha": "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
    "external_id": "",
    "url": "https://api.github.com/repos/flutter/flutter/check-runs/128620228",
    "html_url": "https://github.com/flutter/flutter/runs/128620228",
    "details_url": "https://octocoders.io",
    "status": "queued",
    "conclusion": null,
    "started_at": "2019-05-15T15:21:12Z",
    "completed_at": null,
    "output": {
      "title": null,
      "summary": null,
      "text": null,
      "annotations_count": 0,
      "annotations_url": "https://api.github.com/repos/flutter/flutter/check-runs/128620228/annotations"
    },
    "name": "Octocoders-linter",
    "check_suite": {
      "id": 118578147,
      "node_id": "MDEwOkNoZWNrU3VpdGUxMTg1NzgxNDc=",
      "head_branch": "changes",
      "head_sha": "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
      "status": "queued",
      "conclusion": null,
      "url": "https://api.github.com/repos/flutter/flutter/check-suites/118578147",
      "before": "6113728f27ae82c7b1a177c8d03f9e96e0adf246",
      "after": "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
      "pull_requests": [
        {
          "url": "https://api.github.com/repos/flutter/flutter/pulls/2",
          "id": 279147437,
          "number": 2,
          "head": {
            "ref": "changes",
            "sha": "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
            "repo": {
              "id": 186853002,
              "url": "https://api.github.com/repos/flutter/flutter",
              "name": "flutter"
            }
          },
          "base": {
            "ref": "master",
            "sha": "f95f852bd8fca8fcc58a9a2d6c842781e32a215e",
            "repo": {
              "id": 186853002,
              "url": "https://api.github.com/repos/flutter/flutter",
              "name": "flutter"
            }
          }
        }
      ],
      "app": {
        "id": 29310,
        "node_id": "MDM6QXBwMjkzMTA=",
        "owner": {
          "login": "Octocoders",
          "id": 38302899,
          "node_id": "MDEyOk9yZ2FuaXphdGlvbjM4MzAyODk5",
          "avatar_url": "https://avatars1.githubusercontent.com/u/38302899?v=4",
          "gravatar_id": "",
          "url": "https://api.github.com/users/Octocoders",
          "html_url": "https://github.com/Octocoders",
          "followers_url": "https://api.github.com/users/Octocoders/followers",
          "following_url": "https://api.github.com/users/Octocoders/following{/other_user}",
          "gists_url": "https://api.github.com/users/Octocoders/gists{/gist_id}",
          "starred_url": "https://api.github.com/users/Octocoders/starred{/owner}{/repo}",
          "subscriptions_url": "https://api.github.com/users/Octocoders/subscriptions",
          "organizations_url": "https://api.github.com/users/Octocoders/orgs",
          "repos_url": "https://api.github.com/users/Octocoders/repos",
          "events_url": "https://api.github.com/users/Octocoders/events{/privacy}",
          "received_events_url": "https://api.github.com/users/Octocoders/received_events",
          "type": "Organization",
          "site_admin": false
        },
        "name": "octocoders-linter",
        "description": "",
        "external_url": "https://octocoders.io",
        "html_url": "https://github.com/apps/octocoders-linter",
        "created_at": "2019-04-19T19:36:24Z",
        "updated_at": "2019-04-19T19:36:56Z",
        "permissions": {
          "administration": "write",
          "checks": "write",
          "contents": "write",
          "deployments": "write",
          "issues": "write",
          "members": "write",
          "metadata": "read",
          "organization_administration": "write",
          "organization_hooks": "write",
          "organization_plan": "read",
          "organization_projects": "write",
          "organization_user_blocking": "write",
          "pages": "write",
          "pull_requests": "write",
          "repository_hooks": "write",
          "repository_projects": "write",
          "statuses": "write",
          "team_discussions": "write",
          "vulnerability_alerts": "read"
        },
        "events": []
      },
      "created_at": "2019-05-15T15:20:31Z",
      "updated_at": "2019-05-15T15:20:31Z"
    },
    "app": {
      "id": 29310,
      "node_id": "MDM6QXBwMjkzMTA=",
      "owner": {
        "login": "Octocoders",
        "id": 38302899,
        "node_id": "MDEyOk9yZ2FuaXphdGlvbjM4MzAyODk5",
        "avatar_url": "https://avatars1.githubusercontent.com/u/38302899?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/Octocoders",
        "html_url": "https://github.com/Octocoders",
        "followers_url": "https://api.github.com/users/Octocoders/followers",
        "following_url": "https://api.github.com/users/Octocoders/following{/other_user}",
        "gists_url": "https://api.github.com/users/Octocoders/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/Octocoders/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/Octocoders/subscriptions",
        "organizations_url": "https://api.github.com/users/Octocoders/orgs",
        "repos_url": "https://api.github.com/users/Octocoders/repos",
        "events_url": "https://api.github.com/users/Octocoders/events{/privacy}",
        "received_events_url": "https://api.github.com/users/Octocoders/received_events",
        "type": "Organization",
        "site_admin": false
      },
      "name": "octocoders-linter",
      "description": "",
      "external_url": "https://octocoders.io",
      "html_url": "https://github.com/apps/octocoders-linter",
      "created_at": "2019-04-19T19:36:24Z",
      "updated_at": "2019-04-19T19:36:56Z",
      "permissions": {
        "administration": "write",
        "checks": "write",
        "contents": "write",
        "deployments": "write",
        "issues": "write",
        "members": "write",
        "metadata": "read",
        "organization_administration": "write",
        "organization_hooks": "write",
        "organization_plan": "read",
        "organization_projects": "write",
        "organization_user_blocking": "write",
        "pages": "write",
        "pull_requests": "write",
        "repository_hooks": "write",
        "repository_projects": "write",
        "statuses": "write",
        "team_discussions": "write",
        "vulnerability_alerts": "read"
      },
      "events": []
    },
    "pull_requests": [''';

  for (var i = 0; i < numberOfPullRequests; i++) {
    data += '''{
        "url": "https://api.github.com/repos/flutter/flutter/pulls/2",
        "id": 279147437,
        "number": ${i + 2},
        "head": {
          "ref": "changes",
          "sha": "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
          "repo": {
            "id": 186853002,
            "url": "https://api.github.com/repos/flutter/flutter",
            "name": "flutter"
          }
        },
        "base": {
          "ref": "master",
          "sha": "f95f852bd8fca8fcc58a9a2d6c842781e32a215e",
          "repo": {
            "id": 186853002,
            "url": "https://api.github.com/repos/flutter/flutter",
            "name": "flutter"
          }
        }
      }''';
    if (i < numberOfPullRequests - 1) {
      data += ',';
    }
  }
  data += '''],
    "deployment": {
      "url": "https://api.github.com/repos/flutter/flutter/deployments/326191728",
      "id": 326191728,
      "node_id": "MDEwOkRlcGxveW1lbnQzMjYxOTE3Mjg=",
      "task": "deploy",
      "original_environment": "lab",
      "environment": "lab",
      "description": null,
      "created_at": "2021-02-18T08:22:48Z",
      "updated_at": "2021-02-18T09:47:16Z",
      "statuses_url": "https://api.github.com/repos/flutter/flutter/deployments/326191728/statuses",
      "repository_url": "https://api.github.com/repos/flutter/flutter"
    }
  },
  "repository": {
    "id": 186853002,
    "node_id": "MDEwOlJlcG9zaXRvcnkxODY4NTMwMDI=",
    "name": "flutter",
    "full_name": "flutter/flutter",
    "private": false,
    "owner": {
      "login": "flutter",
      "id": 21031067,
      "node_id": "MDQ6VXNlcjIxMDMxMDY3",
      "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/flutter",
      "html_url": "https://github.com/flutter",
      "followers_url": "https://api.github.com/users/flutter/followers",
      "following_url": "https://api.github.com/users/flutter/following{/other_user}",
      "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
      "organizations_url": "https://api.github.com/users/flutter/orgs",
      "repos_url": "https://api.github.com/users/flutter/repos",
      "events_url": "https://api.github.com/users/flutter/events{/privacy}",
      "received_events_url": "https://api.github.com/users/flutter/received_events",
      "type": "User",
      "site_admin": false
    },
    "html_url": "https://github.com/flutter/flutter",
    "description": null,
    "fork": false,
    "url": "https://api.github.com/repos/flutter/flutter",
    "forks_url": "https://api.github.com/repos/flutter/flutter/forks",
    "keys_url": "https://api.github.com/repos/flutter/flutter/keys{/key_id}",
    "collaborators_url": "https://api.github.com/repos/flutter/flutter/collaborators{/collaborator}",
    "teams_url": "https://api.github.com/repos/flutter/flutter/teams",
    "hooks_url": "https://api.github.com/repos/flutter/flutter/hooks",
    "issue_events_url": "https://api.github.com/repos/flutter/flutter/issues/events{/number}",
    "events_url": "https://api.github.com/repos/flutter/flutter/events",
    "assignees_url": "https://api.github.com/repos/flutter/flutter/assignees{/user}",
    "branches_url": "https://api.github.com/repos/flutter/flutter/branches{/branch}",
    "tags_url": "https://api.github.com/repos/flutter/flutter/tags",
    "blobs_url": "https://api.github.com/repos/flutter/flutter/git/blobs{/sha}",
    "git_tags_url": "https://api.github.com/repos/flutter/flutter/git/tags{/sha}",
    "git_refs_url": "https://api.github.com/repos/flutter/flutter/git/refs{/sha}",
    "trees_url": "https://api.github.com/repos/flutter/flutter/git/trees{/sha}",
    "statuses_url": "https://api.github.com/repos/flutter/flutter/statuses/{sha}",
    "languages_url": "https://api.github.com/repos/flutter/flutter/languages",
    "stargazers_url": "https://api.github.com/repos/flutter/flutter/stargazers",
    "contributors_url": "https://api.github.com/repos/flutter/flutter/contributors",
    "subscribers_url": "https://api.github.com/repos/flutter/flutter/subscribers",
    "subscription_url": "https://api.github.com/repos/flutter/flutter/subscription",
    "commits_url": "https://api.github.com/repos/flutter/flutter/commits{/sha}",
    "git_commits_url": "https://api.github.com/repos/flutter/flutter/git/commits{/sha}",
    "comments_url": "https://api.github.com/repos/flutter/flutter/comments{/number}",
    "issue_comment_url": "https://api.github.com/repos/flutter/flutter/issues/comments{/number}",
    "contents_url": "https://api.github.com/repos/flutter/flutter/contents/{+path}",
    "compare_url": "https://api.github.com/repos/flutter/flutter/compare/{base}...{head}",
    "merges_url": "https://api.github.com/repos/flutter/flutter/merges",
    "archive_url": "https://api.github.com/repos/flutter/flutter/{archive_format}{/ref}",
    "downloads_url": "https://api.github.com/repos/flutter/flutter/downloads",
    "issues_url": "https://api.github.com/repos/flutter/flutter/issues{/number}",
    "pulls_url": "https://api.github.com/repos/flutter/flutter/pulls{/number}",
    "milestones_url": "https://api.github.com/repos/flutter/flutter/milestones{/number}",
    "notifications_url": "https://api.github.com/repos/flutter/flutter/notifications{?since,all,participating}",
    "labels_url": "https://api.github.com/repos/flutter/flutter/labels{/name}",
    "releases_url": "https://api.github.com/repos/flutter/flutter/releases{/id}",
    "deployments_url": "https://api.github.com/repos/flutter/flutter/deployments",
    "created_at": "2019-05-15T15:19:25Z",
    "updated_at": "2019-05-15T15:21:03Z",
    "pushed_at": "2019-05-15T15:20:57Z",
    "git_url": "git://github.com/flutter/flutter.git",
    "ssh_url": "git@github.com:flutter/flutter.git",
    "clone_url": "https://github.com/flutter/flutter.git",
    "svn_url": "https://github.com/flutter/flutter",
    "homepage": null,
    "size": 0,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": "Ruby",
    "has_issues": true,
    "has_projects": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": true,
    "forks_count": 1,
    "mirror_url": null,
    "archived": false,
    "disabled": false,
    "open_issues_count": 2,
    "license": null,
    "forks": 1,
    "open_issues": 2,
    "watchers": 0,
    "default_branch": "master"
  },
  "sender": {
    "login": "flutter",
    "id": 21031067,
    "node_id": "MDQ6VXNlcjIxMDMxMDY3",
    "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/flutter",
    "html_url": "https://github.com/flutter",
    "followers_url": "https://api.github.com/users/flutter/followers",
    "following_url": "https://api.github.com/users/flutter/following{/other_user}",
    "gists_url": "https://api.github.com/users/flutter/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/flutter/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/flutter/subscriptions",
    "organizations_url": "https://api.github.com/users/flutter/orgs",
    "repos_url": "https://api.github.com/users/flutter/repos",
    "events_url": "https://api.github.com/users/flutter/events{/privacy}",
    "received_events_url": "https://api.github.com/users/flutter/received_events",
    "type": "User",
    "site_admin": false
  }
}''';
  final message = pb.GithubWebhookMessage(event: 'check_run', payload: data);
  return PushMessage(data: message.writeToJson(), messageId: 'abc123');
}

PushMessage generateCreateBranchMessage(
  String branchName,
  String repository, {
  bool forked = false,
}) {
  final createEvent = generateCreateBranchEvent(
    branchName,
    repository,
    forked: forked,
  );
  final message = pb.GithubWebhookMessage(
    event: 'create',
    payload: jsonEncode(createEvent),
  );
  return PushMessage(data: message.writeToJson(), messageId: 'abc123');
}

CreateEvent generateCreateBranchEvent(
  String branchName,
  String repository, {
  bool forked = false,
}) => CreateEvent.fromJson(
  jsonDecode('''
{
  "ref": "$branchName",
  "ref_type": "branch",
  "master_branch": "master",
  "description": null,
  "pusher_type": "user",
  "repository": {
    "id": 186853002,
    "node_id": "MDEwOlJlcG9zaXRvcnkxODY4NTMwMDI=",
    "name": "${repository.split('/')[1]}",
    "full_name": "$repository",
    "private": false,
    "owner": {
      "login": "${repository.split('/')[0]}",
      "id": 21031067,
      "node_id": "MDQ6VXNlcjIxMDMxMDY3",
      "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/Codertocat",
      "html_url": "https://github.com/Codertocat",
      "followers_url": "https://api.github.com/users/Codertocat/followers",
      "following_url": "https://api.github.com/users/Codertocat/following{/other_user}",
      "gists_url": "https://api.github.com/users/Codertocat/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/Codertocat/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/Codertocat/subscriptions",
      "organizations_url": "https://api.github.com/users/Codertocat/orgs",
      "repos_url": "https://api.github.com/users/Codertocat/repos",
      "events_url": "https://api.github.com/users/Codertocat/events{/privacy}",
      "received_events_url": "https://api.github.com/users/Codertocat/received_events",
      "type": "User",
      "site_admin": false
    },
    "html_url": "https://github.com/$repository",
    "description": null,
    "fork": $forked,
    "url": "https://api.github.com/repos/$repository",
    "forks_url": "https://api.github.com/repos/$repository/forks",
    "keys_url": "https://api.github.com/repos/$repository/keys{/key_id}",
    "collaborators_url": "https://api.github.com/repos/$repository/collaborators{/collaborator}",
    "teams_url": "https://api.github.com/repos/$repository/teams",
    "hooks_url": "https://api.github.com/repos/$repository/hooks",
    "issue_events_url": "https://api.github.com/repos/$repository/issues/events{/number}",
    "events_url": "https://api.github.com/repos/$repository/events",
    "assignees_url": "https://api.github.com/repos/$repository/assignees{/user}",
    "branches_url": "https://api.github.com/repos/$repository/branches{/branch}",
    "tags_url": "https://api.github.com/repos/$repository/tags",
    "blobs_url": "https://api.github.com/repos/$repository/git/blobs{/sha}",
    "git_tags_url": "https://api.github.com/repos/$repository/git/tags{/sha}",
    "git_refs_url": "https://api.github.com/repos/$repository/git/refs{/sha}",
    "trees_url": "https://api.github.com/repos/$repository/git/trees{/sha}",
    "statuses_url": "https://api.github.com/repos/$repository/statuses/{sha}",
    "languages_url": "https://api.github.com/repos/$repository/languages",
    "stargazers_url": "https://api.github.com/repos/$repository/stargazers",
    "contributors_url": "https://api.github.com/repos/$repository/contributors",
    "subscribers_url": "https://api.github.com/repos/$repository/subscribers",
    "subscription_url": "https://api.github.com/repos/$repository/subscription",
    "commits_url": "https://api.github.com/repos/$repository/commits{/sha}",
    "git_commits_url": "https://api.github.com/repos/$repository/git/commits{/sha}",
    "comments_url": "https://api.github.com/repos/$repository/comments{/number}",
    "issue_comment_url": "https://api.github.com/repos/$repository/issues/comments{/number}",
    "contents_url": "https://api.github.com/repos/$repository/contents/{+path}",
    "compare_url": "https://api.github.com/repos/$repository/compare/{base}...{head}",
    "merges_url": "https://api.github.com/repos/$repository/merges",
    "archive_url": "https://api.github.com/repos/$repository/{archive_format}{/ref}",
    "downloads_url": "https://api.github.com/repos/$repository/downloads",
    "issues_url": "https://api.github.com/repos/$repository/issues{/number}",
    "pulls_url": "https://api.github.com/repos/$repository/pulls{/number}",
    "milestones_url": "https://api.github.com/repos/$repository/milestones{/number}",
    "notifications_url": "https://api.github.com/repos/$repository/notifications{?since,all,participating}",
    "labels_url": "https://api.github.com/repos/$repository/labels{/name}",
    "releases_url": "https://api.github.com/repos/$repository/releases{/id}",
    "deployments_url": "https://api.github.com/repos/$repository/deployments",
    "created_at": "2019-05-15T15:19:25Z",
    "updated_at": "2019-05-15T15:20:41Z",
    "pushed_at": "2019-05-15T15:20:56Z",
    "git_url": "git://github.com/$repository.git",
    "ssh_url": "git@github.com:Codertocat/Hello-World.git",
    "clone_url": "https://github.com/$repository.git",
    "svn_url": "https://github.com/$repository",
    "homepage": null,
    "size": 0,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": "Ruby",
    "has_issues": true,
    "has_projects": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": true,
    "forks_count": 1,
    "mirror_url": null,
    "archived": false,
    "disabled": false,
    "open_issues_count": 2,
    "license": null,
    "forks": 1,
    "open_issues": 2,
    "watchers": 0,
    "default_branch": "master"
  },
  "sender": {
    "login": "Codertocat",
    "id": 21031067,
    "node_id": "MDQ6VXNlcjIxMDMxMDY3",
    "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/Codertocat",
    "html_url": "https://github.com/Codertocat",
    "followers_url": "https://api.github.com/users/Codertocat/followers",
    "following_url": "https://api.github.com/users/Codertocat/following{/other_user}",
    "gists_url": "https://api.github.com/users/Codertocat/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/Codertocat/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/Codertocat/subscriptions",
    "organizations_url": "https://api.github.com/users/Codertocat/orgs",
    "repos_url": "https://api.github.com/users/Codertocat/repos",
    "events_url": "https://api.github.com/users/Codertocat/events{/privacy}",
    "received_events_url": "https://api.github.com/users/Codertocat/received_events",
    "type": "User",
    "site_admin": false
  }
}''')
      as Map<String, dynamic>,
);

PushMessage generatePushMessage(
  String branch,
  String organization,
  String repository,
) {
  final event = generatePushEvent(branch, organization, repository);
  final message = pb.GithubWebhookMessage(
    event: 'push',
    payload: jsonEncode(event),
  );
  return PushMessage(data: message.writeToJson(), messageId: 'abc123');
}

Map<String, dynamic> generatePushEvent(
  String branch,
  String organization,
  String repository, {
  String sha = 'def456def456def456',
  String message = 'Commit-message',
  String avatarUrl = 'https://fakegithubcontent.com/google_profile',
  String username = 'googledotcom',
}) =>
    jsonDecode('''
{
  "ref": "refs/heads/$branch",
  "before": "abc123abc123abc123",
  "after": "$sha",
  "sender": {
    "login": "$username",
    "avatar_url": "$avatarUrl"
  },
  "commits": [
    {
      "id": "ba2f6608108d174c4a6e6e093a4ddcf313656748",
      "message": "Adding null safety",
      "timestamp": "2023-09-05T15:01:04-05:00",
      "url": "https://github.com/org/repo/commit/abc123abc123abc123"
    }
  ],
  "head_commit": {
    "id": "$sha",
    "message": "$message",
    "timestamp": "2023-09-05T15:01:04-05:00",
    "url": "https://github.com/org/repo/commit/abc123abc123abc123"
  },
  "repository": {
    "name": "$repository",
    "full_name": "$organization/$repository"
  }
}
''')
        as Map<String, Object?>;

PushMessage generateMergeGroupMessage({
  required String repository,
  required String action,
  required String message,
  DateTime? publishTime,
  String? reason,
  String? headSha,
  String? headRef,
}) {
  if (action == 'destroyed' &&
      !MergeGroupEvent.destroyReasons.contains(reason)) {
    fail(
      'Invalid reason "$reason" for merge group "destroyed" event. The reason '
      'must be one of: ${MergeGroupEvent.destroyReasons}',
    );
  }
  final webhookMessage = pb.GithubWebhookMessage(
    event: 'merge_group',
    payload: generateMergeGroupEventString(
      action: action,
      message: message,
      repository: repository,
      reason: reason,
      headSha: headSha,
      headRef: headRef,
    ),
  );
  publishTime ??= DateTime.now();
  return PushMessage(
    data: webhookMessage.writeToJson(),
    messageId: 'abc123',
    publishTime: publishTime.toUtc().toIso8601String(),
  );
}

String generateMergeGroupEventString({
  required String action,
  required String message,
  required String repository,
  String? headSha,
  String? headRef,
  String? reason,
}) {
  headSha ??= 'c9affbbb12aa40cb3afbe94b9ea6b119a256bebf';
  headRef ??= 'refs/heads/gh-readonly-queue/main/pr-15-$headSha';
  return '''
{
"action": "$action",
${reason != null ? '"reason": "$reason",' : ''}
"merge_group": {
  "head_sha": "$headSha",
  "head_ref": "$headRef",
  "base_sha": "172355550dde5881b0269972ea4cbe5a6d0561bc",
  "base_ref": "refs/heads/main",
  "head_commit": {
    "id": "c9affbbb12aa40cb3afbe94b9ea6b119a256bebf",
    "tree_id": "556b9a8db18c974738d9d5e15988ae9a67e96b91",
    "message": "$message",
    "timestamp": "2024-10-15T20:24:16Z",
    "author": {
      "name": "John Doe",
      "email": "johndoe@example.org"
    },
    "committer": {
      "name": "GitHub",
      "email": "noreply@github.com"
    }
  }
},
"repository": {
  "id": 186853002,
  "node_id": "MDEwOlJlcG9zaXRvcnkxODY4NTMwMDI=",
  "name": "${repository.split('/')[1]}",
  "full_name": "$repository",
  "private": false,
  "owner": {
    "login": "${repository.split('/')[0]}",
    "id": 21031067,
    "node_id": "MDQ6VXNlcjIxMDMxMDY3",
    "avatar_url": "https://avatars1.githubusercontent.com/u/21031067?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/Codertocat",
    "html_url": "https://github.com/Codertocat",
    "followers_url": "https://api.github.com/users/Codertocat/followers",
    "following_url": "https://api.github.com/users/Codertocat/following{/other_user}",
    "gists_url": "https://api.github.com/users/Codertocat/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/Codertocat/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/Codertocat/subscriptions",
    "organizations_url": "https://api.github.com/users/Codertocat/orgs",
    "repos_url": "https://api.github.com/users/Codertocat/repos",
    "events_url": "https://api.github.com/users/Codertocat/events{/privacy}",
    "received_events_url": "https://api.github.com/users/Codertocat/received_events",
    "type": "User",
    "site_admin": false
  },
  "html_url": "https://github.com/$repository",
  "description": null,
  "fork": false,
  "url": "https://api.github.com/repos/$repository",
  "forks_url": "https://api.github.com/repos/$repository/forks",
  "keys_url": "https://api.github.com/repos/$repository/keys{/key_id}",
  "collaborators_url": "https://api.github.com/repos/$repository/collaborators{/collaborator}",
  "teams_url": "https://api.github.com/repos/$repository/teams",
  "hooks_url": "https://api.github.com/repos/$repository/hooks",
  "issue_events_url": "https://api.github.com/repos/$repository/issues/events{/number}",
  "events_url": "https://api.github.com/repos/$repository/events",
  "assignees_url": "https://api.github.com/repos/$repository/assignees{/user}",
  "branches_url": "https://api.github.com/repos/$repository/branches{/branch}",
  "tags_url": "https://api.github.com/repos/$repository/tags",
  "blobs_url": "https://api.github.com/repos/$repository/git/blobs{/sha}",
  "git_tags_url": "https://api.github.com/repos/$repository/git/tags{/sha}",
  "git_refs_url": "https://api.github.com/repos/$repository/git/refs{/sha}",
  "trees_url": "https://api.github.com/repos/$repository/git/trees{/sha}",
  "statuses_url": "https://api.github.com/repos/$repository/statuses/{sha}",
  "languages_url": "https://api.github.com/repos/$repository/languages",
  "stargazers_url": "https://api.github.com/repos/$repository/stargazers",
  "contributors_url": "https://api.github.com/repos/$repository/contributors",
  "subscribers_url": "https://api.github.com/repos/$repository/subscribers",
  "subscription_url": "https://api.github.com/repos/$repository/subscription",
  "commits_url": "https://api.github.com/repos/$repository/commits{/sha}",
  "git_commits_url": "https://api.github.com/repos/$repository/git/commits{/sha}",
  "comments_url": "https://api.github.com/repos/$repository/comments{/number}",
  "issue_comment_url": "https://api.github.com/repos/$repository/issues/comments{/number}",
  "contents_url": "https://api.github.com/repos/$repository/contents/{+path}",
  "compare_url": "https://api.github.com/repos/$repository/compare/{base}...{head}",
  "merges_url": "https://api.github.com/repos/$repository/merges",
  "archive_url": "https://api.github.com/repos/$repository/{archive_format}{/ref}",
  "downloads_url": "https://api.github.com/repos/$repository/downloads",
  "issues_url": "https://api.github.com/repos/$repository/issues{/number}",
  "pulls_url": "https://api.github.com/repos/$repository/pulls{/number}",
  "milestones_url": "https://api.github.com/repos/$repository/milestones{/number}",
  "notifications_url": "https://api.github.com/repos/$repository/notifications{?since,all,participating}",
  "labels_url": "https://api.github.com/repos/$repository/labels{/name}",
  "releases_url": "https://api.github.com/repos/$repository/releases{/id}",
  "deployments_url": "https://api.github.com/repos/$repository/deployments",
  "created_at": "2019-05-15T15:19:25Z",
  "updated_at": "2019-05-15T15:20:41Z",
  "pushed_at": "2019-05-15T15:20:56Z",
  "git_url": "git://github.com/$repository.git",
  "ssh_url": "git@github.com:Codertocat/Hello-World.git",
  "clone_url": "https://github.com/$repository.git",
  "svn_url": "https://github.com/$repository",
  "homepage": null,
  "size": 0,
  "stargazers_count": 0,
  "watchers_count": 0,
  "language": "Ruby",
  "has_issues": true,
  "has_projects": true,
  "has_downloads": true,
  "has_wiki": true,
  "has_pages": true,
  "forks_count": 1,
  "mirror_url": null,
  "archived": false,
  "disabled": false,
  "open_issues_count": 2,
  "license": null,
  "forks": 1,
  "open_issues": 2,
  "watchers": 0,
  "default_branch": "master"
},
"organization": {
  "login": "flutter",
  "id": 14101776,
  "node_id": "MDEyOk9yZ2FuaXphdGlvbjE0MTAxNzc2",
  "url": "https://api.github.com/orgs/flutter",
  "repos_url": "https://api.github.com/orgs/flutter/repos",
  "events_url": "https://api.github.com/orgs/flutter/events",
  "hooks_url": "https://api.github.com/orgs/flutter/hooks",
  "issues_url": "https://api.github.com/orgs/flutter/issues",
  "members_url": "https://api.github.com/orgs/flutter/members{/member}",
  "public_members_url": "https://api.github.com/orgs/flutter/public_members{/member}",
  "avatar_url": "https://avatars.githubusercontent.com/u/14101776?v=4",
  "description": "Flutter is Google's UI toolkit for building beautiful, natively compiled applications for mobile, web, desktop, and embedded devices from a single codebase."
},
"enterprise": {
  "id": 1732,
  "slug": "alphabet",
  "name": "Alphabet",
  "node_id": "MDEwOkVudGVycHJpc2UxNzMy",
  "avatar_url": "https://avatars.githubusercontent.com/b/1732?v=4",
  "description": "",
  "website_url": "https://abc.xyz/",
  "html_url": "https://github.com/enterprises/alphabet",
  "created_at": "2019-12-19T00:30:52Z",
  "updated_at": "2024-07-18T11:54:37Z"
},
"sender": {
  "login": "johndoe",
  "id": 1924313,
  "node_id": "MDQ6VXNlcjE5MjQzMTM=",
  "avatar_url": "https://avatars.githubusercontent.com/u/1924313?v=4",
  "gravatar_id": "",
  "url": "https://api.github.com/users/johndoe",
  "html_url": "https://github.com/johndoe",
  "followers_url": "https://api.github.com/users/johndoe/followers",
  "following_url": "https://api.github.com/users/johndoe/following{/other_user}",
  "gists_url": "https://api.github.com/users/johndoe/gists{/gist_id}",
  "starred_url": "https://api.github.com/users/johndoe/starred{/owner}{/repo}",
  "subscriptions_url": "https://api.github.com/users/johndoe/subscriptions",
  "organizations_url": "https://api.github.com/users/johndoe/orgs",
  "repos_url": "https://api.github.com/users/johndoe/repos",
  "events_url": "https://api.github.com/users/johndoe/events{/privacy}",
  "received_events_url": "https://api.github.com/users/johndoe/received_events",
  "type": "User",
  "site_admin": false
},
"installation": {
  "id": 10381585,
  "node_id": "MDIzOkludGVncmF0aW9uSW5zdGFsbGF0aW9uMTAzODE1ODU="
}
}
''';
}
