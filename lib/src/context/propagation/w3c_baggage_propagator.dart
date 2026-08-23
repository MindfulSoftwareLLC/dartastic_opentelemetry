// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../otel.dart';

/// Implementation of the W3C Baggage specification for context propagation.
///
/// This propagator handles the extraction and injection of baggage information
/// following the W3C Baggage specification as defined at:
/// https://www.w3.org/TR/baggage/
///
/// Baggage allows for propagating key-value pairs alongside the trace context
/// across service boundaries. This enables the correlation of related telemetry
/// using application-specific or domain-specific properties.
class W3CBaggagePropagator
    implements TextMapPropagator<Map<String, String>, String> {
  /// The standard header name for W3C baggage as defined in the specification
  static const _baggageHeader = 'baggage';

  /// Extracts baggage information from the carrier and updates the context.
  ///
  /// This method parses the W3C baggage header and creates a new baggage
  /// context to return as part of the updated Context.
  ///
  /// @param context The current context
  /// @param carrier The carrier containing the baggage header
  /// @param getter The getter used to extract values from the carrier
  /// @return A new Context with the extracted baggage
  @override
  Context extract(
    Context context,
    Map<String, String> carrier,
    TextMapGetter<String> getter,
  ) {
    final value = getter.get(_baggageHeader);
    if (OTelLog.isDebug()) {
      OTelLog.debug('Extracting baggage: $value');
    }
    if (value == null || value.isEmpty) {
      // Propagators API spec: extract returns the passed context, updated
      // with extracted values — and unchanged when there is nothing to
      // extract. Returning a fresh context here would discard whatever an
      // earlier propagator in a composite (e.g. tracecontext) extracted.
      return context;
    }

    final entries = <String, BaggageEntry>{};
    final pairs = value.split(',');
    for (final pair in pairs) {
      final trimmedPair = pair.trim();
      if (trimmedPair.isEmpty) continue;

      // Split on the first '=' only — the W3C Baggage spec allows '='
      // inside values (e.g. base64 padding like "token=abc123==").
      final eqIndex = trimmedPair.indexOf('=');
      if (eqIndex <= 0) continue;

      // Keys are tokens per RFC 7230 — they are NOT percent-encoded or
      // decoded on the wire.  Use the raw key as-is.
      final key = trimmedPair.substring(0, eqIndex).trim();
      if (key.isEmpty) continue;

      final valueAndMetadata = trimmedPair.substring(eqIndex + 1).split(';');
      final value = _decodeValue(valueAndMetadata[0].trim());
      String? metadata;
      if (valueAndMetadata.length > 1) {
        metadata = valueAndMetadata.sublist(1).join(';').trim();
      }

      entries[key] = OTel.baggageEntry(value, metadata);
    }

    // Propagators API spec: "If a value can not be parsed from the carrier
    // for a cross-cutting concern, the implementation MUST NOT store a new
    // value in the Context, in order to preserve any previously existing
    // valid value."  An empty entry map means nothing was parsed, so we
    // return the original context untouched.
    if (entries.isEmpty) return context;
    final baggage = OTel.baggage(entries);
    return context.withBaggage(baggage);
  }

  /// Injects baggage from the context into the carrier.
  ///
  /// This method serializes the baggage from the context into the
  /// W3C baggage header format and adds it to the carrier.
  ///
  /// @param context The context containing baggage to be injected
  /// @param carrier The carrier to inject the baggage header into
  /// @param setter The setter used to add values to the carrier
  @override
  void inject(
    Context context,
    Map<String, String> carrier,
    TextMapSetter<String> setter,
  ) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Injecting baggage. Context: $context');
    }
    final contextBaggage = context.baggage;
    if (contextBaggage != null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Context baggage: $contextBaggage (${contextBaggage.runtimeType})',
        );
      }

      final baggage = contextBaggage;
      final entries = baggage.getAllEntries();
      if (OTelLog.isDebug()) OTelLog.debug('Baggage entries: $entries');

      if (entries.isEmpty) {
        if (OTelLog.isDebug()) OTelLog.debug('Empty baggage entries');
        return;
      }

      final serializedEntries = entries.entries.where((entry) {
        if (!_isValidToken(entry.key)) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
              'Dropping baggage entry with invalid key: ${entry.key}',
            );
          }
          return false;
        }
        return true;
      }).map((entry) {
        final key = entry.key;
        final value = _encodeValue(entry.value.value);
        final metadata = entry.value.metadata;
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'Processing entry - Key: $key, Value: $value, Metadata: $metadata',
          );
        }
        if (metadata != null && metadata.isNotEmpty) {
          return '$key=$value;$metadata';
        }
        return '$key=$value';
      }).join(',');

      if (OTelLog.isDebug()) {
        OTelLog.debug('Setting baggage header to: $serializedEntries');
      }
      if (serializedEntries.isNotEmpty) {
        setter.set(_baggageHeader, serializedEntries);
      }
    }
  }

  /// Returns the list of propagation fields used by this propagator.
  ///
  /// @return A list containing the baggage header name
  @override
  List<String> fields() => const [_baggageHeader];

  /// Checks whether [key] is a valid W3C Baggage token (RFC 7230).
  ///
  /// Valid token characters: `!`, `#`, `$`, `%`, `&`, `'`, `*`, `+`, `-`,
  /// `.`, `^`, `_`, `` ` ``, `|`, `~`, digits, and letters.
  bool _isValidToken(String key) {
    if (key.isEmpty) return false;
    for (var i = 0; i < key.length; i++) {
      final code = key.codeUnitAt(i);
      if (!_isTchar(code)) return false;
    }
    return true;
  }

  static bool _isTchar(int code) {
    // "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." /
    // "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
    if (code >= 0x41 && code <= 0x5A) return true; // A-Z
    if (code >= 0x61 && code <= 0x7A) return true; // a-z
    if (code >= 0x30 && code <= 0x39) return true; // 0-9
    switch (code) {
      case 0x21: // !
      case 0x23: // #
      case 0x24: // $
      case 0x25: // %
      case 0x26: // &
      case 0x27: // '
      case 0x2A: // *
      case 0x2B: // +
      case 0x2D: // -
      case 0x2E: // .
      case 0x5E: // ^
      case 0x5F: // _
      case 0x60: // `
      case 0x7C: // |
      case 0x7E: // ~
        return true;
      default:
        return false;
    }
  }

  /// Encodes a baggage value per the W3C Baggage specification.
  ///
  /// The spec's `baggage-octet` set allows most printable ASCII but
  /// excludes space (0x20), `"` (0x22), `,` (0x2C), and `;` (0x3B).
  /// Those four characters are percent-encoded; everything else passes through.
  String _encodeValue(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      switch (code) {
        case 0x20: // space
          buffer.write('%20');
        case 0x22: // "
          buffer.write('%22');
        case 0x2C: // ,
          buffer.write('%2C');
        case 0x3B: // ;
          buffer.write('%3B');
        default:
          buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// Decodes a baggage value (plain percent-decoding, no form-style `+`).
  String _decodeValue(String value) {
    return Uri.decodeComponent(value);
  }
}
