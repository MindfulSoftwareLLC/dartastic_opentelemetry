// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Backport release script — republishes a `1.1.0-beta.x` release on the
/// `0.9.x` stable channel.
///
/// Run this AFTER `dart tool/release.dart` has cut and published the beta.
/// The `0.9.x` line is not separate development: each `0.9.x` release is the
/// beta's code with a different version stamp, so that users who have not
/// opted into prereleases still get the fixes. This script performs exactly
/// that stamp, from the beta's own tag, so the published code is provably the
/// beta's code and not whatever happens to be on your branch.
///
/// Given `--version 0.9.8 --from v1.1.0-beta.13` it:
///   1. Checks out `v1.1.0-beta.13` detached, so the tree is the beta's tree.
///   2. Rewrites `version:` in `pubspec.yaml` to `0.9.8`.
///   3. Rewrites the `dartastic_opentelemetry_api:` constraint to the stable
///      api line (auto-detected from the previous `0.9.x` tag, or
///      `--api-constraint`). The beta depends on an api prerelease, which a
///      caret constraint on a `0.9.x` release must not point at.
///   4. Rewrites `dartastic_opentelemetry: ^...` references in `README.md`.
///   5. Rewrites the CHANGELOG header `## [0.9.8]` (with any placeholder such
///      as `- unreleased`) to `## [0.9.8] - YYYY-MM-DD`.
///   6. Runs `dart pub get`, `dart analyze`, and the test suite.
///   7. Commits as `Release 0.9.8 — stable-channel republication of
///      1.1.0-beta.13` and tags `v0.9.8`. The commit is reachable only from
///      the tag; it is deliberately not merged to a branch.
///   8. Runs `dart pub publish` (pub.dev prompts before uploading).
///   9. Returns to the original branch, pushes the tag, and creates a GitHub
///      release from the CHANGELOG section.
///  10. Dates the `## [0.9.8]` header on the original branch too, and commits
///      it (see "the lost-entry problem" below). `--no-sync-changelog` opts out.
///
/// Usage:
///     dart tool/backport_release.dart --version 0.9.8 --from v1.1.0-beta.13
///     dart tool/backport_release.dart --version 0.9.8   # --from = latest beta tag
///     dart tool/backport_release.dart ... --api-constraint ^0.9.2
///     dart tool/backport_release.dart ... --no-publish
///     dart tool/backport_release.dart ... --skip-tests
///     dart tool/backport_release.dart ... --no-github-release
///     dart tool/backport_release.dart ... --no-sync-changelog
///     dart tool/backport_release.dart ... --yes
///
/// Design notes:
/// - **The lost-entry problem.** Releases 0.9.4 through 0.9.7 each wrote their
///   CHANGELOG entry on the release commit only. That commit is reachable from
///   the tag and was never merged, so `main`'s CHANGELOG stopped at 0.9.3 and
///   four releases went undocumented on the branch everyone reads. This script
///   inverts the order: you author the `## [X.Y.Z]` section on your branch
///   *before* running it (the script fails early if it is missing), and step 10
///   writes the release date back to the branch. The entry is on `main` by
///   construction rather than by anyone remembering.
/// - Reads the beta's tree from the tag rather than `HEAD`, so a dirty or
///   drifted working branch cannot leak into a stable-channel release.
/// - The api constraint is auto-detected from the previous `0.9.x` tag, which
///   is right only while the stable api line is unchanged. The chosen value is
///   printed prominently and confirmed before use; pass `--api-constraint` when
///   the api has cut a new stable release.
/// - Mirrors `tool/release.dart`'s line-precise editing: `pubspec.yaml` is
///   never round-tripped through a YAML printer, so comments and formatting
///   survive and only the intended lines change.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

const _pubspecPath = 'pubspec.yaml';
const _changelogPath = 'CHANGELOG.md';
const _readmePath = 'README.md';
const _versionFilePath = 'lib/src/version.dart';

/// The dependency whose constraint has to move from the prerelease api line
/// to the stable one. The beta depends on e.g. `^1.0.0-rc.1`; a `0.9.x`
/// release must depend on the api's own `0.9.x` republication.
const _backportedDep = 'dartastic_opentelemetry_api';

