// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/trace/span.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Interface for span processors that handle span lifecycle events.
///
/// Span processors are invoked at key moments in a span's lifecycle, such as
/// when it is started, ended, or when its name is updated. They are responsible
/// for performing additional processing on spans, such as filtering, batching,
/// or exporting them.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/#span-processor
abstract class SpanProcessor {
  /// Called when a span is started.
  ///
  /// This method is called synchronously when a span is started, allowing
  /// for immediate processing of the span. Implementations should be lightweight
  /// and avoid blocking operations or excessive processing.
  ///
  /// @param span The span that was started
  /// @param parentContext The parent context, if any
  Future<void> onStart(Span span, Context? parentContext);

  /// Called when a span is ended.
  ///
  /// This method is called synchronously when a span is ended, allowing
  /// for processing of the completed span. This is typically where spans
  /// are exported or otherwise processed for storage or analysis.
  ///
  /// @param span The span that was ended
  Future<void> onEnd(Span span);

  /// Called when a span's name is updated.
  ///
  /// This method is called synchronously when a span's name is updated,
  /// allowing for processing of the updated span metadata.
  ///
  /// @param span The span whose name was updated
  /// @param newName The new name of the span
  Future<void> onNameUpdate(Span span, String newName);

  /// Shuts down the span processor.
  ///
  /// This method is called when the tracer provider is shut down.
  /// Implementations should release any resources they hold and perform
  /// any final processing of spans.
  Future<void> shutdown();

  /// Forces the span processor to flush any queued spans.
  ///
  /// This method is called when the tracer provider's forceFlush method
  /// is called. Implementations should ensure that any spans that have
  /// been processed but not yet exported are exported immediately.
  Future<void> forceFlush();
}
