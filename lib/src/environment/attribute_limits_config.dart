// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Configuration for attribute limits read from environment variables.
///
/// Used by both general attribute limits (`OTEL_ATTRIBUTE_*`) and
/// signal-specific limits (e.g., `OTEL_LOGRECORD_ATTRIBUTE_*`).
///
/// Per the OpenTelemetry specification:
/// - Values exceeding the length limit should be truncated.
/// - Attributes exceeding the count limit should be dropped.
/// - Warnings should be logged when limits are exceeded.
///
/// See: https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/#attribute-limits
class AttributeLimitsConfig {
  /// Maximum length of attribute values.
  ///
  /// When set, attribute values longer than this limit should be truncated.
  /// `null` means unlimited (no limit set).
  final int? attributeValueLengthLimit;

  /// Maximum number of attributes allowed per telemetry item.
  ///
  /// When set, attributes beyond this count should be dropped.
  /// `null` means not explicitly configured via environment variable.
  /// The spec default is 128 when not set.
  final int? attributeCountLimit;

  /// Creates a new [AttributeLimitsConfig].
  const AttributeLimitsConfig({
    this.attributeValueLengthLimit,
    this.attributeCountLimit,
  });

  /// Whether no limits were configured from environment variables.
  bool get isEmpty =>
      attributeValueLengthLimit == null && attributeCountLimit == null;

  /// Whether any limits were configured from environment variables.
  bool get isNotEmpty => !isEmpty;

  /// Converts this config to a JSON-compatible map.
  ///
  /// Only includes fields that are non-null, matching the previous
  /// `Map<String, dynamic>` behavior for backward compatibility.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (attributeValueLengthLimit != null) {
      map['attributeValueLengthLimit'] = attributeValueLengthLimit;
    }
    if (attributeCountLimit != null) {
      map['attributeCountLimit'] = attributeCountLimit;
    }
    return map;
  }
}
