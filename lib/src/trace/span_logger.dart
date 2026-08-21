// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import '../../dartastic_opentelemetry.dart' show OTelLog, Span;

/// Logs a single span with an optional message.
///
/// This utility function logs span information for debugging purposes.
/// It includes a timestamp and formats the span information in a consistent way.
///
/// @param span The span to log
/// @param message Optional message to include with the span log
void logSpan(Span span, [String? message]) {
  if (OTelLog.logFunction != null) {
    final timestamp = DateTime.now().toIso8601String();
    final msg = message ?? '';
    OTelLog.logFunction!('[$timestamp] [message] $msg [span] $span');
  }
}

/// Logs multiple spans with an optional message.
///
/// This utility function logs information about multiple spans for debugging purposes.
/// It includes a timestamp and formats the spans information in a consistent way.
///
/// @param spans The list of spans to log
/// @param message Optional message to include with the spans log
void logSpans(List<Span> spans, [String? message]) {
  if (OTelLog.isLogSpans()) {
    final timestamp = DateTime.now().toIso8601String();
    final msg = message ?? '';
    OTelLog.spanLogFunction!('[$timestamp] [message] $msg [spans] $spans');
  }
}
