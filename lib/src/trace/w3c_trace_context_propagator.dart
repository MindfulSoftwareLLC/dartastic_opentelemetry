// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../otel.dart';

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

  /// The highest traceparent version this propagator understands, and the
  /// version it emits. Per the spec's versioning rules, higher versions are
  /// parsed using this version's field layout.
  static const _version = '00';

  /// The version reserved as invalid by the specification.
  static const _forbiddenVersion = 'ff';

  static const _versionLength = 2;
  static const _traceIdLength = 32;
  static const _spanIdLength = 16;
  static const _traceFlagsLength = 2;

  /// Field offsets, applied to every version. The spec assumes future versions
  /// will be additive to version 00, and on that basis defines the parse of a
  /// higher version as reading these same positions.
  static const _traceIdOffset = _versionLength + 1;
  static const _spanIdOffset = _traceIdOffset + _traceIdLength + 1;
  static const _traceFlagsOffset = _spanIdOffset + _spanIdLength + 1;

  /// The exact length of a version 00 traceparent, and the minimum length of
  /// any traceparent.
  static const _traceparentLength = _traceFlagsOffset + _traceFlagsLength;

  @override
  Context extract(
    Context context,
    Map<String, String> carrier,
    TextMapGetter<String> getter,
  ) {
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
    var finalSpanContext = spanContext;

    if (tracestate != null && tracestate.isNotEmpty) {
      final tracestateMap = _parseTracestate(tracestate);
      if (tracestateMap.isNotEmpty) {
        finalSpanContext = spanContext.withTraceState(
          OTel.traceState(tracestateMap),
        );
      }
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('Extracted span context: $finalSpanContext');
    }

    return context.withSpanContext(finalSpanContext);
  }

  @override
  void inject(
    Context context,
    Map<String, String> carrier,
    TextMapSetter<String> setter,
  ) {
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
  /// A version above [_version] may append further dash-delimited fields, which
  /// are ignored. Versions up to [_version] must carry no trailing data. Every
  /// field must be lowercase hex, and version `ff` is always invalid.
  ///
  /// Returns null if the format is invalid.
  SpanContext? _parseTraceparent(String traceparent) {
    if (traceparent.length < _traceparentLength) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid traceparent length: ${traceparent.length}, expected at least $_traceparentLength',
        );
      }
      return null;
    }

    if (traceparent[_traceIdOffset - 1] != '-' ||
        traceparent[_spanIdOffset - 1] != '-' ||
        traceparent[_traceFlagsOffset - 1] != '-') {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Invalid traceparent format: misplaced delimiters');
      }
      return null;
    }

    // The API's hex parser accepts lowercase hex only, as the W3C grammar
    // requires, and returns null rather than reporting an error: a malformed
    // incoming header is not API misuse.
    final version = traceparent.substring(0, _versionLength);
    if (IdGenerator.hexToBytes(version) == null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid traceparent version, expected only 0-9 and a-f: $version',
        );
      }
      return null;
    }

    if (version == _forbiddenVersion) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid traceparent version: $_forbiddenVersion is reserved as invalid',
        );
      }
      return null;
    }

    // A known version has a closed grammar, so trailing data makes it
    // malformed. A higher version may append dash-delimited fields, which this
    // propagator must tolerate and ignore. Lowercase hex pairs order the same
    // way as their values, so compareTo ranks versions.
    if (version.compareTo(_version) <= 0) {
      if (traceparent.length != _traceparentLength) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'Version $version traceparent must be exactly $_traceparentLength characters, got ${traceparent.length}',
          );
        }
        return null;
      }
    } else if (traceparent.length > _traceparentLength &&
        traceparent[_traceparentLength] != '-') {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid traceparent: trace flags must end the header or be followed by a dash',
        );
      }
      return null;
    }

    final traceIdHex = traceparent.substring(
      _traceIdOffset,
      _traceIdOffset + _traceIdLength,
    );
    final traceIdBytes = IdGenerator.hexToBytes(traceIdHex);
    if (traceIdBytes == null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid trace ID, expected only 0-9 and a-f: $traceIdHex',
        );
      }
      return null;
    }

    final spanIdHex = traceparent.substring(
      _spanIdOffset,
      _spanIdOffset + _spanIdLength,
    );
    final spanIdBytes = IdGenerator.hexToBytes(spanIdHex);
    if (spanIdBytes == null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid span ID, expected only 0-9 and a-f: $spanIdHex',
        );
      }
      return null;
    }

    // The whole byte is kept, so flags this SDK does not model still
    // propagate, and the random-trace-id bit survives as W3C Level 2 requires.
    final traceFlagsHex = traceparent.substring(
      _traceFlagsOffset,
      _traceFlagsOffset + _traceFlagsLength,
    );
    final traceFlags = TraceFlags.fromString(traceFlagsHex);
    if (traceFlags == null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Invalid trace flags, expected only 0-9 and a-f: $traceFlagsHex',
        );
      }
      return null;
    }

    // Header content can no longer fail past this point. The SDK factory can:
    // it throws a StateError before OTel.initialize(), and extract must not
    // throw on that, so the header is dropped instead.
    try {
      final traceId = OTel.traceIdOf(traceIdBytes);
      if (!traceId.isValid) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('Invalid trace ID: all zeros');
        }
        return null;
      }

      final spanId = OTel.spanIdOf(spanIdBytes);
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
      // ignore: avoid_catching_errors
    } on StateError catch (e) {
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
