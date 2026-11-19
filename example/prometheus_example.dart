// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Run with OTEL_METRICS_EXPORTER=prometheus, then scrape localhost:9464/metrics.
/// Optional OTEL_EXPORTER_PROMETHEUS_HOST/PORT settings control the listener.
Future<void> main() async {
  await OTel.initialize(serviceName: 'prometheus-example');
  final readers =
      OTel.meterProvider().metricReaders.whereType<PrometheusMetricReader>();
  if (readers.isEmpty || !await readers.single.ready) {
    stderr.writeln('Select OTEL_METRICS_EXPORTER=prometheus and a free port.');
    await OTel.shutdown();
    return;
  }
  final reader = readers.single;
  print('Scrape http://${reader.host}:${reader.boundPort}/metrics');
  final counter = OTel.meter().createCounter<int>(name: 'example_ticks');
  final timer =
      Timer.periodic(const Duration(seconds: 1), (_) => counter.add(1));
  await ProcessSignal.sigint.watch().first;
  timer.cancel();
  await OTel.shutdown();
}
