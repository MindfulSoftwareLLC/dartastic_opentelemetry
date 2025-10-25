// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry/src/trace/span_processor.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Automatically copies baggage entries to span attributes on span start.
///
/// https://opentelemetry.io/docs/specs/otel/baggage/api/#baggage-propagation
/// "Because a common use case for Baggage is to add data to Span Attributes
/// across a whole trace, several languages have Baggage Span Processors that
/// add data from baggage as attributes on span creation."
///
/// This BaggageSpanProcessor extracts all baggage entries from the parent or
/// current context and adds them as span attributes when spans are created.
///
/// This enables baggage values to be:
/// - Visible in tracing backends (HyperDX, Jaeger, etc.)
/// - Searchable and filterable for trace queries
/// - Automatically propagated to all spans without manual attribute setting
///
/// Example usage:
///
/// ```dart
/// final tracerProvider = OTel.tracerProvider();
/// tracerProvider.addSpanProcessor(BaggageSpanProcessor());
/// ```
class BaggageSpanProcessor implements SpanProcessor {
  /// Creates a [BaggageSpanProcessor] instance.
  const BaggageSpanProcessor();

  @override
  Future<void> onStart(Span span, Context? parentContext) async {
    // Extract baggage from the current context
    final baggage = (parentContext ?? Context.current).baggage;
    if (baggage == null) {
      return;
    }

    final entries = baggage.getAllEntries();
    if (entries.isEmpty) {
      return;
    }

    // Convert baggage entries to a map for span attributes
    // Note: Baggage metadata is intentionally not included as it's not part of the value
    final attributeMap = <String, String>{};
    for (final entry in entries.entries) {
      attributeMap[entry.key] = entry.value.value;
    }

    // Add all baggage attributes to the span at once
    if (attributeMap.isNotEmpty) {
      span.addAttributes(Attributes.of(attributeMap));
    }
  }

  @override
  Future<void> onEnd(Span span) async {
    // No-op: baggage attributes are already added during onStart
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {
    // No-op: baggage values don't change when span name is updated
  }

  @override
  Future<void> shutdown() async {
    // No-op: this processor has no resources to clean up
  }

  @override
  Future<void> forceFlush() async {
    // No-op: this processor doesn't batch or queue spans
  }
}
