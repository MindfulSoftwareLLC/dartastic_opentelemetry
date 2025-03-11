// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

import '../../util/otel_log.dart';

/// W3C Baggage Propagator implementation.
/// https://w3c.github.io/baggage/
class W3CBaggagePropagator implements TextMapPropagator<Map<String, String>, String> {
  static const _baggageHeader = 'baggage';

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

  @override
  List<String> fields() => const [_baggageHeader];

  String _encodeComponent(String value) {
    return Uri.encodeComponent(value)
        .replaceAll('%20', '+')
        .replaceAll('*', '%2A');
  }

  String _decodeComponent(String value) {
    return Uri.decodeComponent(value.replaceAll('+', '%20'));
  }
}
