// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => EnvironmentService.testOverrides = null);

  test('unset and empty settings are absent', () {
    for (final vars in [
      <String, String>{},
      {
        'OTEL_EXPORTER_PROMETHEUS_HOST': '',
        'OTEL_EXPORTER_PROMETHEUS_PORT': '',
      }
    ]) {
      EnvironmentService.testOverrides = vars;
      expect(OTelEnv.getPrometheusConfig(), (host: null, port: null));
    }
  });

  test('host and legal port boundaries use shared environment parsing', () {
    for (final port in [0, 1, 9464, 65535]) {
      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_PROMETHEUS_HOST': '0.0.0.0',
        'OTEL_EXPORTER_PROMETHEUS_PORT': '$port',
      };
      expect(OTelEnv.getPrometheusConfig(), (host: '0.0.0.0', port: port));
    }
  });

  test('invalid ports are ignored', () {
    for (final port in [
      '-1',
      '65536',
      '1.5',
      'abc',
      '999999999999999999999999'
    ]) {
      EnvironmentService.testOverrides = {
        'OTEL_EXPORTER_PROMETHEUS_PORT': port
      };
      expect(OTelEnv.getPrometheusConfig().port, isNull, reason: port);
    }
  });

  test('whitespace-only host cannot abort SDK initialization', () {
    EnvironmentService.testOverrides = {'OTEL_EXPORTER_PROMETHEUS_HOST': '   '};
    expect(OTelEnv.getPrometheusConfig().host, isNull);
  });
}
