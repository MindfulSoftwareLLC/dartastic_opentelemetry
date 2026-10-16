// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Cross-post release script: republishes `dartastic_opentelemetry`
/// `1.1.0-beta.N` as `opentelemetry` `1.0.0-beta.N`.
///
/// Each SDK release is three publications:
///   1. `dart tool/release.dart` publishes `dartastic_opentelemetry`
///      `1.1.0-beta.N`.
///   2. `dart tool/backport_release.dart` republishes it on the `0.x` stable
///      channel.
///   3. This script cross-posts it to `opentelemetry`, the name the official
///      OpenTelemetry SDK for Dart will be published under from
///      open-telemetry/opentelemetry-dart once the donation is complete
///      (https://dartastic.io/blog/open-source-donation-plan/).
///
/// The `opentelemetry` package lives in `opentelemetry/` and holds no SDK
/// code. `lib/opentelemetry.dart` re-exports `dartastic_opentelemetry`, and
/// `pubspec.yaml` admits only the release it cross-posts, so an app that
/// mixes the two imports still has a single `OTel`.
///
/// Run it on the `workiva_opentelemetry` branch, after steps 1 and 2 have
/// pushed their tags:
///
///     git fetch --tags && git checkout workiva_opentelemetry
///     dart tool/opentelemetry_release.dart
///     git checkout main
///
/// Given `--from v1.1.0-beta.17` it:
///   1. Checks that pub.dev already lists `dartastic_opentelemetry`
///      `1.1.0-beta.17`, since the cross-post depends on it.
///   2. Sets `opentelemetry/pubspec.yaml` to `version: 1.0.0-beta.17` and
///      `dartastic_opentelemetry: '>=1.1.0-beta.17 <1.1.0-beta.18'`.
///   3. Regenerates everything below the cross-post marker in
///      `opentelemetry/README.md` from the tag's README. The install line and
///      imports are pointed at `opentelemetry`, and relative links are made
///      absolute at the tag. The notice above the marker is hand-written.
///   4. Writes a dated `## [1.0.0-beta.17]` section into
///      `opentelemetry/CHANGELOG.md` that carries the beta's own entry, and
///      copies `example/example.dart` (imports rewritten), `LICENSE` and
///      `NOTICE` from the tag.
///   5. Runs `dart pub get`, `dart format` and `dart analyze` in
///      `opentelemetry/`.
///   6. Commits as `Release opentelemetry 1.0.0-beta.17`, runs
///      `dart pub publish --dry-run` on the committed tree, and tags
///      `opentelemetry-v1.0.0-beta.17`.
///   7. Runs `dart pub publish` in `opentelemetry/` (pub.dev prompts before
///      uploading).
///   8. Pushes the branch and tag to origin, then creates a prerelease GitHub
///      release from the new CHANGELOG section.
///
/// Usage:
///     dart tool/opentelemetry_release.dart                  # --from = latest beta tag
///     dart tool/opentelemetry_release.dart --from v1.1.0-beta.17
///     dart tool/opentelemetry_release.dart ... --version 1.0.0-beta.17
///     dart tool/opentelemetry_release.dart ... --dry-run    # regenerate + validate only
///     dart tool/opentelemetry_release.dart ... --no-publish
///     dart tool/opentelemetry_release.dart ... --no-github-release
///     dart tool/opentelemetry_release.dart ... --yes
///
/// Design notes:
/// - `workiva_opentelemetry` is a publishing branch and is never merged to
///   `main`. Pub publishes every tracked file, so on `main` the SDK's archive
///   would carry `opentelemetry/`. A root `.pubignore` cannot leave it out:
///   pub applies the parent directory's ignore rules when publishing the
///   nested package too, which hides its pubspec. The SDK code on this branch
///   is never read; everything comes from the beta tag.
/// - The release commit is on the branch, not only on the tag as in the
///   backport. The package's files are small and generated, and keeping them
///   on the branch is what makes the published README and CHANGELOG
///   reviewable, keeps the CHANGELOG history from being lost, and gives the
///   pubspec's `repository:` URL a pubspec to verify.
/// - Tags are prefixed `opentelemetry-` so they never match the `v1.x-beta`
///   and `v0.x` patterns that release.dart and backport_release.dart search.
/// - Everything is read from the tag with `git show`, never from the working
///   tree, so what is cross-posted is the published beta's README and
///   CHANGELOG even if the branch has moved on.
/// - Like the other release scripts, `pubspec.yaml` is edited line by line
///   and never round-tripped through a YAML printer.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

