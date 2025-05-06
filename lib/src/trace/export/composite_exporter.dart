// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/export/span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

/// A composite exporter that delegates export operations to multiple exporters.
/// 
/// This exporter combines multiple exporters, making it possible to export spans
/// to multiple backend systems simultaneously.
/// Used for debugging, it prints exported spans
class CompositeExporter extends SpanExporter {
  /// The list of exporters to delegate to.
  final List<SpanExporter> spanExporters;
  /// Creates a new CompositeExporter with the specified exporters.
  /// 
  /// @param spanExporters The list of exporters to delegate to
  CompositeExporter(this.spanExporters);

  @override
  Future<void> export(List<Span> spans) async {
    for (var exporter in spanExporters) {
      await exporter.export(spans);
    }
  }

  @override
  Future<void> forceFlush() async {
    for (var exporter in spanExporters) {
      await exporter.forceFlush();
    }
  }

  @override
  Future<void> shutdown() async {
    for (var exporter in spanExporters) {
      await exporter.shutdown();
    }
  }
}