/// Tag pattern for the prerelease line this channel republishes.
final _betaTagRe = RegExp(r'^v1\.\d+\.\d+-beta(\.\d+)?$');

/// Tag pattern for the stable channel itself.
final _stableTagRe = RegExp(r'^v0\.\d+\.\d+$');

/// Matches a `  <name>: <constraint>` pubspec line, capturing the indentation
/// and key in group 1, the whole constraint value in group 2, and any trailing
/// whitespace or comment in group 3.
///
/// Group 2 has to take the rest of the line rather than a single `\S+` run. A
/// range constraint is quoted and contains a space, as in
/// `'>=1.0.0-rc.3 <1.0.0-rc.4'`, and `\S+` stops at that space, which would
/// read back a truncated constraint and, on rewrite, leave the tail of the old
/// one and its unbalanced quote behind.
RegExp _dependencyLineRe(String name) =>
    RegExp(r'^(\s*' + RegExp.escape(name) + r':\s*)(.*?)(\s*(?:#.*)?)$');

Future<void> main(List<String> args) async {
  final flags = _Flags.parse(args);

  if (!_isWorkingTreeClean()) {
    _die('working tree is dirty. commit or stash first.');
  }

  final version = flags.version ?? _die('--version is required (e.g. 0.9.8)');
  try {
    Version.parse(version);
  } on FormatException {
    _die('--version "$version" is not a valid semver version');
  }
  if (version.startsWith('v')) {
    _die('--version takes a bare version (0.9.8), not a tag (v0.9.8)');
  }

  final tag = 'v$version';
  if (_tagExists(tag)) {
    _die('tag $tag already exists. This release has already been cut.');
  }

  final from = flags.from ?? _latestBetaTag();
  if (!_tagExists(from)) {
    _die('--from tag "$from" does not exist locally. '
        'Run `git fetch --tags` or pass an existing tag.');
  }
  final betaVersion = from.startsWith('v') ? from.substring(1) : from;

  if (!_changelogHasSection(version)) {
    _die('CHANGELOG.md has no section for $version.\n'
        '       Expected a line like "## [$version]" (a placeholder date such\n'
        '       as "- unreleased" is fine — this script rewrites it).\n'
        '       Author the entry on this branch first: that is what keeps it\n'
        '       on the branch instead of only on the release tag.');
  }

  final apiConstraint = flags.apiConstraint ?? _previousStableApiConstraint();
  final originalRef = _currentRef();

  await _warnIfAlreadyPublished(version);

  stdout
    ..writeln()
    ..writeln('  Backport release: $version   (tag $tag)')
    ..writeln('  Republishing:     $betaVersion   (from tag $from)')
    ..writeln('  $_backportedDep: $apiConstraint'
        '${flags.apiConstraint == null ? "   <-- auto-detected from the "
            "previous 0.9.x tag; pass --api-constraint to override" : ""}')
    ..writeln('  Return to:        $originalRef')
    ..writeln(
      '  Publish:          ${flags.publish ? "yes — pub.dev will prompt before uploading" : "no — local commit + tag only"}',
    )
    ..writeln(
      '  GH release:       ${flags.publish && flags.githubRelease ? "yes — push tag, create release from CHANGELOG section" : "no"}',
    )
    ..writeln(
      '  Sync CHANGELOG:   ${flags.syncChangelog ? "yes — date the $version header on $originalRef too" : "no"}',
    )
    ..writeln();

  if (!flags.assumeYes) {
    stdout.write('Continue? [y/N] ');
    final reply = stdin.readLineSync()?.trim();
    if (reply != 'y' && reply != 'Y') {
      stdout.writeln('aborted.');
      exit(1);
    }
  }

  // The CHANGELOG section is read off the current branch before we detach,
  // because the branch is where the entry was authored. The beta's tree has
  // whatever the CHANGELOG looked like at beta-tag time, which for a
  // just-authored entry may be nothing at all.
  final changelogSection = _extractChangelogSection(version);
  if (changelogSection.isEmpty) {
    _die('the CHANGELOG section for $version is empty — nothing to '
        'release-note. Write the entry before releasing.');
  }
  final datedHeader = '## [$version] - ${_today()}';

  var tagged = false;
  try {
    // ---- stamp the beta's tree ----
    stdout.writeln('\nChecking out $from (detached) — the tree being '
        'republished...');
    _runOrThrow('git', ['checkout', '--detach', from]);

    _replaceVersionLine(to: version);
    _replaceVersionConst(to: version);
    _replaceDependencyConstraint(name: _backportedDep, to: apiConstraint);
    _replaceReadmeVersion(packageName: _readPackageName(), to: version);
    // The beta tag's CHANGELOG predates the entry we just validated on the
    // branch, so write the whole section in rather than rewriting a header
    // that may not be there.
    _upsertChangelogSection(
      version: version,
      header: datedHeader,
      body: changelogSection,
    );

    _runOrThrow('dart', ['pub', 'get'], silent: true);
    _runOrThrow('dart', ['analyze']);
    if (flags.skipTests) {
      stdout.writeln('(skipping tests — --skip-tests)');
    } else if (File('tool/test.sh').existsSync() &&
        (Platform.isMacOS || Platform.isLinux)) {
      // Same reasoning as release.dart: the suite needs an OTLP collector,
      // and tool/test.sh owns starting it.
      _runOrThrow('bash', ['tool/test.sh']);
    } else {
      _runOrThrow('dart', ['test']);
    }

    _runOrThrow('git', [
      'add',
      _pubspecPath,
      _changelogPath,
      _versionFilePath,
      if (File(_readmePath).existsSync()) _readmePath,
    ]);
    _runOrThrow('git', [
      'commit',
      '-m',
      'Release $version — stable-channel republication of $betaVersion',
    ]);
    _runOrThrow('git', ['tag', tag]);
    tagged = true;
    stdout.writeln('✓ tagged $tag');
  } catch (e) {
    stderr
      ..writeln()
      ..writeln('error: failed mid-backport: $e');
    // Never leave the user on a detached HEAD they did not ask for. The edits
    // are discarded with it: everything up to this point is reproducible by
    // rerunning, so there is nothing worth preserving in the detached tree.
    final back = Process.runSync('git', ['checkout', '-f', originalRef]);
    if (back.exitCode == 0) {
      stderr.writeln('Returned to $originalRef; the stamped edits were '
          'discarded. Rerun once the cause is fixed.');
    } else {
      stderr.writeln('WARNING: could not return to $originalRef. You are on a '
          'detached HEAD. Run: git checkout -f $originalRef');
    }
    if (tagged) {
      stderr.writeln('The $tag tag was created before the failure. '
          'Remove it before rerunning: git tag -d $tag');
    }
    stderr.writeln();
    exit(1);
  }

  // ---- publish (working tree is already the tagged tree) ----
  var published = false;
  if (flags.publish) {
    stdout
      ..writeln()
      ..writeln('About to invoke `dart pub publish` — pub.dev will print the '
          'file list and prompt for a final y/N before uploading.')
      ..writeln('The working tree is the $tag tree, so what you see in that '
          'file list is what ships.');
    published = await _runInteractive('dart', ['pub', 'publish']);
  }

  stdout.writeln('\nReturning to $originalRef...');
  _runOrThrow('git', ['checkout', originalRef]);

  if (flags.publish && !published) {
    stderr
      ..writeln()
      ..writeln('error: `dart pub publish` did not succeed.')
      ..writeln('The commit and the $tag tag are still in place. Retry with:')
      ..writeln('  git checkout $tag && dart pub publish && '
          'git checkout $originalRef')
      ..writeln();
    exit(1);
  }

  // ---- GitHub release ----
  var ghReleaseCreated = false;
  if (flags.publish && flags.githubRelease) {
    if (!_hasGhCli()) {
      stdout.writeln('\n(skipping GitHub release — `gh` CLI not found or not '
          'authenticated; pass --no-github-release to silence this)');
    } else {
      try {
        _runOrThrow('git', ['push', 'origin', tag]);
        ghReleaseCreated = await _createGitHubRelease(
          tag: tag,
          notes: changelogSection,
          // A 0.9.x republication is a stable release even though the code it
          // carries was cut as a prerelease — that is the entire point of the
          // channel, so it must not be marked prerelease on GitHub.
          prerelease: version.contains('-'),
        );
        if (!ghReleaseCreated) {
          stderr.writeln('warning: `gh release create` did not succeed. The '
              'tag is pushed; create the release manually.');
        }
      } catch (e) {
        stderr.writeln('warning: GitHub release step failed ($e). The publish '
            'succeeded — push the tag and create the release manually.');
      }
    }
  }

  // ---- date the entry on the branch (the lost-entry fix) ----
  if (flags.syncChangelog) {
    try {
      if (_changelogHasSection(version)) {
        final changed = _replaceChangelogHeader(
          version: version,
          newHeader: datedHeader,
        );
        if (changed) {
          _runOrThrow('git', ['add', _changelogPath]);
          _runOrThrow('git', [
            'commit',
            '-m',
            'Date the $version CHANGELOG entry\n\n'
                'The release commit for $tag is reachable only from the tag, '
                'so without this the dated entry would exist solely on the '
                'tag and $originalRef would keep the placeholder — which is '
                'how 0.9.4 through 0.9.7 ended up undocumented on the branch.',
          ]);
          stdout.writeln('✓ dated the $version entry on $originalRef');
        } else {
          stdout.writeln('($version entry on $originalRef already dated)');
        }
      }
    } catch (e) {
      stderr.writeln('warning: could not sync the CHANGELOG date onto '
          '$originalRef ($e). Do it by hand — otherwise this release is '
          'documented only on the tag.');
    }
  }

  stdout
    ..writeln()
    ..writeln('✓ done.')
    ..writeln();
  if (ghReleaseCreated) {
    stdout.writeln('Released $version on pub.dev and GitHub.');
  } else {
    stdout
      ..writeln('Next steps:')
      ..writeln('  git push origin $tag');
    if (!flags.publish) {
      stdout
        ..writeln('  git checkout $tag')
        ..writeln('  dart pub publish')
        ..writeln('  git checkout $originalRef');
    }
  }
  if (flags.syncChangelog) {
    stdout.writeln('  git push origin $originalRef   '
        '# the dated CHANGELOG entry');
  }
  stdout
    ..writeln()
    ..writeln('To roll back before pushing:')
    ..writeln('  git tag -d $tag')
    ..writeln()
    ..writeln('If a security advisory covers this release, it can be '
        'published now that $version exists on pub.dev.')
    ..writeln();
}

