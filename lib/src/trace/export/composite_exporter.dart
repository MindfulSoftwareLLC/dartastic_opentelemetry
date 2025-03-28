// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/export/span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

//Used for debugging, it prints exported spans
class CompositeExporter extends SpanExporter {
  final List<SpanExporter> spanExporters;
  CompositeExporter(this.spanExporters);

  @override
  Future<void> export(List<Span> spans) async {
    for (var exporter in spanExporters) {
      exporter.export(spans);
    }
  }

  @override
  Future<void> forceFlush() async {
    for (var exporter in spanExporters) {
      exporter.forceFlush();
    }
  }

  @override
  Future<void> shutdown() async {
    for (var exporter in spanExporters) {
      exporter.shutdown();
    }
  }
}
