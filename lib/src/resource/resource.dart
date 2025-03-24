// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:meta/meta.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

import '../util/otel_log.dart';

part 'resource_create.dart';

/// Represents a resource, which captures identifying information about the entities
/// for which signals (stats and traces) are reported.
@immutable
class Resource {
  final Attributes _attributes;
  final String? _schemaUrl;

  /// Quickly create empty resources, this is duplicated in OTel but the
  /// spec says "quickly" so it's also here.
  static final Resource empty = Resource._(OTel.attributesFromMap({}));

  Attributes get attributes => _attributes;
  String? get schemaUrl => _schemaUrl;

  Resource._(Attributes attributes, [String? schemaUrl])
      : _attributes = attributes,
        _schemaUrl = schemaUrl;

  Resource merge(Resource other) {
    final mergedMap = <String, Object>{};

    // Add current attributes
    _attributes.toMap().forEach((key, value) {
      mergedMap[key] = value.value;
    });

    // Add other resource's attributes (they take precedence)
    other._attributes.toMap().forEach((key, value) {
      mergedMap[key] = value.value;
    });

    // Handle schema URL merging according to spec
    String? mergedSchemaUrl;
    if (_schemaUrl == null || _schemaUrl!.isEmpty) {
      mergedSchemaUrl = other._schemaUrl;
    } else if (other._schemaUrl == null || other._schemaUrl!.isEmpty) {
      mergedSchemaUrl = _schemaUrl;
    } else if (_schemaUrl == other._schemaUrl) {
      mergedSchemaUrl = _schemaUrl;
    } else {
      // Schema URLs are different and non-empty - this is a merging error
      // The spec says the result is implementation-specific
      // We'll choose to use the updating resource's schema URL
      mergedSchemaUrl = other._schemaUrl;
    }

    final result = Resource._(OTel.attributesFromMap(mergedMap), mergedSchemaUrl);

    if (OTelLog.isDebug()) {
      OTelLog.debug('Resource merge result attributes:');
      result._attributes.toList().forEach((attr) {
        if (attr.key == 'tenant_id' || attr.key == 'service.name') {
          OTelLog.debug('  ${attr.key}: ${attr.value}');
        }
      });
    }

    return result;
  }
}