// ---------------------------------------------------------------------------
// Version / tag discovery
// ---------------------------------------------------------------------------

bool _tagExists(String tag) =>
    Process.runSync(
            'git', ['rev-parse', '--verify', '--quiet', 'refs/tags/$tag'])
        .exitCode ==
    0;

List<String> _tagsMatching(RegExp re) {
  final r = Process.runSync('git', ['tag', '--list']);
  if (r.exitCode != 0) _die('git tag --list failed:\n${r.stderr}');
  return (r.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where(re.hasMatch)
      .toList();
}

/// Sorts tags by their parsed semver so `beta.10` follows `beta.9` rather
/// than sorting lexically between `beta.1` and `beta.2`.
List<String> _sortedBySemver(List<String> tags) {
  final parsed = <MapEntry<String, Version>>[];
  for (final t in tags) {
    try {
      parsed.add(MapEntry(t, Version.parse(t.substring(1))));
    } on FormatException {
      // Not a version tag we understand — ignore it.
    }
  }
  parsed.sort((a, b) => a.value.compareTo(b.value));
  return parsed.map((e) => e.key).toList();
}

String _latestBetaTag() {
  final tags = _sortedBySemver(_tagsMatching(_betaTagRe));
  if (tags.isEmpty) {
    _die('no v1.x.y-beta[.n] tags found — pass --from explicitly.');
  }
  return tags.last;
}

/// Reads the `_backportedDep` constraint from the most recent stable `0.x` tag.
/// That is the constraint the previous republication shipped, which is right
/// as long as the stable api line has not moved since.
String _previousStableApiConstraint() {
  final tags = _sortedBySemver(_tagsMatching(_stableTagRe));
  for (final t in tags.reversed) {
    final r = Process.runSync('git', ['show', '$t:$_pubspecPath']);
    if (r.exitCode != 0) continue;
    for (final line in (r.stdout as String).split('\n')) {
      final m = _dependencyLineRe(_backportedDep).firstMatch(line);
      // An empty group 2 is a `name:` key with the constraint nested beneath
      // it, such as a path or git dependency. Not a constraint we can read.
      if (m != null && m.group(2)!.isNotEmpty) return m.group(2)!;
    }
  }
  _die('could not auto-detect the $_backportedDep constraint from any stable '
      'v0.x tag; pass --api-constraint (e.g. --api-constraint ^0.11.0).');
}

/// Warns (does not fail) if pub.dev already lists this version. A soft check:
/// no network, or an unexpected response, must not block a release.
Future<void> _warnIfAlreadyPublished(String version) async {
  final name = _readPackageName();
  try {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final req =
        await client.getUrl(Uri.parse('https://pub.dev/api/packages/$name'));
    final res = await req.close();
    if (res.statusCode != 200) {
      client.close();
      return;
    }
    final body = await res.transform(utf8.decoder).join();
    client.close();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return;
    final versions = decoded['versions'];
    if (versions is! List) return;
    final exists = versions.any((v) => v is Map && v['version'] == version);
    if (exists) {
      stderr.writeln('\nwarning: pub.dev already lists $name $version. '
          'Publishing will fail — pub.dev versions are immutable.');
    }
  } catch (_) {
    // Offline or pub.dev unreachable: not a reason to stop a release.
  }
}

// ---------------------------------------------------------------------------
// pubspec / README / CHANGELOG writers (line-precise, as in release.dart)
// ---------------------------------------------------------------------------

String _readPackageName() {
  for (final line in File(_pubspecPath).readAsLinesSync()) {
    final m = RegExp(r'^name:\s*(\S+)').firstMatch(line);
    if (m != null) return m.group(1)!;
  }
  _die('no `name:` line in $_pubspecPath');
}

void _replaceVersionLine({required String to}) {
  final f = File(_pubspecPath);
  final lines = f.readAsLinesSync();
  var replaced = false;
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('version:')) continue;
    lines[i] = 'version: $to';
    replaced = true;
    break;
  }
  if (!replaced) throw StateError('no `version:` line in $_pubspecPath');
  f.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ pubspec version -> $to');
}

