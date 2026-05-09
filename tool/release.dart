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
///
/// After success, push and publish manually:
///     git push origin HEAD vX.Y.Z
///     dart pub publish
///
/// Usage:
///     dart tool/release.dart                       # auto-bump
///     dart tool/release.dart --next 1.2.0-beta     # override next
///     dart tool/release.dart --yes                 # non-interactive
///
/// Design notes:
/// - Reading is done via `package:pubspec_parse`, which produces a typed
///   `Pubspec` with a `pub_semver.Version`. That validates the file is
///   well-formed and the version is real semver before we touch anything.
/// - Writing is line-precise: we never round-trip the YAML through a
///   parser-printer, so comments and formatting in `pubspec.yaml` are
///   preserved bit-for-bit. Only the single `version:` line changes.
/// - The previous `tool/release.sh` used a perl substitution whose
///   `\s*$` greedily ate the trailing `\n` and joined the version line
///   with the next line. Doing this in Dart with a typed reader and
///   line-based writer makes that whole class of bug impossible.
library;

import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

const _wipSuffix = '-wip';
const _pubspecPath = 'pubspec.yaml';
const _changelogPath = 'CHANGELOG.md';

void main(List<String> args) {
  final flags = _Flags.parse(args);

  if (!_isWorkingTreeClean()) {
    _die('working tree is dirty. commit or stash first.');
  }

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
    ..writeln();

  if (!flags.assumeYes) {
    stdout.write('Continue? [y/N] ');
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
    _runOrThrow('dart', ['test']);
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

  stdout
    ..writeln()
    ..writeln('✓ done.')
    ..writeln()
    ..writeln('Next steps:')
    ..writeln('  git push origin HEAD v$release')
    ..writeln('  dart pub publish')
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
  _Flags({this.nextOverride, required this.assumeYes});

  final String? nextOverride;
  final bool assumeYes;

  static _Flags parse(List<String> args) {
    String? nextOverride;
    var assumeYes = false;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      switch (a) {
        case '--next':
          if (i + 1 >= args.length) _die('--next requires a value');
          nextOverride = args[++i];
        case '--yes':
        case '-y':
          assumeYes = true;
        case '-h':
        case '--help':
          _printUsage();
          exit(0);
        default:
          _die('unknown arg: $a');
      }
    }
    return _Flags(nextOverride: nextOverride, assumeYes: assumeYes);
  }
}

void _printUsage() {
  stdout.writeln('Usage: dart tool/release.dart [--next <version>] [--yes]');
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

Never _die(String msg) {
  stderr.writeln('error: $msg');
  exit(1);
}
