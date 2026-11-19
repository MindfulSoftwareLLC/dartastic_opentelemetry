// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'helpers/subprocess_env.dart';

void main() {
  test('Prometheus listener settings read process environment', () async {
    final output = await runWithEnv('tool/read_otel_config.dart', {
      'OTEL_EXPORTER_PROMETHEUS_HOST': '127.0.0.2',
      'OTEL_EXPORTER_PROMETHEUS_PORT': '9465',
    }, args: [
      'prometheus'
    ]);
    expect(jsonDecode(output), {'host': '127.0.0.2', 'port': 9465});
  });

  test('Dart defines override process environment for both settings', () async {
    final env = Map<String, String>.from(Platform.environment)
      ..removeWhere((key, _) => key.startsWith('OTEL_'))
      ..addAll({
        'OTEL_EXPORTER_PROMETHEUS_HOST': '127.0.0.2',
        'OTEL_EXPORTER_PROMETHEUS_PORT': '9465'
      });
    final result = await Process.run(
        Platform.resolvedExecutable,
        [
          '-DOTEL_EXPORTER_PROMETHEUS_HOST=127.0.0.3',
          '-DOTEL_EXPORTER_PROMETHEUS_PORT=9466',
          'tool/read_otel_config.dart',
          'prometheus',
        ],
        workingDirectory: await packageRoot(),
        environment: env,
        includeParentEnvironment: false);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(jsonDecode(result.stdout as String),
        {'host': '127.0.0.3', 'port': 9466});
  });
}
