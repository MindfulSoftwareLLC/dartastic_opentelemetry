// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Release script — Flutter / Dart team `-wip` pattern.
///
/// Reads `pubspec.yaml` (whose version MUST end in `-wip`), then:
///   1. Strips `-wip` from `pubspec.yaml`.
///   2. Rewrites `## [X.Y.Z-wip]` in `CHANGELOG.md` to
///      `## [X.Y.Z] - YYYY-MM-DD`.
///   3. Runs `dart pub get`, `dart analyze`, `dart test`.
///   4. Commits as `Release X.Y.Z` and tags `vX.Y.Z`.
///   5. Bumps `pubspec.yaml` to next `-wip` (rightmost numeric component
///      + 1 by default; `--next X.Y.Z` to override).
///   6. Inserts a fresh `## [next-wip]` CHANGELOG section.
///   7. Commits as `Bump to <next-wip>`.
///   8. Checks out the `vX.Y.Z` tag (so the working tree shows the
///      released version, not the wip bump) and runs `dart pub publish`.
///      pub.dev's own confirmation prompt is the publish gate.
///   9. Returns the working tree to the original branch.
///
/// After success, push:
///     git push origin BRANCH vX.Y.Z
///
/// Usage:
///     dart tool/release.dart                       # auto-bump + publish
///     dart tool/release.dart --next 1.2.0-beta     # override next dev
///     dart tool/release.dart --no-publish          # cut release locally only
///     dart tool/release.dart --skip-tests          # skip `dart test`
///     dart tool/release.dart --yes                 # non-interactive confirm
///
/// Design notes:
/// - Reading is done via `package:pubspec_parse`, which produces a typed
///   `Pubspec` with a `pub_semver.Version`. That validates the file is
///   well-formed and the version is real semver before we touch anything.
/// - Writing is line-precise: we never round-trip the YAML through a
///   parser-printer, so comments and formatting in `pubspec.yaml` are
///   preserved bit-for-bit. Only the single `version:` line changes.
/// - Auto-publishing avoids a known footgun: `dart pub publish` reads
///   the working tree, so if you ran the release script and then ran
///   `dart pub publish` manually from HEAD, you would end up offering
///   the `-wip` bump version to pub.dev. Step 8 checks out the release
///   tag first so the working tree reflects the version being published.
/// - The previous `tool/release.sh` used a perl substitution whose
///   `\s*$` greedily ate the trailing `\n` and joined the version line
///   with the next line. Doing this in Dart with a typed reader and
///   line-based writer makes that whole class of bug impossible.
library;

import 'dart:async';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

const _wipSuffix = '-wip';
const _pubspecPath = 'pubspec.yaml';
const _changelogPath = 'CHANGELOG.md';

