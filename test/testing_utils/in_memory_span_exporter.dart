// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// A simple in-memory span exporter that captures spans for verification in tests.
/// This exporter is designed to be used in unit tests where you need to verify
/// that spans were created and exported correctly without relying on external
/// infrastructure like real collectors or file systems.
class InMemorySpanExporter implements SpanExporter {
  final List<Span> _spans = [];
  bool _isShutdown = false;

  /// Get all spans that have been exported to this exporter
  List<Span> get spans => List.unmodifiable(_spans);

  /// Clear all exported spans
  void clear() => _spans.clear();

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      throw StateError('Exporter is shutdown');
    }
    _spans.addAll(spans);
  }

  @override
  Future<void> forceFlush() async {
    // No buffering, nothing to flush
  }

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }

  /// Find a span by name
  Span? findSpanByName(String name) {
    return _spans.cast<Span?>().firstWhere(
          (span) => span?.name == name,
          orElse: () => null,
        );
  }

  /// Check if a span with the given name exists
  bool hasSpanWithName(String name) {
    return _spans.any((span) => span.name == name);
  }

  /// Get all span names (useful for debugging)
  List<String> get spanNames => _spans.map((span) => span.name).toList();
}