/// Rewrites the stamped `packageVersion` const in lib/src/version.dart
/// (see issue #249), so the backported release identifies itself as its own
/// version rather than the beta's. Throws if the line is missing so a moved
/// or hand-edited file fails the release loudly.
void _replaceVersionConst({required String to}) {
  final f = File(_versionFilePath);
  final lines = f.readAsLinesSync();
  final re = RegExp(r"^const String packageVersion = '.*';$");
  var replaced = false;
  for (var i = 0; i < lines.length; i++) {
    if (!re.hasMatch(lines[i])) continue;
    lines[i] = "const String packageVersion = '$to';";
    replaced = true;
    break;
  }
  if (!replaced) {
    throw StateError(
      'did not find the packageVersion const in $_versionFilePath',
    );
  }
  f.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ $_versionFilePath -> $to');
}

/// Rewrites `  <name>: <constraint>` in place, preserving indentation and any
/// trailing comment on the line.
void _replaceDependencyConstraint({
  required String name,
  required String to,
}) {
  final f = File(_pubspecPath);
  final lines = f.readAsLinesSync();
  final re = _dependencyLineRe(name);
  var replaced = false;
  for (var i = 0; i < lines.length; i++) {
    final m = re.firstMatch(lines[i]);
    if (m == null || m.group(2)!.isEmpty) continue;
    final was = m.group(2)!;
    lines[i] = '${m.group(1)}$to${m.group(3)}';
    replaced = true;
    stdout.writeln('✓ $name: $was -> $to');
    break;
  }
  if (!replaced) {
    throw StateError('no `$name:` dependency line in $_pubspecPath');
  }
  f.writeAsStringSync('${lines.join('\n')}\n');
}