/// The cross-posted package's directory, relative to the repo root.
const _pkgDir = 'opentelemetry';
const _pkgName = 'opentelemetry';

/// The package being cross-posted, and the GitHub repo its tags live in.
const _sdkName = 'dartastic_opentelemetry';
const _sdkRepo =
    'https://github.com/MindfulSoftwareLLC/dartastic_opentelemetry';
const _sdkRawRepo =
    'https://raw.githubusercontent.com/MindfulSoftwareLLC/dartastic_opentelemetry';

const _tagPrefix = 'opentelemetry-v';

/// The publishing branch; the pubspec's `repository:` URL names it.
const _branch = 'workiva_opentelemetry';

/// Separates the hand-written notice at the top of the cross-post README from
/// the part this script regenerates.
const _readmeMarker =
    '<!-- cross-post: everything below this line is generated by '
    'tool/opentelemetry_release.dart from the dartastic_opentelemetry README. '
    'Edit only above it. -->';

/// The library and testing imports, mapped to their cross-post equivalents.
const _importRewrites = {
  'package:$_sdkName/$_sdkName.dart': 'package:$_pkgName/$_pkgName.dart',
  'package:$_sdkName/testing.dart': 'package:$_pkgName/testing.dart',
};

/// Tag pattern for the prerelease line being cross-posted, as in
/// backport_release.dart.
final _betaTagRe = RegExp(r'^v1\.\d+\.\d+-beta(\.\d+)?$');

String get _pubspecPath => '$_pkgDir/pubspec.yaml';
String get _readmePath => '$_pkgDir/README.md';
String get _changelogPath => '$_pkgDir/CHANGELOG.md';

/// Matches a `  <name>: <constraint>` pubspec line; see backport_release.dart
/// for why group 2 takes the rest of the line.
RegExp _dependencyLineRe(String name) =>
    RegExp(r'^(\s*' + RegExp.escape(name) + r':\s*)(.*?)(\s*(?:#.*)?)$');

