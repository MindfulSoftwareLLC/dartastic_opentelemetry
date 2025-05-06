// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import '../../dartastic_opentelemetry.dart' show Span, OTelLog;

/// Logs a single span with an optional message.
///
/// This utility function logs span information for debugging purposes.
/// It includes a timestamp and formats the span information in a consistent way.
///
/// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
/// span events are being deprecated and will be replaced by the Logging API in future versions.
///
/// @param span The span to log
/// @param message Optional message to include with the span log
void logSpan(Span span, [String? message]) {
  if (OTelLog.logFunction == null) {
    return;
  } else {
    final timestamp = DateTime.now().toIso8601String();
    final String msg = message ?? '';
    OTelLog.logFunction!('[$timestamp] [message] $msg [span] $span');
  }
}

/// Logs multiple spans with an optional message.
///
/// This utility function logs information about multiple spans for debugging purposes.
/// It includes a timestamp and formats the spans information in a consistent way.
///
/// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
/// span events are being deprecated and will be replaced by the Logging API in future versions.
///
/// @param spans The list of spans to log
/// @param message Optional message to include with the spans log
void logSpans(List<Span> spans, [String? message]) {
  if (OTelLog.isLogSpans()) {
    final timestamp = DateTime.now().toIso8601String();
    final String msg = message ?? '';
    OTelLog.spanLogFunction!('[$timestamp] [message] $msg [spans] $spans');
  }
}
