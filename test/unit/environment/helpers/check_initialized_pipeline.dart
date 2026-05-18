// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Helper script: calls OTel.initialize() with no parameters and prints a
// JSON snapshot of the resulting pipeline (span processors, metric readers,
// log record processors, and the exporter type each wraps). Used by
// subprocess tests to verify behavior under different env var combinations.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

String _exporterTag(Object? exporter) {
  if (exporter == null) return 'null';
  if (exporter is CompositeMetricExporter) {
    return 'CompositeMetricExporter(${exporter.exporters.map(_exporterTag).join(',')})';
  }
  if (exporter is CompositeExporter) {
    return 'CompositeExporter(${exporter.spanExporters.map(_exporterTag).join(',')})';
  }
  return exporter.runtimeType.toString();
}

String _spanProcessorTag(SpanProcessor processor) {
  if (processor is BatchSpanProcessor) {
    return 'BatchSpanProcessor(${_exporterTag(processor.exporter)})';
  }
  if (processor is SimpleSpanProcessor) {
    return 'SimpleSpanProcessor';
  }
  return processor.runtimeType.toString();
}

String _logProcessorTag(LogRecordProcessor processor) {
  if (processor is BatchLogRecordProcessor) {
    return 'BatchLogRecordProcessor(${_exporterTag(processor.exporter)})';
  }
  if (processor is SimpleLogRecordProcessor) {
    return 'SimpleLogRecordProcessor';
  }
  return processor.runtimeType.toString();
}

String _readerTag(MetricReader reader) {
  if (reader is PeriodicExportingMetricReader) {
    return 'PeriodicExportingMetricReader(${_exporterTag(reader.exporter)})';
  }
  return reader.runtimeType.toString();
}

Future<void> main() async {
  await OTel.initialize();

  final tracerProvider = OTel.tracerProvider();
  final meterProvider = OTel.meterProvider();
  final loggerProvider = OTel.loggerProvider();

  final snapshot = <String, dynamic>{
    'spanProcessors':
        tracerProvider.spanProcessors.map(_spanProcessorTag).toList(),
    'metricReaders': meterProvider.metricReaders.map(_readerTag).toList(),
    'logRecordProcessors':
        loggerProvider.logRecordProcessors.map(_logProcessorTag).toList(),
  };

  print(jsonEncode(snapshot));

  // Force-exit to avoid waiting on the periodic metric reader timer or any
  // background batch timers — we just want the pipeline snapshot.
  exit(0);
}