Future<void> main(List<String> args) async {
  final flags = _Flags.parse(args);

  if (!_isWorkingTreeClean()) {
    _die('working tree is dirty. commit or stash first.');
  }

  final originalRef = _currentRef();
  final current = _readWipVersion();
  final release = _stripWip(current);
  final nextWip = _computeNextWip(release, override: flags.nextOverride);

  if (!_changelogHasWipSection(current)) {
    _die('CHANGELOG.md has no section header for $current\n'
        '       expected "## [$current]" or "## $current".');
  }

  stdout
    ..writeln()
    ..writeln('  Releasing: $release   (was: $current)')
    ..writeln('  Next dev:  $nextWip')
    ..writeln(
      '  Publish:   ${flags.publish ? "yes — pub.dev will prompt before uploading" : "no — local commits + tag only"}',
    )
    ..writeln();

  if (!flags.assumeYes) {
    stdout.write('Continue with the local release steps? [y/N] ');
    final reply = stdin.readLineSync()?.trim();
    if (reply != 'y' && reply != 'Y') {
      stdout.writeln('aborted.');
      exit(1);
    }
  }

  try {
    // ---- release commit ----
    _replaceVersionLine(from: current, to: release);
    _replaceChangelogSection(
      from: current,
      newHeader: '## [$release] - ${_today()}',
    );
    _runOrThrow('dart', ['pub', 'get'], silent: true);
    _runOrThrow('dart', ['analyze']);
    if (flags.skipTests) {
      stdout.writeln('(skipping tests — --skip-tests)');
    } else if (File('tool/test.sh').existsSync() &&
        (Platform.isMacOS || Platform.isLinux)) {
      // Repos that ship a `tool/test.sh` wrapper (e.g. the SDK, which
      // needs an OTLP collector running for integration tests) own
      // collector setup inside the script. Plain `dart test` would
      // hang on those tests.
      _runOrThrow('bash', ['tool/test.sh']);
    } else {
      _runOrThrow('dart', ['test']);
    }
    _runOrThrow('git', ['add', _pubspecPath, _changelogPath]);
    _runOrThrow('git', ['commit', '-m', 'Release $release']);
    _runOrThrow('git', ['tag', 'v$release']);
    stdout.writeln('✓ tagged v$release');

    // ---- next-wip commit ----
    _replaceVersionLine(from: release, to: nextWip);
    _injectChangelogSectionAbove(existingHeader: release, newSection: nextWip);
    _runOrThrow('git', ['add', _pubspecPath, _changelogPath]);
    _runOrThrow('git', ['commit', '-m', 'Bump to $nextWip']);
  } catch (e) {
    stderr
      ..writeln()
      ..writeln('error: failed mid-release: $e')
      ..writeln('To recover:')
      ..writeln('  git checkout $_pubspecPath $_changelogPath')
      ..writeln('  git tag -d v$release 2>/dev/null || true')
      ..writeln();
    exit(1);
  }

  // ---- publish ----
  if (flags.publish) {
    stdout
      ..writeln()
      ..writeln('Local release steps complete. About to invoke '
          '`dart pub publish` —')
      ..writeln('pub.dev will print the file list and prompt for a '
          'final y/N before uploading.')
      ..writeln('Checking out v$release first '
          '(pub publish reads the working tree, not the tag)...');
    _runOrThrow('git', ['checkout', 'v$release']);
    var publishOk = false;
    try {
      publishOk = await _runInteractive('dart', ['pub', 'publish']);
    } finally {
      stdout.writeln('Returning working tree to $originalRef...');
      _runOrThrow('git', ['checkout', originalRef]);
    }
    if (!publishOk) {
      stderr
        ..writeln()
        ..writeln('error: `dart pub publish` did not succeed.')
        ..writeln('The local commits and the v$release tag are still in '
            'place — you can re-publish with:')
        ..writeln('  git checkout v$release && dart pub publish && '
            'git checkout $originalRef')
        ..writeln();
      exit(1);
    }
  }

  stdout
    ..writeln()
    ..writeln('✓ done.')
    ..writeln()
    ..writeln('Next steps:')
    ..writeln('  git push origin $originalRef v$release');
  if (!flags.publish) {
    stdout
      ..writeln('  git checkout v$release')
      ..writeln('  dart pub publish')
      ..writeln('  git checkout $originalRef');
  }
  stdout
    ..writeln()
    ..writeln('To roll back the local commits and tag (before push):')
    ..writeln('  git tag -d v$release')
    ..writeln('  git reset --hard HEAD~2')
    ..writeln();
}

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------

class _Flags {
  _Flags({
    this.nextOverride,
    required this.assumeYes,
    required this.publish,
    required this.skipTests,
  });

  final String? nextOverride;
  final bool assumeYes;
  final bool publish;
  final bool skipTests;

  static _Flags parse(List<String> args) {
    String? nextOverride;
    var assumeYes = false;
    var publish = true;
    var skipTests = false;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      switch (a) {
        case '--next':
          if (i + 1 >= args.length) _die('--next requires a value');
          nextOverride = args[++i];
        case '--yes':
        case '-y':
          assumeYes = true;
        case '--no-publish':
          publish = false;
        case '--skip-tests':
          skipTests = true;
        case '-h':
        case '--help':
          _printUsage();
          exit(0);
        default:
          _die('unknown arg: $a');
      }
    }
    return _Flags(
      nextOverride: nextOverride,
      assumeYes: assumeYes,
      publish: publish,
      skipTests: skipTests,
    );
  }
}

void _printUsage() {
  stdout.writeln('Usage: dart tool/release.dart '
      '[--next <version>] [--yes] [--no-publish] [--skip-tests]');
  stdout.writeln();
  stdout.writeln('See the file header for full docs.');
}

// ---------------------------------------------------------------------------
// Pubspec read / write
// ---------------------------------------------------------------------------

/// Reads pubspec.yaml via `pubspec_parse`, validates the version exists
/// and is semver, asserts it ends in `-wip`, returns the version string.
String _readWipVersion() {
  final text = File(_pubspecPath).readAsStringSync();
  final Pubspec pubspec;
  try {
    pubspec = Pubspec.parse(text);
  } catch (e) {
    _die('pubspec.yaml is malformed: $e');
  }
  final version = pubspec.version;
  if (version == null) {
    _die('pubspec.yaml has no version field.');
  }
  final str = version.toString();
  if (!str.endsWith(_wipSuffix)) {
    _die('pubspec.yaml version is "$str" — expected to end in $_wipSuffix.\n'
        '       did you already release? bump to the next $_wipSuffix version.');
  }
  return str;
}

/// Strips the `-wip` suffix from [version] and validates the result is
/// still real semver via `pub_semver.Version.parse`.
String _stripWip(String version) {
  final stripped = version.substring(0, version.length - _wipSuffix.length);
  try {
    Version.parse(stripped);
  } on FormatException catch (e) {
    _die('release version "$stripped" (from "$version") is not valid '
        'semver: ${e.message}');
  }
  return stripped;
}