/// Bumps every `<packageName>: ^X.Y.Z` reference in the README, matching by
/// package name rather than by old version, exactly as release.dart does.
int _replaceReadmeVersion({required String packageName, required String to}) {
  final f = File(_readmePath);
  if (!f.existsSync()) return 0;
  final original = f.readAsStringSync();
  final pattern = RegExp(r'(\b' + RegExp.escape(packageName) + r':\s*\^)\S+');
  var count = 0;
  final updated = original.replaceAllMapped(pattern, (m) {
    count++;
    return '${m.group(1)}$to';
  });
  if (count > 0 && updated != original) {
    f.writeAsStringSync(updated);
    stdout.writeln('✓ updated $count README reference(s) to ^$to');
  }
  return count;
}

RegExp _changelogHeaderRegex(String version) =>
    RegExp(r'^##[ \t]*\[?' + RegExp.escape(version) + r'\]?([ \t]|$)');

bool _changelogHasSection(String version) => File(_changelogPath)
    .readAsLinesSync()
    .any(_changelogHeaderRegex(version).hasMatch);

/// Returns the body between this version's header and the next `## ` header.
String _extractChangelogSection(String version) {
  final lines = File(_changelogPath).readAsLinesSync();
  final start = lines.indexWhere(_changelogHeaderRegex(version).hasMatch);
  if (start < 0) return '';
  var end = lines.length;
  for (var i = start + 1; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) {
      end = i;
      break;
    }
  }
  return lines.sublist(start + 1, end).join('\n').trim();
}

