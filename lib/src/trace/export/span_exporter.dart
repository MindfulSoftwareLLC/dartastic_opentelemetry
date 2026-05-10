// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../span.dart';

/// A SpanExporter exports finished [Span]s.
abstract class SpanExporter {
  /// Exports a batch of finished [Span]s.
  Future<void> export(List<Span> spans);

  /// Flushes any pending data.
  Future<void> forceFlush();

  /// Shuts down the exporter.
  Future<void> shutdown();
}