/// Bumps the rightmost numeric component of [release] and reattaches
/// `-wip`. If [override] is non-null, uses that as the next version
/// (with `-wip` appended if the caller didn't include it).
String _computeNextWip(String release, {String? override}) {
  if (override != null) {
    final s = override.endsWith(_wipSuffix) ? override : '$override$_wipSuffix';
    final stripped = s.substring(0, s.length - _wipSuffix.length);
    try {
      Version.parse(stripped);
    } on FormatException catch (e) {
      _die('--next "$override" is not valid semver: ${e.message}');
    }
    return s;
  }
  final m = RegExp(r'^(.*?)(\d+)$').firstMatch(release);
  if (m == null) {
    _die('cannot auto-bump "$release" (no trailing number).\n'
        '       use --next <version> to specify it explicitly.');
  }
  final prefix = m.group(1)!;
  final num = int.parse(m.group(2)!);
  return '$prefix${num + 1}$_wipSuffix';
}

/// Rewrites the single `version:` line in pubspec.yaml. Preserves
/// every other byte of the file (comments, blank lines, ordering).
void _replaceVersionLine({required String from, required String to}) {
  final f = File(_pubspecPath);
  final lines = f.readAsLinesSync();
  var replaced = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('version:')) continue;
    final after = line.substring('version:'.length).trim();
    if (after != from) continue;
    lines[i] = 'version: $to';
    replaced = true;
    break;
  }
  if (!replaced) {
    throw StateError('did not find "version: $from" line in $_pubspecPath');
  }
  // readAsLinesSync drops line terminators; rejoin with \n and add a
  // trailing newline so we don't end the file abruptly.
  f.writeAsStringSync('${lines.join('\n')}\n');
}

// ---------------------------------------------------------------------------
// CHANGELOG read / write
// ---------------------------------------------------------------------------

bool _changelogHasWipSection(String wipVersion) {
  final text = File(_changelogPath).readAsStringSync();
  return _changelogHeaderRegex(wipVersion).hasMatch(text);
}

/// Replaces the existing wip-version section header line (the whole
/// line — `##` prefix and any trailing date marker) with [newHeader].
/// The caller supplies the exact replacement text starting with `## `.
void _replaceChangelogSection({
  required String from,
  required String newHeader,
}) {
  final f = File(_changelogPath);
  final text = f.readAsStringSync();
  final re = RegExp(
    r'^##[ \t]*\[?' + RegExp.escape(from) + r'\]?[^\n]*$',
    multiLine: true,
  );
  final replaced = text.replaceFirst(re, newHeader);
  if (replaced == text) {
    throw StateError('did not rewrite CHANGELOG section header for $from');
  }
  f.writeAsStringSync(replaced);
}

/// Inserts a new `## [<newSection>]` block immediately above the
/// `## [<existingHeader>]` line. Used to seed the next development
/// cycle.
void _injectChangelogSectionAbove({
  required String existingHeader,
  required String newSection,
}) {
  final f = File(_changelogPath);
  final text = f.readAsStringSync();
  final re = _changelogHeaderRegex(existingHeader);
  final m = re.firstMatch(text);
  if (m == null) {
    throw StateError(
      'did not find "## [$existingHeader]" in CHANGELOG to inject above',
    );
  }
  final injected = '${text.substring(0, m.start)}'
      '## [$newSection]\n\n'
      '${text.substring(m.start)}';
  f.writeAsStringSync(injected);
}

RegExp _changelogHeaderRegex(String version) => RegExp(
      r'^##[ \t]*\[?' + RegExp.escape(version) + r'\]?',
      multiLine: true,
    );

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

bool _isWorkingTreeClean() {
  final r = Process.runSync('git', ['status', '--porcelain']);
  if (r.exitCode != 0) {
    _die('git status failed:\n${r.stderr}');
  }
  return (r.stdout as String).trim().isEmpty;
}

/// Returns the current symbolic ref (branch name) or, if HEAD is
/// detached, the abbreviated commit SHA. Used as the "return to"
/// target after the publish step.
String _currentRef() {
  final symbolic = Process.runSync('git', ['symbolic-ref', '--quiet', 'HEAD']);
  if (symbolic.exitCode == 0) {
    final ref = (symbolic.stdout as String).trim();
    if (ref.startsWith('refs/heads/')) {
      return ref.substring('refs/heads/'.length);
    }
    return ref;
  }
  // Detached HEAD — fall back to the commit SHA.
  final sha = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (sha.exitCode != 0) {
    _die('cannot resolve HEAD');
  }
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
    throw StateError(
      '$exe ${args.join(' ')} failed (exit ${r.exitCode})',
    );
  }
}

/// Runs [exe] [args] with stdio inherited from this process so the
/// child's prompts (e.g. `dart pub publish`'s y/N confirmation) and
/// streaming output reach the user's terminal directly. Returns true
/// on exit code 0.
Future<bool> _runInteractive(String exe, List<String> args) async {
  stdout.writeln('\$ $exe ${args.join(' ')}');
  final p = await Process.start(
    exe,
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await p.exitCode;
  return code == 0;
}

Never _die(String msg) {
  stderr.writeln('error: $msg');
  exit(1);
}
