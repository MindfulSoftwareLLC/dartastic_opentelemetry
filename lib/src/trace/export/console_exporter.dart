// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/export/span_exporter.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

//Used for debugging, it prints exported spans
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