/// Replaces this version's header line with [newHeader]. Returns whether the
/// file actually changed.
bool _replaceChangelogHeader({
  required String version,
  required String newHeader,
}) {
  final f = File(_changelogPath);
  final lines = f.readAsLinesSync();
  final i = lines.indexWhere(_changelogHeaderRegex(version).hasMatch);
  if (i < 0) return false;
  if (lines[i] == newHeader) return false;
  lines[i] = newHeader;
  f.writeAsStringSync('${lines.join('\n')}\n');
  return true;
}

/// Ensures the CHANGELOG carries `[header]` + [body] for this version. If the
/// tree already has a section (the beta's own CHANGELOG might), its header is
/// corrected in place; otherwise the section is inserted below the preamble.
void _upsertChangelogSection({
  required String version,
  required String header,
  required String body,
}) {
  final f = File(_changelogPath);
  final lines = f.readAsLinesSync();
  final existing = lines.indexWhere(_changelogHeaderRegex(version).hasMatch);
  if (existing >= 0) {
    lines[existing] = header;
    f.writeAsStringSync('${lines.join('\n')}\n');
    stdout.writeln('✓ CHANGELOG header -> $header');
    return;
  }
  // Insert above the first existing version section, which keeps the file's
  // preamble (title, Keep a Changelog blurb) intact.
  var insertAt = lines.indexWhere((l) => l.startsWith('## '));
  if (insertAt < 0) insertAt = lines.length;
  lines.insertAll(insertAt, [header, '', body, '']);
  f.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ inserted CHANGELOG section $header');
}

// ---------------------------------------------------------------------------
// GitHub release
// ---------------------------------------------------------------------------

bool _hasGhCli() {
  try {
    if (Process.runSync('gh', ['--version']).exitCode != 0) return false;
  } catch (_) {
    return false;
  }
  return Process.runSync('gh', ['auth', 'status']).exitCode == 0;
}

Future<bool> _createGitHubRelease({
  required String tag,
  required String notes,
  required bool prerelease,
}) async {
  stdout.writeln('\$ gh release create $tag --title $tag --notes-file -'
      '${prerelease ? ' --prerelease' : ''}');
  final p = await Process.start('gh', [
    'release',
    'create',
    tag,
    '--title',
    tag,
    '--notes-file',
    '-',
    if (prerelease) '--prerelease',
  ]);
  p.stdin.write(notes);
  await p.stdin.close();
  final outF = p.stdout.transform(const SystemEncoding().decoder).join();
  final errF = p.stderr.transform(const SystemEncoding().decoder).join();
  final code = await p.exitCode;
  final out = await outF;
  final err = await errF;
  if (out.isNotEmpty) stdout.write(out);
  if (err.isNotEmpty) stderr.write(err);
  return code == 0;
}

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------

class _Flags {
  _Flags({
    required this.version,
    required this.from,
    required this.apiConstraint,
    required this.assumeYes,
    required this.publish,
    required this.skipTests,
    required this.githubRelease,
    required this.syncChangelog,
  });

