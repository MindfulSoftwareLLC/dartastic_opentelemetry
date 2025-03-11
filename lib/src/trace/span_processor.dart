// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:opentelemetry_api/opentelemetry_api.dart';
import 'package:dartastic_opentelemetry/src/trace/span.dart';

/// Interface for span processors that handle span lifecycle events
abstract class SpanProcessor {
  /// Called when a span is started
  Future<void> onStart(Span span,Context? parentContext);

  /// Called when a span is ended
  Future<void> onEnd(Span span);

  /// Called when a span's name is updated
  Future<void> onNameUpdate(Span span, String newName);

  /// Shuts down the span processor
  Future<void> shutdown();

  /// Forces the span processor to flush any queued spans
  Future<void> forceFlush();
}
