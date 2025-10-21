// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Implementation of the W3C Trace Context specification for context propagation.
///
/// This propagator handles the extraction and injection of trace context information
/// following the W3C Trace Context specification as defined at:
/// https://www.w3.org/TR/trace-context/
///
/// The traceparent header contains:
/// - version (2 hex digits)
/// - trace-id (32 hex digits)
/// - parent-id/span-id (16 hex digits)
/// - trace-flags (2 hex digits)
///
/// Example: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
///
/// The tracestate header is optional and contains vendor-specific trace information
/// as a comma-separated list of key=value pairs.
class W3CTraceContextPropagator
    implements TextMapPropagator<Map<String, String>, String> {
  /// The standard header name for W3C trace parent
  static const _traceparentHeader = 'traceparent';

  /// The standard header name for W3C trace state
  static const _tracestateHeader = 'tracestate';

  /// The current version of the W3C Trace Context specification
  static const _version = '00';

  /// The length of a valid traceparent header value
  static const _traceparentLength = 55; // 00-{32}-{16}-{2}

  @override
  Context extract(Context context, Map<String, String> carrier,
      TextMapGetter<String> getter) {
    final traceparent = getter.get(_traceparentHeader);

    if (OTelLog.isDebug()) {
      OTelLog.debug('Extracting traceparent: $traceparent');
    }

    if (traceparent == null || traceparent.isEmpty) {
      return context;
    }

    // Parse the traceparent header
    final spanContext = _parseTraceparent(traceparent);
    if (spanContext == null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Invalid traceparent format, skipping extraction');
      }
      return context;
    }

    // Extract tracestate if present
    final tracestate = getter.get(_tracestateHeader);
    SpanContext finalSpanContext = spanContext;

    if (tracestate != null && tracestate.isNotEmpty) {
      final tracestateMap = _parseTracestate(tracestate);
      if (tracestateMap.isNotEmpty) {
        finalSpanContext =
            spanContext.withTraceState(OTel.traceState(tracestateMap));
      }
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('Extracted span context: $finalSpanContext');
    }

    return context.withSpanContext(finalSpanContext);
  }

  @override
  void inject(Context context, Map<String, String> carrier,
      TextMapSetter<String> setter) {
    final spanContext = context.spanContext;

    if (OTelLog.isDebug()) {
      OTelLog.debug('Injecting span context: $spanContext');
    }

    if (spanContext == null || !spanContext.isValid) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('No valid span context to inject');
      }
      return;
    }

    // Build traceparent header: version-traceId-spanId-traceFlags
    final traceparent = '$_version-'
        '${spanContext.traceId.hexString}-'
        '${spanContext.spanId.hexString}-'
        '${spanContext.traceFlags}';

    setter.set(_traceparentHeader, traceparent);

    if (OTelLog.isDebug()) {
      OTelLog.debug('Injected traceparent: $traceparent');
    }

    // Inject tracestate if present
    final traceState = spanContext.traceState;
    if (traceState != null && traceState.entries.isNotEmpty) {
      final tracestateValue = _serializeTracestate(traceState);
      setter.set(_tracestateHeader, tracestateValue);

      if (OTelLog.isDebug()) {
        OTelLog.debug('Injected tracestate: $tracestateValue');
      }
    }
  }

  @override
  List<String> fields() => const [_traceparentHeader, _tracestateHeader];

  /// Parses a traceparent header value into a SpanContext.
  ///
  /// The traceparent format is: version-traceId-spanId-traceFlags
  /// Example: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
  ///
  /// Returns null if the format is invalid.
  SpanContext? _parseTraceparent(String traceparent) {
    // Basic validation
    if (traceparent.length != _traceparentLength) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'Invalid traceparent length: ${traceparent.length}, expected $_traceparentLength');
      }
      return null;
    }

    final parts = traceparent.split('-');
    if (parts.length != 4) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'Invalid traceparent format: expected 4 parts, got ${parts.length}');
      }
      return null;
    }

    final version = parts[0];
    final traceIdHex = parts[1];
    final spanIdHex = parts[2];
    final traceFlagsHex = parts[3];

    // Validate version (currently only 00 is supported)
    if (version != _version) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Unsupported traceparent version: $version');
      }
      // Per spec, we should still try to parse if version is unknown
      // but for now we'll reject it
      return null;
    }

    // Validate trace ID length (32 hex chars = 16 bytes)
    if (traceIdHex.length != 32) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'Invalid trace ID length: ${traceIdHex.length}, expected 32');
      }
      return null;
    }

    // Validate span ID length (16 hex chars = 8 bytes)
    if (spanIdHex.length != 16) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'Invalid span ID length: ${spanIdHex.length}, expected 16');
      }
      return null;
    }

    // Validate trace flags length (2 hex chars = 1 byte)
    if (traceFlagsHex.length != 2) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'Invalid trace flags length: ${traceFlagsHex.length}, expected 2');
      }
      return null;
    }

    try {
      // Parse the components
      final traceId = OTel.traceIdFrom(traceIdHex);
      final spanId = OTel.spanIdFrom(spanIdHex);
      final traceFlags = TraceFlags.fromString(traceFlagsHex);

      // Validate that trace ID and span ID are not all zeros
      if (!traceId.isValid) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('Invalid trace ID: all zeros');
        }
        return null;
      }

      if (!spanId.isValid) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('Invalid span ID: all zeros');
        }
        return null;
      }

      // Create the span context with isRemote=true since it came from a carrier
      return OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: traceFlags,
        isRemote: true,
      );
    } catch (e) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Error parsing traceparent: $e');
      }
      return null;
    }
  }

  /// Parses a tracestate header value into a map.
  ///
  /// The tracestate format is: key1=value1,key2=value2,...
  /// Example: rojo=00f067aa0ba902b7,congo=t61rcWkgMzE
  Map<String, String> _parseTracestate(String tracestate) {
    final result = <String, String>{};

    if (tracestate.isEmpty) {
      return result;
    }

    // Split by comma and process each entry
    final entries = tracestate.split(',');
    for (final entry in entries) {
      final trimmedEntry = entry.trim();
      if (trimmedEntry.isEmpty) continue;

      final separatorIndex = trimmedEntry.indexOf('=');
      if (separatorIndex <= 0 || separatorIndex >= trimmedEntry.length - 1) {
        // Invalid format, skip this entry
        if (OTelLog.isDebug()) {
          OTelLog.debug('Invalid tracestate entry format: $trimmedEntry');
        }
        continue;
      }

      final key = trimmedEntry.substring(0, separatorIndex).trim();
      final value = trimmedEntry.substring(separatorIndex + 1).trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        result[key] = value;
      }
    }

    return result;
  }

  /// Serializes a TraceState into a tracestate header value.
  ///
  /// The format is: key1=value1,key2=value2,...
  String _serializeTracestate(TraceState traceState) {
    final entries = traceState.entries;
    if (entries.isEmpty) {
      return '';
    }

    return entries.entries.map((e) => '${e.key}=${e.value}').join(',');
  }
}
