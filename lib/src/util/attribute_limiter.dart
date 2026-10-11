// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

import '../otel.dart';

/// Limits attributes according to count and value length limits.
///
/// Shared utility with no span-specific knowledge, reusable by spans,
/// span events, span links, and log records.
@internal
class AttributeLimiter {
  /// The maximum number of attributes allowed in a collection.
  final int countLimit;

  /// The maximum allowed length for string attribute values.
  /// When `null`, there is no length limit.
  final int? valueLengthLimit;

  /// Creates an [AttributeLimiter] with the specified limits.
  const AttributeLimiter({
    this.countLimit = 128,
    this.valueLengthLimit,
  })  : assert(countLimit >= 0, 'countLimit must be non-negative'),
        assert(
          valueLengthLimit == null || valueLengthLimit >= 0,
          'valueLengthLimit must be non-negative',
        );

  /// Returns whether [codeUnit] is a UTF-16 lead (high) surrogate (0xD800..0xDBFF).
  static bool isLeadSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  /// Returns whether [codeUnit] is a UTF-16 trail (low) surrogate (0xDC00..0xDFFF).
  static bool isTrailSurrogate(int codeUnit) =>
      codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

  /// Truncates [value] to [limit] characters without splitting a surrogate pair.
  ///
  /// If [limit] is `null`, returns [value] unchanged.
  /// If [limit] is 0, returns `null` (dropped).
  /// If [value.length <= limit], returns [value].
  /// If truncation would split a surrogate pair (ending on a lead surrogate),
  /// backs up 1 code unit.
  /// If the string would truncate to empty (length 0), returns `null` (dropped).
  static String? truncateString(String value, int? limit) {
    if (limit == null) return value;
    if (limit <= 0) return null;
    if (value.length <= limit) return value;

    var end = limit;
    if (isLeadSurrogate(value.codeUnitAt(end - 1))) {
      end -= 1;
    }
    if (end <= 0) return null;
    return value.substring(0, end);
  }

  /// Truncates each element of [list] using [truncateString].
  ///
  /// If [limit] is `null`, returns [list] unchanged.
  /// If [limit] is 0, returns `null` (dropped).
  /// If [list] is empty, returns [list] (unless [limit] is 0).
  /// Drops any element that would truncate to empty (or null).
  /// If all elements are dropped (resulting list is empty but original was not),
  /// returns `null` (dropped).
  static List<String>? truncateStringList(List<String> list, int? limit) {
    if (limit == null) return list;
    if (limit <= 0) return null;
    if (list.isEmpty) return list;

    final truncated = <String>[];
    for (final item in list) {
      final s = truncateString(item, limit);
      if (s != null) {
        truncated.add(s);
      }
    }
    if (truncated.isEmpty) return null;
    return truncated;
  }

  /// Limits an attribute value based on [valueLengthLimit].
  ///
  /// Returns `null` if the value is dropped.
  Object? limitValue(Object value) {
    if (value is String) {
      return truncateString(value, valueLengthLimit);
    } else if (value is List<String>) {
      return truncateStringList(value, valueLengthLimit);
    }
    return value;
  }

  /// Checks if [limited] differs from [original] due to truncation.
  ///
  /// Returns `true` if truncated, `false` otherwise.
  static bool wasValueTruncated(Object original, Object? limited) {
    if (limited == null) return false; // Handled as dropped, not just truncated
    if (original is String && limited is String) {
      return limited.length < original.length;
    }
    if (original is List<String> && limited is List<String>) {
      if (limited.length < original.length) return true;
      for (var i = 0; i < limited.length; i++) {
        if (limited[i].length < original[i].length) return true;
      }
    }
    return false;
  }

  /// Applies limits to an incoming map of attributes, starting from an empty collection.
  ///
  /// Returns a record with:
  /// - `attributes`: the limited [Attributes]
  /// - `droppedCount`: the number of attributes dropped
  /// - `hadDiscardOrTruncation`: whether any attribute was dropped or truncated
  ({Attributes attributes, int droppedCount, bool hadDiscardOrTruncation})
      limitAttributes(Attributes? input) {
    if (input == null) {
      return (
        attributes: OTel.attributesFromMap({}),
        droppedCount: 0,
        hadDiscardOrTruncation: false,
      );
    }

    final resultMap = <String, Object>{};
    var droppedCount = 0;
    var hadDiscardOrTruncation = false;

    for (final attr in input.toList()) {
      final key = attr.key;
      final rawValue = attr.value;

      if (resultMap.containsKey(key)) {
        // Updating an existing key is allowed even at count limit
        final limited = limitValue(rawValue);
        if (limited == null) {
          droppedCount++;
          hadDiscardOrTruncation = true;
        } else {
          if (wasValueTruncated(rawValue, limited)) {
            hadDiscardOrTruncation = true;
          }
          resultMap[key] = limited;
        }
      } else {
        if (resultMap.length >= countLimit) {
          droppedCount++;
          hadDiscardOrTruncation = true;
        } else {
          final limited = limitValue(rawValue);
          if (limited == null) {
            droppedCount++;
            hadDiscardOrTruncation = true;
          } else {
            if (wasValueTruncated(rawValue, limited)) {
              hadDiscardOrTruncation = true;
            }
            resultMap[key] = limited;
          }
        }
      }
    }

    return (
      attributes: OTel.attributesFromMap(resultMap),
      droppedCount: droppedCount,
      hadDiscardOrTruncation: hadDiscardOrTruncation,
    );
  }
}
