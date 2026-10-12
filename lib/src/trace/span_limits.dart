// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

import '../environment/otel_env.dart';

/// Configuration of limits for data collection on spans.
///
/// Follows the OpenTelemetry Trace SDK specification (v1.60.0) for
/// Span Limits and Attribute Limits.
@immutable
class SpanLimits {
  /// Default limit for attribute counts.
  static const int defaultAttributeCountLimit = 128;

  /// Default limit for event counts.
  static const int defaultEventCountLimit = 128;

  /// Default limit for link counts.
  static const int defaultLinkCountLimit = 128;

  /// Default limit for attribute count per event.
  static const int defaultAttributePerEventCountLimit = 128;

  /// Default limit for attribute count per link.
  static const int defaultAttributePerLinkCountLimit = 128;

  /// The maximum number of attributes allowed per span.
  final int attributeCountLimit;

  /// The maximum allowed length for string attribute values.
  /// When `null`, there is no length limit.
  final int? attributeValueLengthLimit;

  /// The maximum number of events allowed per span.
  final int eventCountLimit;

  /// The maximum number of links allowed per span.
  final int linkCountLimit;

  /// The maximum number of attributes allowed per span event.
  final int attributePerEventCountLimit;

  /// The maximum number of attributes allowed per span link.
  final int attributePerLinkCountLimit;

  /// Creates a new immutable [SpanLimits] instance with the specified limits.
  const SpanLimits({
    this.attributeCountLimit = defaultAttributeCountLimit,
    this.attributeValueLengthLimit,
    this.eventCountLimit = defaultEventCountLimit,
    this.linkCountLimit = defaultLinkCountLimit,
    this.attributePerEventCountLimit = defaultAttributePerEventCountLimit,
    this.attributePerLinkCountLimit = defaultAttributePerLinkCountLimit,
  })  : assert(attributeCountLimit >= 0,
            'attributeCountLimit must be non-negative'),
        assert(
            attributeValueLengthLimit == null || attributeValueLengthLimit >= 0,
            'attributeValueLengthLimit must be non-negative'),
        assert(eventCountLimit >= 0, 'eventCountLimit must be non-negative'),
        assert(linkCountLimit >= 0, 'linkCountLimit must be non-negative'),
        assert(attributePerEventCountLimit >= 0,
            'attributePerEventCountLimit must be non-negative'),
        assert(attributePerLinkCountLimit >= 0,
            'attributePerLinkCountLimit must be non-negative');

  /// Creates a [SpanLimits] by reading environment variables via [OTelEnv].
  ///
  /// Falls back to standard defaults if variables are missing or invalid.
  factory SpanLimits.fromEnvironment([SpanLimitsEnvironmentValues? env]) {
    final values = env ?? OTelEnv.getSpanLimits();
    return SpanLimits(
      attributeCountLimit:
          values.attributeCountLimit ?? defaultAttributeCountLimit,
      attributeValueLengthLimit: values.attributeValueLengthLimit,
      eventCountLimit: values.eventCountLimit ?? defaultEventCountLimit,
      linkCountLimit: values.linkCountLimit ?? defaultLinkCountLimit,
      attributePerEventCountLimit: values.attributePerEventCountLimit ??
          defaultAttributePerEventCountLimit,
      attributePerLinkCountLimit: values.attributePerLinkCountLimit ??
          defaultAttributePerLinkCountLimit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpanLimits &&
          runtimeType == other.runtimeType &&
          attributeCountLimit == other.attributeCountLimit &&
          attributeValueLengthLimit == other.attributeValueLengthLimit &&
          eventCountLimit == other.eventCountLimit &&
          linkCountLimit == other.linkCountLimit &&
          attributePerEventCountLimit == other.attributePerEventCountLimit &&
          attributePerLinkCountLimit == other.attributePerLinkCountLimit;

  @override
  int get hashCode => Object.hash(
        attributeCountLimit,
        attributeValueLengthLimit,
        eventCountLimit,
        linkCountLimit,
        attributePerEventCountLimit,
        attributePerLinkCountLimit,
      );

  @override
  String toString() => 'SpanLimits('
      'attributeCountLimit: $attributeCountLimit, '
      'attributeValueLengthLimit: $attributeValueLengthLimit, '
      'eventCountLimit: $eventCountLimit, '
      'linkCountLimit: $linkCountLimit, '
      'attributePerEventCountLimit: $attributePerEventCountLimit, '
      'attributePerLinkCountLimit: $attributePerLinkCountLimit)';
}
