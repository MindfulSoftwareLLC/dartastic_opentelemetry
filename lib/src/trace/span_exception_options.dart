// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Callback that transforms a raw exception into sanitized span data.
///
/// Used by [SpanExceptionOptions.exceptionSanitizer] to control exactly what
/// exception information is recorded on a span, for example to strip PII,
/// tokens, request URLs, or user IDs from an error message before it is
/// recorded.
typedef ExceptionSanitizer = SanitizedSpanException Function(
  Object error,
  StackTrace stackTrace,
);

/// Controls how exceptions thrown from the function passed to
/// [Tracer.withSpan] / [Tracer.withSpanAsync] (and the convenience methods
/// that route through them) are recorded.
///
/// Can be configured globally via `OTel.initialize(spanExceptionOptions: ...)`
/// (or per [TracerProvider] via [TracerProvider.spanExceptionOptions]) and
/// overridden per call via the `exceptionOptions` parameter of the withSpan
/// family. Per-call options are merged field-by-field over the global
/// configuration (see [mergeWith]), so overriding a single flag preserves the
/// globally configured sanitizer.
///
/// The defaults preserve the library's historical behavior: a thrown
/// exception is recorded on the span and the span status is set to
/// [SpanStatusCode.Error]. The original exception is always rethrown
/// regardless of these options.
///
/// This mirrors OpenTelemetry Python's `record_exception` /
/// `set_status_on_exception` controls and the Grafana Faro Flutter SDK's
/// `SpanExceptionOptions`, while additionally allowing the exception details
/// to be sanitized via [exceptionSanitizer].
///
/// Example:
/// ```dart
/// await tracer.withSpanAsync(
///   span,
///   () async => await doWork(),
///   exceptionOptions: SpanExceptionOptions(
///     exceptionSanitizer: (error, stackTrace) {
///       return SanitizedSpanException(
///         type: error.runtimeType.toString(),
///         message: redact(error.toString()),
///         stackTrace: sanitizeStackTrace(stackTrace),
///         statusDescription: 'sanitized exception',
///       );
///     },
///   ),
/// );
/// ```
class SpanExceptionOptions {
  /// Creates span exception options.
  ///
  /// Omitted parameters inherit from global configuration when these options
  /// are used as a per-call override (see [mergeWith]). Without global
  /// configuration, omitted parameters default to the SDK's standard
  /// behavior:
  /// - [recordException]: `true` — auto-record exceptions on the span
  /// - [setStatusOnException]: `true` — auto-set span status to error
  /// - [exceptionSanitizer]: `null` — record the raw exception as-is
  const SpanExceptionOptions({
    bool? recordException,
    bool? setStatusOnException,
    this.exceptionSanitizer,
  })  : _recordException = recordException,
        _setStatusOnException = setStatusOnException;

  /// The SDK default span exception behavior: record the exception and set
  /// the span status to error.
  static const SpanExceptionOptions defaults = SpanExceptionOptions(
    recordException: true,
    setStatusOnException: true,
  );

  final bool? _recordException;
  final bool? _setStatusOnException;

  /// Whether the SDK should automatically record the exception on the span.
  ///
  /// When `true` (default), the SDK records an `exception` event on the span.
  /// When `false`, the SDK skips automatic exception recording.
  bool get recordException => _recordException ?? true;

  /// Whether the SDK should automatically set the span status to
  /// [SpanStatusCode.Error] when the wrapped function throws.
  ///
  /// When `true` (the default) the status is set; when `false` it is left
  /// untouched.
  bool get setStatusOnException => _setStatusOnException ?? true;

  /// Optional callback to sanitize exception data before it is recorded.
  ///
  /// When provided, the SDK uses the returned [SanitizedSpanException] to
  /// record the exception instead of the raw error object — the original
  /// exception's type, message, and stack trace are never recorded, so
  /// unsanitized data cannot leak. This is useful for removing PII or other
  /// sensitive data from error messages.
  ///
  /// The sanitizer is only invoked when [recordException] or
  /// [setStatusOnException] is `true`. If the sanitizer itself throws, the
  /// original exception is not recorded and the span is marked with
  /// [SpanStatusCode.Error] using a generic description.
  final ExceptionSanitizer? exceptionSanitizer;

  /// Returns a new options object with [overrides] applied field-by-field.
  ///
  /// This allows a per-call override like
  /// `SpanExceptionOptions(recordException: false)` to keep a globally
  /// configured [exceptionSanitizer] while changing only one flag.
  ///
  /// Note: passing `exceptionSanitizer: null` in [overrides] is
  /// indistinguishable from not setting it — to intentionally clear a global
  /// sanitizer, use separate configuration.
  SpanExceptionOptions mergeWith(SpanExceptionOptions? overrides) {
    if (overrides == null) {
      return this;
    }
    return SpanExceptionOptions(
      recordException: overrides._recordException ?? _recordException,
      setStatusOnException:
          overrides._setStatusOnException ?? _setStatusOnException,
      exceptionSanitizer: overrides.exceptionSanitizer ?? exceptionSanitizer,
    );
  }
}

/// Sanitized exception data to record on a span.
///
/// Returned by an [ExceptionSanitizer] to control exactly what gets recorded
/// as exception attributes on the span. The fields map directly to the
/// OpenTelemetry exception semantic conventions:
///
/// - [type] -> `exception.type`
/// - [message] -> `exception.message`
/// - [stackTrace] -> `exception.stacktrace` (omitted when null)
class SanitizedSpanException {
  /// Creates a sanitized span exception.
  const SanitizedSpanException({
    required this.type,
    required this.message,
    this.stackTrace,
    this.statusDescription,
  });

  /// The exception type, recorded as the `exception.type` attribute.
  final String type;

  /// The sanitized error message, recorded as the `exception.message`
  /// attribute.
  final String message;

  /// Optional sanitized stack trace, recorded as the `exception.stacktrace`
  /// attribute. When `null`, no stack trace is recorded. The original
  /// (unsanitized) stack trace is never recorded when a sanitizer is used.
  final StackTrace? stackTrace;

  /// Optional status description used when setting the span status to
  /// [SpanStatusCode.Error]. Falls back to [message] when not provided.
  final String? statusDescription;
}
