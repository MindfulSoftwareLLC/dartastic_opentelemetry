// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Implementation of the W3C Baggage specification for context propagation.
///
/// This propagator handles the extraction and injection of baggage information
/// following the W3C Baggage specification as defined at:
/// https://www.w3.org/TR/baggage/
///
/// Baggage allows for propagating key-value pairs alongside the trace context
/// across service boundaries. This enables the correlation of related telemetry
/// using application-specific or domain-specific properties.
class W3CBaggagePropagator implements TextMapPropagator<Map<String, String>, String> {
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
  Context extract(Context context, Map<String, String> carrier, TextMapGetter<String> getter) {
    final value = getter.get(_baggageHeader);
    OTelLog.debug('Extracting baggage: $value');
    if (value == null || value.isEmpty) {
      // Return context with empty baggage instead of original context
      return OTel.context();
    }

    final entries = <String, BaggageEntry>{};
    final pairs = value.split(',');
    for (final pair in pairs) {
      final trimmedPair = pair.trim();
      if (trimmedPair.isEmpty) continue;

      final keyValue = trimmedPair.split('=');
      if (keyValue.length != 2) continue;

      final key = _decodeComponent(keyValue[0].trim());
      if (key.isEmpty) continue;

      final valueAndMetadata = keyValue[1].split(';');
      final value = _decodeComponent(valueAndMetadata[0].trim());
      String? metadata;
      if (valueAndMetadata.length > 1) {
        metadata = valueAndMetadata.sublist(1).join(';').trim();
      }

      entries[key] = OTel.baggageEntry(value, metadata);
    }

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
  void inject(Context context, Map<String, String> carrier, TextMapSetter<String> setter) {
    if (OTelLog.isDebug()) OTelLog.debug('Injecting baggage. Context: $context');
    final contextBaggage = context.baggage;
    if (contextBaggage != null) {
      if (OTelLog.isDebug()) OTelLog.debug('Context baggage: $contextBaggage (${contextBaggage.runtimeType})');

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
            'Processing entry - Key: $key, Value: $value, Metadata: $metadata');
        }
        if (metadata != null && metadata.isNotEmpty) {
          return '$key=$value;$metadata';
        }
        return '$key=$value';
      }).join(',');

      if (OTelLog.isDebug()) OTelLog.debug('Setting baggage header to: $serializedEntries');
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
    return Uri.encodeComponent(value)
        .replaceAll('%20', '+')
        .replaceAll('*', '%2A');
  }

  /// Decodes a component from the baggage header.
  ///
  /// @param value The value to decode
  /// @return The decoded value
  String _decodeComponent(String value) {
    return Uri.decodeComponent(value.replaceAll('+', '%20'));
  }
}