Future<void> main(List<String> args) async {
  final flags = _Flags.parse(args);

  if (!File(_pubspecPath).existsSync()) {
    _die('no $_pubspecPath. Run this from the repo root.');
  }
  if (!_isWorkingTreeClean()) {
    _die('working tree is dirty. commit or stash first.');
  }

  final from = flags.from ?? _latestBetaTag();
  if (!_tagExists(from)) {
    _die('--from tag "$from" does not exist locally. '
        'Run `git fetch --tags` or pass an existing tag.');
  }
  final betaVersion = from.startsWith('v') ? from.substring(1) : from;
  final version = flags.version ?? _defaultVersion(betaVersion);
  try {
    Version.parse(version);
  } on FormatException {
    _die('--version "$version" is not a valid semver version');
  }
  final tag = '$_tagPrefix$version';
  if (_tagExists(tag)) {
    _die('tag $tag already exists. This cross-post has already been cut.');
  }
  if (!File(_readmePath).readAsStringSync().contains(_readmeMarker)) {
    _die('$_readmePath has lost its cross-post marker line. Restore it:\n'
        '       $_readmeMarker');
  }

  final originalRef = _currentRef();
  if (originalRef != _branch && !flags.dryRun) {
    _die('on "$originalRef". Cross-posts are released from $_branch, the '
        'branch the\n'
        '       pubspec\'s repository URL names: git checkout $_branch');
  }
  await _checkPubDev(betaVersion: betaVersion, version: version);

  stdout
    ..writeln()
    ..writeln('  Cross-post:   $_pkgName $version   (tag $tag)')
    ..writeln('  Re-exports:   $_sdkName $betaVersion   (from tag $from)')
    ..writeln('  Branch:       $originalRef')
    ..writeln(
      '  Mode:         ${flags.dryRun ? "dry run — regenerate and validate, no commit" : "release"}',
    )
    ..writeln(
      '  Publish:      ${!flags.dryRun && flags.publish ? "yes — pub.dev will prompt before uploading" : "no"}',
    )
    ..writeln(
      '  GH release:   ${!flags.dryRun && flags.publish && flags.githubRelease ? "yes — push, then create release from CHANGELOG section" : "no"}',
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

  final String notes;
  var committed = false;
  var tagged = false;
  try {
    // ---- regenerate the package from the tag ----
    _replaceVersionLine(to: version);
    _replaceDependencyConstraint(
      name: _sdkName,
      to: _onlyReleaseConstraint(betaVersion),
    );
    _regenerateReadme(from: from, version: version);
    notes = _upsertChangelogSection(
      from: from,
      betaVersion: betaVersion,
      version: version,
    );
    _writeFromTag(from, 'example/example.dart', rewriteImports: true);
    _writeFromTag(from, 'LICENSE');
    _writeFromTag(from, 'NOTICE');

    // ---- validate ----
    _runOrThrow('dart', ['pub', 'get'], silent: true);
    _runOrThrow(
        'dart', ['format', '--output=none', '--set-exit-if-changed', '.']);
    _runOrThrow('dart', ['analyze', '--fatal-infos']);

    if (flags.dryRun) {
      // pub's validation warns that regenerated files are modified in git,
      // so a warning (exit 65) is expected here and not fatal. The real
      // release validates again after committing, with no slack.
      _runOrThrow('dart', ['pub', 'publish', '--dry-run'], allowExit: 65);
      stdout.writeln();
      if (_isWorkingTreeClean()) {
        stdout
          ..writeln('✓ dry run done. $_pkgDir/ already matches what $from '
              'generates; nothing changed.')
          ..writeln();
      } else {
        stdout
          ..writeln('✓ dry run done. The regenerated files in $_pkgDir/ are '
              'uncommitted:')
          ..writeln('  git status -- $_pkgDir && git diff -- $_pkgDir')
          ..writeln('Discard them with:')
          ..writeln('  git checkout -- $_pkgDir && git clean -fd -- $_pkgDir')
          ..writeln();
      }
      return;
    }

    // ---- commit, validate the committed tree, tag ----
    _runOrThrow('git', ['add', '--', _pkgDir], inPackage: false);
    final staged = Process.runSync('git', ['diff', '--cached', '--quiet']);
    if (staged.exitCode == 0) {
      stdout.writeln('($_pkgDir/ already matches $from; tagging HEAD)');
    } else {
      _runOrThrow(
        'git',
        [
          'commit',
          '-m',
          'Release $_pkgName $version, cross-post of $_sdkName $betaVersion',
        ],
        inPackage: false,
      );
      committed = true;
    }
    _runOrThrow('dart', ['pub', 'publish', '--dry-run']);
    _runOrThrow('git', ['tag', tag], inPackage: false);
    tagged = true;
    stdout.writeln('✓ tagged $tag');
  } catch (e) {
    stderr
      ..writeln()
      ..writeln('error: failed mid-release: $e')
      ..writeln('To recover:');
    if (committed) {
      stderr.writeln('  git reset --hard HEAD~1   # drops the release commit');
    } else {
      stderr.writeln('  git checkout -- $_pkgDir && git clean -fd -- $_pkgDir');
    }
    if (tagged) stderr.writeln('  git tag -d $tag');
    stderr.writeln();
    exit(1);
  }

  // ---- publish (the working tree is the tagged tree) ----
  if (flags.publish) {
    stdout
      ..writeln()
      ..writeln(
          'About to invoke `dart pub publish` in $_pkgDir/ — pub.dev will '
          'print the file list and prompt for a final y/N before uploading.');
    final ok = await _runInteractive('dart', ['pub', 'publish']);
    if (!ok) {
      stderr
        ..writeln()
        ..writeln('error: `dart pub publish` did not succeed.')
        ..writeln('The commit and the $tag tag are still in place. Retry with:')
        ..writeln('  git checkout $tag && (cd $_pkgDir && dart pub publish) '
            '&& git checkout $originalRef')
        ..writeln();
      exit(1);
    }
  }

  // ---- push, independent of gh, as in release.dart ----
  var pushed = false;
  if (flags.publish) {
    try {
      _runOrThrow('git', ['push', 'origin', originalRef, tag],
          inPackage: false);
      pushed = true;
    } catch (e) {
      stderr.writeln(
        'warning: pushing $originalRef and $tag to origin failed ($e). '
        'pub.dev has the release; push manually so the tag is not local only.',
      );
    }
  }

  // ---- GitHub release ----
  var ghReleaseCreated = false;
  if (flags.publish && flags.githubRelease) {
    if (!pushed) {
      stderr.writeln('warning: skipping the GitHub release because the push '
          'failed, so there is no tag on origin to attach it to.');
    } else if (!_hasGhCli()) {
      stderr.writeln('warning: skipping the GitHub release, `gh` CLI not found '
          'or not authenticated. The branch and tag are pushed; create the '
          'release manually, or pass --no-github-release to silence this.');
    } else {
      try {
        ghReleaseCreated = await _createGitHubRelease(
          tag: tag,
          notes: notes,
          prerelease: version.contains('-'),
        );
        if (!ghReleaseCreated) {
          stderr.writeln('warning: `gh release create` did not succeed. The '
              'tag is pushed; create the release manually.');
        }
      } catch (e) {
        stderr.writeln('warning: GitHub release step failed ($e). The publish '
            'and the push both succeeded; create the release manually.');
      }
    }
  }

  stdout
    ..writeln()
    ..writeln('✓ done.')
    ..writeln();
  if (ghReleaseCreated) {
    stdout.writeln('Released $_pkgName $version on pub.dev and GitHub.');
  } else {
    stdout.writeln('Next steps:');
    if (!pushed) stdout.writeln('  git push origin $originalRef $tag');
    if (!flags.publish) {
      stdout.writeln('  (cd $_pkgDir && dart pub publish)');
    }
  }
  stdout
    ..writeln()
    ..writeln('To roll back before pushing:')
    ..writeln('  git tag -d $tag')
    ..writeln('  git reset --hard HEAD~1   # only if a release commit was made')
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

String _latestBetaTag() {
  final r = Process.runSync('git', ['tag', '--list']);
  if (r.exitCode != 0) _die('git tag --list failed:\n${r.stderr}');
  final parsed = <MapEntry<String, Version>>[];
  for (final t in (r.stdout as String).split('\n').map((s) => s.trim())) {
    if (!_betaTagRe.hasMatch(t)) continue;
    try {
      parsed.add(MapEntry(t, Version.parse(t.substring(1))));
    } on FormatException {
      // Not a version tag we understand — ignore it.
    }
  }
  if (parsed.isEmpty) {
    _die('no v1.x.y-beta[.n] tags found — pass --from explicitly.');
  }
  // Sort by semver so `beta.10` follows `beta.9`.
  parsed.sort((a, b) => a.value.compareTo(b.value));
  return parsed.last.key;
}

/// `1.1.0-beta.N` cross-posts as `1.0.0-beta.N`, keeping the beta number
/// so either version names the other. Anything else needs `--version`.
String _defaultVersion(String betaVersion) {
  final m = RegExp(r'^1\.1\.0-beta\.(\d+)$').firstMatch(betaVersion);
  if (m == null) {
    _die('cannot derive the $_pkgName version from $betaVersion.\n'
        '       Pass --version explicitly.');
  }
  return '1.0.0-beta.${m.group(1)}';
}

/// The constraint that admits [betaVersion] and no later beta, in the form
/// PUBLICATION_CHECKLIST.md requires for a prerelease dependency:
/// `'>=1.1.0-beta.17 <1.1.0-beta.18'`. pub warns on an exact pin, and a
/// caret would let `1.0.0-beta.17` resolve to a later beta's code.
String _onlyReleaseConstraint(String betaVersion) {
  final m = RegExp(r'^(.*\.)(\d+)$').firstMatch(betaVersion);
  if (m == null) {
    _die('cannot compute the next prerelease after $betaVersion for the '
        '$_sdkName constraint.');
  }
  final next = '${m.group(1)}${int.parse(m.group(2)!) + 1}';
  return "'>=$betaVersion <$next'";
}

/// Fails if pub.dev does not list [betaVersion] of the SDK yet, since the
/// cross-post depends on it, and warns if [version] of the cross-post is
/// already there. Being offline is a warning, not a failure: `dart pub get`
/// fails later with its own message if the SDK release really is missing.
Future<void> _checkPubDev({
  required String betaVersion,
  required String version,
}) async {
  final sdkVersions = await _pubDevVersions(_sdkName);
  if (sdkVersions == null) {
    stderr.writeln('warning: could not reach pub.dev to check that '
        '$_sdkName $betaVersion is published.');
  } else if (!sdkVersions.contains(betaVersion)) {
    _die('pub.dev does not list $_sdkName $betaVersion yet.\n'
        '       Publish it with `dart tool/release.dart` first: the cross-post '
        'depends on it.');
  }
  final ownVersions = await _pubDevVersions(_pkgName);
  if (ownVersions != null && ownVersions.contains(version)) {
    stderr.writeln('\nwarning: pub.dev already lists $_pkgName $version. '
        'Publishing will fail — pub.dev versions are immutable.');
  }
}

/// The versions pub.dev lists for [name], or null if it can't be reached.
Future<Set<String>?> _pubDevVersions(String name) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req =
        await client.getUrl(Uri.parse('https://pub.dev/api/packages/$name'));
    final res = await req.close();
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(await res.transform(utf8.decoder).join());
    if (decoded is! Map<String, dynamic>) return null;
    final versions = decoded['versions'];
    if (versions is! List) return null;
    return {
      for (final v in versions)
        if (v is Map && v['version'] is String) v['version'] as String,
    };
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

// ---------------------------------------------------------------------------
// Generated files
// ---------------------------------------------------------------------------

/// Reads [path] as it is at [ref].
String _gitShow(String ref, String path) {
  final r = Process.runSync('git', ['show', '$ref:$path']);
  if (r.exitCode != 0) {
    throw StateError('git show $ref:$path failed:\n${r.stderr}');
  }
  return r.stdout as String;
}

bool _existsAt(String ref, String path) =>
    Process.runSync('git', ['cat-file', '-e', '$ref:$path']).exitCode == 0;

String _rewriteImports(String text) {
  var out = text;
  for (final MapEntry(:key, :value) in _importRewrites.entries) {
    out = out.replaceAll(key, value);
  }
  return out;
}

/// Copies [path] from [ref] into the package at the same relative path.
void _writeFromTag(String ref, String path, {bool rewriteImports = false}) {
  var text = _gitShow(ref, path);
  if (rewriteImports) text = _rewriteImports(text);
  final f = File('$_pkgDir/$path');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(text);
  stdout.writeln('✓ $_pkgDir/$path <- $ref');
}

/// Keeps the README above the marker and replaces everything below it with
/// the tag's README, adapted to the cross-post.
void _regenerateReadme({required String from, required String version}) {
  final f = File(_readmePath);
  final current = f.readAsStringSync();
  final notice = current.substring(
    0,
    current.indexOf(_readmeMarker) + _readmeMarker.length,
  );

  var body = _rewriteImports(_gitShow(from, 'README.md'));

  // The install snippet: `dartastic_opentelemetry: ^1.1.0-beta.N`.
  body = body.replaceAllMapped(
    RegExp(r'\b' + RegExp.escape(_sdkName) + r':(\s*)\^\S+'),
    (m) => '$_pkgName:${m[1]}^$version',
  );

  // Relative links and images point into the SDK repo, which this package
  // does not contain, so pin them to the tag. Only paths that exist at the
  // tag are rewritten, which keeps code such as `handlers[i](event)` intact.
  body = body.replaceAllMapped(
    RegExp(r'(!?)\[([^\]]*)\]\(([^)\s]+)\)'),
    (m) {
      final image = m[1]!;
      final target = m[3]!;
      if (target.contains(':') || target.startsWith('#')) return m[0]!;
      final hash = target.indexOf('#');
      final path = hash < 0 ? target : target.substring(0, hash);
      if (!_existsAt(from, path)) return m[0]!;
      final base =
          image.isEmpty ? '$_sdkRepo/blob/$from' : '$_sdkRawRepo/$from';
      return '$image[${m[2]}]($base/$target)';
    },
  );

  f.writeAsStringSync('$notice\n\n${body.trimLeft()}');
  stdout.writeln('✓ $_readmePath regenerated from $from:README.md');
}

RegExp _changelogHeaderRegex(String version) => RegExp(
      r'^##[ \t]*\[?' + RegExp.escape(version) + r'\]?([ \t]|$)',
    );

/// Returns the body between [version]'s header and the next `## ` header.
String _extractChangelogSection(List<String> lines, String version) {
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

/// Writes the dated `## [version]` section, carrying the beta's own entry,
/// above the existing sections, replacing any earlier copy of it so a rerun
/// is idempotent. Returns the section body, for the GitHub release notes.
String _upsertChangelogSection({
  required String from,
  required String betaVersion,
  required String version,
}) {
  final betaEntry = _extractChangelogSection(
      _gitShow(from, 'CHANGELOG.md').split('\n'), betaVersion);
  if (betaEntry.isEmpty) {
    throw StateError('$from:CHANGELOG.md has no entry for $betaVersion');
  }
  final body = 'Cross-post of [`$_sdkName` $betaVersion]'
      '(https://pub.dev/packages/$_sdkName/versions/$betaVersion), which this '
      'release is pinned to and re-exports. Its CHANGELOG entry follows.'
      '\n\n$betaEntry';

  final f = File(_changelogPath);
  final lines = f.readAsLinesSync();
  final existing = lines.indexWhere(_changelogHeaderRegex(version).hasMatch);
  if (existing >= 0) {
    var end = lines.length;
    for (var i = existing + 1; i < lines.length; i++) {
      if (lines[i].startsWith('## ')) {
        end = i;
        break;
      }
    }
    lines.removeRange(existing, end);
  }
  var insertAt = lines.indexWhere((l) => l.startsWith('## '));
  if (insertAt < 0) {
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    lines.add('');
    insertAt = lines.length;
  }
  lines.insertAll(insertAt, ['## [$version] - ${_today()}', '', body, '']);
  f.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ $_changelogPath section ## [$version]');
  return body;
}

// ---------------------------------------------------------------------------
// pubspec writers (line-precise, as in release.dart)
// ---------------------------------------------------------------------------

void _replaceVersionLine({required String to}) {
  final f = File(_pubspecPath);
  final lines = f.readAsLinesSync();
  final i = lines.indexWhere((l) => l.startsWith('version:'));
  if (i < 0) throw StateError('no `version:` line in $_pubspecPath');
  lines[i] = 'version: $to';
  f.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ $_pubspecPath version -> $to');
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
    lines[i] = '${m.group(1)}$to${m.group(3)}';
    replaced = true;
    break;
  }
  if (!replaced) {
    throw StateError('no `$name:` dependency line in $_pubspecPath');
  }
  f.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('✓ $_pubspecPath $name: $to');
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
    required this.from,
    required this.version,
    required this.assumeYes,
    required this.dryRun,
    required this.publish,
    required this.githubRelease,
  });

  final String? from;
  final String? version;
  final bool assumeYes;
  final bool dryRun;
  final bool publish;
  final bool githubRelease;

  static _Flags parse(List<String> args) {
    String? from;
    String? version;
    var assumeYes = false;
    var dryRun = false;
    var publish = true;
    var githubRelease = true;

    String next(int i, String flag) {
      if (i + 1 >= args.length) _die('$flag needs a value');
      return args[i + 1];
    }

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--from':
          from = next(i, '--from');
          i++;
        case '--version':
          version = next(i, '--version');
          i++;
        case '--yes':
        case '-y':
          assumeYes = true;
        case '--dry-run':
          dryRun = true;
        case '--no-publish':
          publish = false;
        case '--no-github-release':
          githubRelease = false;
        case '--help':
        case '-h':
          _printUsage();
          exit(0);
        default:
          _die('unknown argument: ${args[i]}\nRun with --help for usage.');
      }
    }
    return _Flags(
      from: from,
      version: version,
      assumeYes: assumeYes,
      dryRun: dryRun,
      publish: publish,
      githubRelease: githubRelease,
    );
  }
}

