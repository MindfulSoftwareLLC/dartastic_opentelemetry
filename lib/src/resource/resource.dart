// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

part 'resource_create.dart';

/// Represents a resource, which captures identifying information about the entities
/// for which signals (stats, traces, and logs) are reported.
///
/// A Resource is an immutable collection of attributes that provide information
/// about the entity producing telemetry. Resources are a core concept of OpenTelemetry's
/// identity model.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/resource/sdk/
///
/// Note: Per [OTEP 0265](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/0265-event-vision.md),
/// span events are being deprecated and will be replaced by the Logging API.
@immutable
class Resource {
  final Attributes _attributes;
  final String? _schemaUrl;

  /// An empty resource with no attributes.
  ///
  /// This is a convenience constant for when no resource attributes are needed.
  static final Resource empty = Resource._(OTel.attributesFromMap({}));

  /// Gets the attributes describing this resource.
  Attributes get attributes => _attributes;

  /// Gets the schema URL for this resource's attributes, if any.
  String? get schemaUrl => _schemaUrl;

  /// Private constructor for creating Resource instances.
  ///
  /// Resources should be created through the [OTel.resource] method
  /// or [ResourceCreate.create] method, not directly.
  Resource._(Attributes attributes, [String? schemaUrl])
      : _attributes = attributes,
        _schemaUrl = schemaUrl;

  /// Merges this resource with another resource.
  ///
  /// The resulting resource contains the combined attributes of both resources.
  /// If there are attributes with the same key, the attributes from the other
  /// resource will take precedence.
  ///
  /// For schema URLs, the following rules apply:
  /// - If one schema URL is empty, use the non-empty one
  /// - If both schema URLs are the same, use that schema URL
  /// - If both schema URLs are different and non-empty, use the other resource's schema URL
  ///
  /// @param other The resource to merge with this resource
  /// @return A new resource with the merged attributes
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

    final result =
        Resource._(OTel.attributesFromMap(mergedMap), mergedSchemaUrl);

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
