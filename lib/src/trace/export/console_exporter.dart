// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/export/span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

/// A simple span exporter that prints spans to the console.
/// 
/// This exporter is primarily used for debugging and testing, as it simply
/// prints the spans to the standard output rather than sending them to a
/// telemetry backend.
class ConsoleExporter extends SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {
    print(spans);
  }

  @override
  Future<void> forceFlush() async {
  }

  @override
  Future<void> shutdown() async {
  }
}
