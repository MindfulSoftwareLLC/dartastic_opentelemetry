// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';

import '../../dartastic_opentelemetry.dart';

/// A read-only view of a log record.
///
/// This interface provides read-only access to all LogRecord information
/// for exporters and processors that only need to read the data.
///
/// Implementations can access InstrumentationScope and Resource implicitly.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#readablelogrecord
abstract class ReadableLogRecord implements LogRecord {
  /// The instrumentation scope associated with this log record.
  InstrumentationScope get instrumentationScope;

  /// The resource associated with this log record.
  Resource? get resource;

  /// The count of attributes that were dropped due to limits.
  int get droppedAttributesCount;

  /// The trace ID associated with this log record, if any.
  TraceId? get traceId;

  /// The span ID associated with this log record, if any.
  SpanId? get spanId;

  /// The trace flags associated with this log record, if any.
  TraceFlags? get traceFlags;
}

/// A mutable view of a log record.
///
/// This interface extends ReadableLogRecord to provide write access to
/// log record fields. It is used by LogRecordProcessors that need to
/// modify log records.
///
/// Implementations are NOT required to be concurrent-safe. Asynchronous
/// processors should clone the log record if needed.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#readwritelogrecord
abstract class ReadWriteLogRecord implements ReadableLogRecord {
  /// Sets the timestamp of when the event occurred.
  set timestamp(Int64? value);

  /// Sets the timestamp of when the event was observed.
  set observedTimestamp(Int64? value);

  /// Sets the severity number.
  set severityNumber(Severity? value);

  /// Sets the severity text.
  set severityText(String? value);

  /// Sets the body of the log record.
  set body(dynamic value);

  /// Sets the attributes of the log record.
  set attributes(Attributes? value);

  /// Sets the event name.
  set eventName(String? value);

  /// Sets the trace ID.
  set traceId(TraceId? value);

  /// Sets the span ID.
  set spanId(SpanId? value);

  /// Sets the trace flags.
  set traceFlags(TraceFlags? value);

  /// Adds an attribute to the log record.
  ///
  /// @param attribute The attribute to add
  void addAttribute(Attribute attribute);

  /// Removes an attribute from the log record by key.
  ///
  /// @param key The key of the attribute to remove
  void removeAttribute(String key);

  /// Creates a deep clone of this log record.
  ///
  /// This is useful for async processors that need to avoid race conditions.
  ReadWriteLogRecord clone();
}

/// SDK implementation of ReadWriteLogRecord.
///
/// This class provides the concrete implementation of a log record with
/// both read and write capabilities.
class SDKLogRecord implements ReadWriteLogRecord {
  Int64? _timestamp;
  Int64? _observedTimestamp;
  final Context? _context;
  Severity? _severityNumber;
  String? _severityText;
  dynamic _body;
  Attributes? _attributes;
  String? _eventName;
  TraceId? _traceId;
  SpanId? _spanId;
  TraceFlags? _traceFlags;
  int _droppedAttributesCount = 0;

  final InstrumentationScope _instrumentationScope;
  Resource? _resource;

  /// Maximum number of attributes allowed per log record.
  /// This can be configured via LogRecordLimits.
  static int maxAttributeCount = 128;

  /// Maximum length of attribute values.
  /// This can be configured via LogRecordLimits.
  static int? maxAttributeValueLength;

  /// Creates a new SDK log record.
  ///
  /// @param instrumentationScope The instrumentation scope for this log record
  /// @param resource The resource associated with this log record
  /// @param timestamp When the event occurred
  /// @param observedTimestamp When the event was observed
  /// @param context The context associated with this log record
  /// @param severityNumber The severity level
  /// @param severityText The severity text
  /// @param body The log message body
  /// @param attributes Additional attributes
  /// @param eventName The event name
  SDKLogRecord({
    required InstrumentationScope instrumentationScope,
    Resource? resource,
    Int64? timestamp,
    Int64? observedTimestamp,
    Context? context,
    Severity? severityNumber,
    String? severityText,
    dynamic body,
    Attributes? attributes,
    String? eventName,
  })  : _instrumentationScope = instrumentationScope,
        _resource = resource,
        _timestamp = timestamp,
        _observedTimestamp = observedTimestamp,
        _context = context,
        _severityNumber = severityNumber,
        _severityText = severityText,
        _body = body,
        _attributes = attributes,
        _eventName = eventName {
    // Extract trace context from Context if available
    if (_context != null) {
      final spanContext = _context!.spanContext;
      if (spanContext != null && spanContext.isValid) {
        _traceId = spanContext.traceId;
        _spanId = spanContext.spanId;
        _traceFlags = spanContext.traceFlags;
      }
    }

    // Apply attribute limits
    _applyAttributeLimits();
  }

