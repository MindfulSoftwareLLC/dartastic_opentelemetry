// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Regression tests for issue #33 — `OTel.shutdown()` hangs in short-lived
/// Dart CLI binaries.
///
/// Original symptom report:
///   1. `await OTel.initialize(serviceName: ...)`
///   2. Start a span, end it
///   3. `await OTel.tracerProvider().forceFlush()`
///   4. `await OTel.shutdown()` — issue says "never returns"
///   5. process never exits, only `kill -9` works
///
/// Actual diagnosis (after running the repro): the `await OTel.shutdown()`
/// call DOES return and any post-shutdown `print` runs. What hangs is
/// process exit. Something keeps the Dart isolate alive after `main()`
/// returns — the `Dart_RunLoop` parking the issue mentions.
///
/// Most likely cause class: a leaked `Timer.periodic` that was created
/// during `OTel.initialize` but isn't cancelled during `OTel.shutdown`.
/// Candidates: `BatchSpanProcessor._timer`, `BatchLogRecordProcessor._timer`,
/// `PeriodicExportingMetricReader._timer`, `RateLimitingSampler._tokenReplenishTimer`,
/// any uncancelled `StreamSubscription`, or an open socket from a
/// gRPC channel that wasn't fully terminated.
///
/// Why the existing in-process tests don't catch this: `dart test` runs
/// each test in an isolate the framework tears down after the test
/// completes, so leaked Timers don't keep the test runner alive. To
/// catch the real-world bug we have to spawn a separate process and
/// assert it exits.
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

/// Returns a localhost port that was free at call time.
Future<int> _findFreePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// Spawns a transient Dart CLI that runs [reproSource], then waits up
/// to [exitDeadline] for the child process to exit on its own. Returns
/// the elapsed time to natural exit, or fails if the deadline elapses
/// (process is killed).
///
/// Standalone-process testing is the only way to catch "isolate stays
/// alive after main() returns" bugs — a leaked Timer.periodic does not
/// fail an in-process test because `dart test` tears down the isolate
/// for you.
Future<Duration> _runUntilExit({
  required String reproSource,
  required Duration exitDeadline,
}) async {
  final tmpDir = await Directory.systemTemp.createTemp('otel_shutdown_repro_');
  try {
    final pubspec = File('${tmpDir.path}/pubspec.yaml');
    final repoRoot = Directory.current.absolute.path;
    // `dependency_overrides` from the SDK's own pubspec are ignored when
    // the SDK is a transitive dep (pub only honors overrides from the
    // root package). Replicate the SDK's local API override here so the
    // subprocess can resolve the in-flight API beta against its local
    // path even when its published `^x.y.z-beta.N` constraint hasn't
    // landed yet.
    final apiPath = Directory('$repoRoot/../dartastic_opentelemetry_api')
        .absolute
        .path;
    pubspec.writeAsStringSync('''
name: shutdown_repro
publish_to: none
environment:
  sdk: ^3.0.0
dependencies:
  dartastic_opentelemetry:
    path: $repoRoot
dependency_overrides:
  dartastic_opentelemetry_api:
    path: $apiPath
''');
    final src = File('${tmpDir.path}/main.dart');
    src.writeAsStringSync(reproSource);

    final pubGet = await Process.run(
      'dart',
      ['pub', 'get', '--offline'],
      workingDirectory: tmpDir.path,
    );
    if (pubGet.exitCode != 0) {
      // Fall back to non-offline pub get if the pub cache doesn't have
      // everything yet.
      final pubGet2 = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: tmpDir.path,
      );
      if (pubGet2.exitCode != 0) {
        fail('pub get failed:\n${pubGet2.stdout}\n${pubGet2.stderr}');
      }
    }

    final stopwatch = Stopwatch()..start();
    final p = await Process.start(
      'dart',
      ['run', 'main.dart'],
      workingDirectory: tmpDir.path,
    );

    // Drain stdout/stderr so the pipes don't fill up.
    final stdoutFuture = p.stdout.drain<void>();
    final stderrFuture = p.stderr.drain<void>();

    final exitFuture = p.exitCode;
    final naturalExit = await Future.any<int?>([
      exitFuture.then<int?>((c) => c),
      Future<int?>.delayed(exitDeadline, () => null),
    ]);

    if (naturalExit == null) {
      // Deadline hit before process exited — kill and fail.
      p.kill(ProcessSignal.sigkill);
      await Future.wait([stdoutFuture, stderrFuture, exitFuture]);
      fail(
        'CLI did not exit within ${exitDeadline.inSeconds}s after '
        'OTel.shutdown() returned — issue #33 reproduces (something is '
        'keeping the isolate alive after main returns).',
      );
    }
    stopwatch.stop();
    await Future.wait([stdoutFuture, stderrFuture]);
    expect(naturalExit, equals(0));
    return stopwatch.elapsed;
  } finally {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  }
}

void main() {
  group('OTel.shutdown() does not hang the process (issue #33)', () {
    test(
      'CLI binary exits within 30s after OTel.initialize → span → '
      'forceFlush → shutdown (the user\'s repro)',
      () async {
        final port = await _findFreePort();
        final elapsed = await _runUntilExit(
          exitDeadline: const Duration(seconds: 30),
          reproSource: '''
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  await OTel.initialize(
    serviceName: 'shutdown-hang-repro',
    serviceVersion: '0.0.0',
    endpoint: 'http://127.0.0.1:$port',
  );
  final tracer = OTel.tracerProvider().getTracer('repro');
  final span = tracer.startSpan('one', kind: SpanKind.internal);
  span.end();
  await OTel.tracerProvider().forceFlush();
  await OTel.shutdown();
}
''',
        );
        // It should exit in seconds, not on the deadline.
        expect(
          elapsed,
          lessThan(const Duration(seconds: 25)),
          reason: 'process exit should be near-instant after shutdown returns',
        );
      },
      // Process spin-up + pub get + exit grace = generous test cap.
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'CLI binary exits cleanly with logs/metrics enabled (default)',
      () async {
        final port = await _findFreePort();
        final elapsed = await _runUntilExit(
          exitDeadline: const Duration(seconds: 30),
          reproSource: '''
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  await OTel.initialize(
    serviceName: 'shutdown-hang-with-defaults',
    serviceVersion: '0.0.0',
    endpoint: 'http://127.0.0.1:$port',
    // enableMetrics + enableLogs default to true in OTel.initialize.
  );
  final tracer = OTel.tracerProvider().getTracer('repro');
  final span = tracer.startSpan('one', kind: SpanKind.internal);
  span.end();

  final logger = OTel.logger();
  logger.emit(body: 'hello');

  await OTel.tracerProvider().forceFlush();
  await OTel.shutdown();
}
''',
        );
        expect(elapsed, lessThan(const Duration(seconds: 25)));
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });
}
