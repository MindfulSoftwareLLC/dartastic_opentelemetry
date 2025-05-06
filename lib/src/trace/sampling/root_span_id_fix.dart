// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Utility class to help with root span ID issues
class RootSpanIdFix {
  /// Ensure a span context has a proper parent span ID - all zeros for root spans
  static SpanContext ensureParentSpanId(SpanContext spanContext) {
    // If there's no parent span ID, add an invalid one (all zeros)
    if (spanContext.parentSpanId == null) {
      return spanContext.withParentSpanId(SpanId.invalidSpanId);
    }
    return spanContext;
  }
}

/// Extensions to SpanContext
extension SpanContextExtension on SpanContext {
  /// Create a new SpanContext with the given parent span ID
  SpanContext withParentSpanId(SpanId parentId) {
    return OTelAPI.spanContext(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentId,
      traceFlags: traceFlags,
      traceState: traceState,
      isRemote: isRemote,
    );
  }
}
