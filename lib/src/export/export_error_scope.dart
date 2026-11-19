// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Internal reporting context for one export or lifecycle operation.
///
/// Nested processors/readers can supply a fallback for silent custom exporters
/// without duplicating a diagnostic already emitted by an SDK exporter. Zones
/// keep overlapping operations independent; no global handler is replaced.
class ExportErrorScope {
  static final Object _key = Object();
  final ExportErrorScope? _parent;
  bool _handled = false;
  bool _finished = false;
  Object? _handlerException;

  ExportErrorScope._(this._parent);

  /// Runs one operation with its own reporting state.
  static Future<T> run<T>(Future<T> Function(ExportErrorScope scope) action) {
    final scope = ExportErrorScope._(Zone.current[_key] as ExportErrorScope?);
    return runZoned(() async {
      try {
        return await action(scope);
      } finally {
        scope._finished = true;
      }
    }, zoneValues: {_key: scope});
  }

  /// Reports an original SDK error and marks enclosing operations as handled.
  static void report(Object error, [StackTrace? stackTrace]) {
    final scope = Zone.current[_key] as ExportErrorScope?;
    if (scope?._handled ?? false) return;
    // A timeout ends the owning operation without cancelling its exporter.
    // Ignore late results, including those from nested composite delegates.
    // A handled but still active parent must not suppress sibling delegates.
    for (var current = scope; current != null; current = current._parent) {
      if (current._finished) return;
    }
    scope?._markHandled();
    try {
      OTelErrorHandling.report(error, stackTrace);
    } catch (handlerError) {
      for (var current = scope; current != null; current = current._parent) {
        current._handlerException = handlerError;
      }
      rethrow;
    }
  }

  /// Marks expected cancellation as handled, so callers do not invent errors.
  static void suppress() {
    (Zone.current[_key] as ExportErrorScope?)?._markHandled();
  }

  void _markHandled() {
    for (ExportErrorScope? current = this;
        current != null;
        current = current._parent) {
      current._handled = true;
    }
  }

  /// Reports a fallback only if this operation has no diagnostic yet.
  /// Deliberate handler exceptions must escape rather than be reported again.
  void reportIfNeeded(Object error, [StackTrace? stackTrace]) {
    if (identical(error, _handlerException)) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
    }
    if (!_handled) report(error, stackTrace);
  }
}