  final String? version;
  final String? from;
  final String? apiConstraint;
  final bool assumeYes;
  final bool publish;
  final bool skipTests;
  final bool githubRelease;
  final bool syncChangelog;

  static _Flags parse(List<String> args) {
    String? version;
    String? from;
    String? apiConstraint;
    var assumeYes = false;
    var publish = true;
    var skipTests = false;
    var githubRelease = true;
    var syncChangelog = true;

    String next(int i, String flag) {
      if (i + 1 >= args.length) _die('$flag needs a value');
      return args[i + 1];
    }

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--version':
          version = next(i, '--version');
          i++;
        case '--from':
          from = next(i, '--from');
          i++;
        case '--api-constraint':
          apiConstraint = next(i, '--api-constraint');
          i++;
        case '--yes':
        case '-y':
          assumeYes = true;
        case '--no-publish':
          publish = false;
        case '--skip-tests':
          skipTests = true;
        case '--no-github-release':
          githubRelease = false;
        case '--no-sync-changelog':
          syncChangelog = false;
        case '--help':
        case '-h':
          _printUsage();
          exit(0);
        default:
          _die('unknown argument: ${args[i]}\nRun with --help for usage.');
      }
    }
    return _Flags(
      version: version,
      from: from,
      apiConstraint: apiConstraint,
      assumeYes: assumeYes,
      publish: publish,
      skipTests: skipTests,
      githubRelease: githubRelease,
      syncChangelog: syncChangelog,
    );
  }
}

void _printUsage() {
  stdout.writeln('''
Backport release — republish a 1.1.0-beta.x release on the 0.9.x channel.
Run after `dart tool/release.dart` has published the beta.

  dart tool/backport_release.dart --version 0.9.8 [--from v1.1.0-beta.13]

  --version X.Y.Z         the 0.9.x version to publish (required)
  --from vX.Y.Z-beta.N    beta tag to republish (default: latest beta tag)
  --api-constraint ^X.Y.Z $_backportedDep constraint
                          (default: whatever the previous v0.9.x tag used)
  --no-publish            local commit + tag only
  --skip-tests            skip the test suite
  --no-github-release     skip pushing the tag and creating the release
  --no-sync-changelog     do not date the entry on the current branch
  --yes, -y               non-interactive confirm
  --help, -h              this message

The CHANGELOG section for the target version must already exist on the
current branch — author it before running this.''');
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

bool _isWorkingTreeClean() {
  final r = Process.runSync('git', ['status', '--porcelain']);
  if (r.exitCode != 0) _die('git status failed:\n${r.stderr}');
  return (r.stdout as String).trim().isEmpty;
}

String _currentRef() {
  final symbolic = Process.runSync('git', ['symbolic-ref', '--quiet', 'HEAD']);
  if (symbolic.exitCode == 0) {
    final ref = (symbolic.stdout as String).trim();
    return ref.startsWith('refs/heads/')
        ? ref.substring('refs/heads/'.length)
        : ref;
  }
  final sha = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (sha.exitCode != 0) _die('cannot resolve HEAD');
  return (sha.stdout as String).trim();
}

String _today() {
  final n = DateTime.now();
  String pad(int v, [int w = 2]) => v.toString().padLeft(w, '0');
  return '${pad(n.year, 4)}-${pad(n.month)}-${pad(n.day)}';
}

void _runOrThrow(String exe, List<String> args, {bool silent = false}) {
  if (!silent) stdout.writeln('\$ $exe ${args.join(' ')}');
  final r = Process.runSync(exe, args, runInShell: false);
  if (!silent) {
    stdout.write(r.stdout);
    stderr.write(r.stderr);
  }
  if (r.exitCode != 0) {
    throw StateError('$exe ${args.join(' ')} failed (exit ${r.exitCode})');
  }
}

Future<bool> _runInteractive(String exe, List<String> args) async {
  stdout.writeln('\$ $exe ${args.join(' ')}');
  final p = await Process.start(exe, args, mode: ProcessStartMode.inheritStdio);
  return await p.exitCode == 0;
}

Never _die(String msg) {
  stderr.writeln('error: $msg');
  exit(1);
}