  void _applyAttributeLimits() {
    if (_attributes == null) return;

    final attrList = _attributes!.toList();
    if (attrList.length > maxAttributeCount) {
      final dropped = attrList.length - maxAttributeCount;
      _droppedAttributesCount += dropped;
      _attributes =
          OTel.attributesFromList(attrList.take(maxAttributeCount).toList());

      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'SDKLogRecord: Dropped $dropped attributes due to limit ($maxAttributeCount)');
      }
    }
  }

  @override
  Int64? get timestamp => _timestamp;

  @override
  set timestamp(Int64? value) {
    _timestamp = value;
  }

  @override
  Int64? get observedTimestamp => _observedTimestamp;

  @override
  set observedTimestamp(Int64? value) {
    _observedTimestamp = value;
  }

  @override
  Context? get context => _context;

  @override
  Severity? get severityNumber => _severityNumber;

  @override
  set severityNumber(Severity? value) {
    _severityNumber = value;
  }

  @override
  String? get severityText => _severityText;

  @override
  set severityText(String? value) {
    _severityText = value;
  }

  @override
  dynamic get body => _body;

  @override
  set body(dynamic value) {
    _body = value;
  }

  @override
  Attributes? get attributes => _attributes;

  @override
  set attributes(Attributes? value) {
    _attributes = value;
    _applyAttributeLimits();
  }

  @override
  String? get eventName => _eventName;

  @override
  set eventName(String? value) {
    _eventName = value;
  }

  @override
  InstrumentationScope get instrumentationScope => _instrumentationScope;

  @override
  Resource? get resource => _resource;

  /// Sets the resource for this log record.
  set resource(Resource? value) {
    _resource = value;
  }

  @override
  int get droppedAttributesCount => _droppedAttributesCount;

  @override
  TraceId? get traceId => _traceId;

  @override
  set traceId(TraceId? value) {
    _traceId = value;
  }

  @override
  SpanId? get spanId => _spanId;

  @override
  set spanId(SpanId? value) {
    _spanId = value;
  }

  @override
  TraceFlags? get traceFlags => _traceFlags;

  @override
  set traceFlags(TraceFlags? value) {
    _traceFlags = value;
  }

  @override
  void addAttribute(Attribute attribute) {
    if (_attributes == null) {
      _attributes = OTel.attributesFromList([attribute]);
    } else {
      final currentList = _attributes!.toList();
      if (currentList.length >= maxAttributeCount) {
        _droppedAttributesCount++;
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'SDKLogRecord: Dropped attribute ${attribute.key} due to limit');
        }
        return;
      }
      _attributes = OTel.attributesFromList([...currentList, attribute]);
    }
  }

  @override
  void removeAttribute(String key) {
    if (_attributes == null) return;
    final filtered = _attributes!.toList().where((a) => a.key != key).toList();
    _attributes = OTel.attributesFromList(filtered);
  }

  @override
  ReadWriteLogRecord clone() {
    return SDKLogRecord(
      instrumentationScope: _instrumentationScope,
      resource: _resource,
      timestamp: _timestamp,
      observedTimestamp: _observedTimestamp,
      context: _context,
      severityNumber: _severityNumber,
      severityText: _severityText,
      body: _body,
      attributes: _attributes,
      eventName: _eventName,
    )
      .._traceId = _traceId
      .._spanId = _spanId
      .._traceFlags = _traceFlags
      .._droppedAttributesCount = _droppedAttributesCount;
  }

  @override
  String toString() {
    final buffer = StringBuffer('SDKLogRecord{');
    buffer.write('timestamp: $timestamp');
    buffer.write(', observedTimestamp: $observedTimestamp');
    buffer.write(', severity: $severityNumber');
    if (severityText != null) buffer.write(' ($severityText)');
    if (body != null) buffer.write(', body: $body');
    if (eventName != null) buffer.write(', eventName: $eventName');
    if (traceId != null) buffer.write(', traceId: $traceId');
    if (spanId != null) buffer.write(', spanId: $spanId');
    if (attributes != null && attributes!.length > 0) {
      buffer.write(', attributes: ${attributes!.length} items');
    }
    buffer.write('}');
    return buffer.toString();
  }
}