void _printUsage() {
  stdout.writeln('''
Cross-post release — republish $_sdkName 1.1.0-beta.N as $_pkgName 1.0.0-beta.N.
Run after `dart tool/release.dart` has published the beta.

  dart tool/opentelemetry_release.dart [--from v1.1.0-beta.N]

  --from vX.Y.Z-beta.N    beta tag to cross-post (default: latest beta tag)
  --version X.Y.Z         the $_pkgName version (default: 1.0.0-beta.N)
  --dry-run               regenerate $_pkgDir/ and validate; no commit or tag
  --no-publish            local commit + tag only
  --no-github-release     skip the GitHub release
  --yes, -y               non-interactive confirm
  --help, -h              this message''');
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

/// Runs [exe] [args] in the package directory, or at the repo root when
/// [inPackage] is false. An exit code equal to [allowExit] is tolerated.
void _runOrThrow(
  String exe,
  List<String> args, {
  bool silent = false,
  bool inPackage = true,
  int? allowExit,
}) {
  final where = inPackage ? '$_pkgDir\$ ' : '\$ ';
  if (!silent) stdout.writeln('$where$exe ${args.join(' ')}');
  final r = Process.runSync(
    exe,
    args,
    workingDirectory: inPackage ? _pkgDir : null,
  );
  if (!silent) {
    stdout.write(r.stdout);
    stderr.write(r.stderr);
  }
  if (r.exitCode != 0 && r.exitCode != allowExit) {
    if (silent) {
      stdout.write(r.stdout);
      stderr.write(r.stderr);
    }
    throw StateError('$exe ${args.join(' ')} failed (exit ${r.exitCode})');
  }
}

/// Runs [exe] [args] in the package directory with inherited stdio, so
/// `dart pub publish`'s y/N prompt reaches the terminal.
Future<bool> _runInteractive(String exe, List<String> args) async {
  stdout.writeln('$_pkgDir\$ $exe ${args.join(' ')}');
  final p = await Process.start(
    exe,
    args,
    workingDirectory: _pkgDir,
    mode: ProcessStartMode.inheritStdio,
  );
  return await p.exitCode == 0;
}

Never _die(String msg) {
  stderr.writeln('error: $msg');
  exit(1);
}
