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
    OTelLog.debug('Extracting baggage: $value');
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

      final key = _decodeComponent(trimmedPair.substring(0, eqIndex).trim());
      if (key.isEmpty) continue;

      final valueAndMetadata = trimmedPair.substring(eqIndex + 1).split(';');
      final value = _decodeComponent(valueAndMetadata[0].trim());
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

      final serializedEntries = entries.entries.map((entry) {
        final key = _encodeComponent(entry.key);
        final value = _encodeComponent(entry.value.value);
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

  /// Encodes a component for use in the baggage header.
  ///
  /// @param value The value to encode
  /// @return The encoded value
  String _encodeComponent(String value) {
    return Uri.encodeComponent(
      value,
    ).replaceAll('%20', '+').replaceAll('*', '%2A');
  }

  /// Decodes a component from the baggage header.
  ///
  /// @param value The value to decode
  /// @return The decoded value
  String _decodeComponent(String value) {
    return Uri.decodeComponent(value.replaceAll('+', '%20'));
  }
}
