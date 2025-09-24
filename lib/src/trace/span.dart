// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

import '../resource/resource.dart';
import 'tracer.dart';

part 'span_create.dart';

/// SDK implementation of the APISpan interface.
///
/// A Span represents a single operation within a trace. Spans can be nested
/// to form a trace tree. Each trace contains a root span, which typically
/// describes the entire operation and, optionally, one or more sub-spans
/// for its sub-operations.
///
/// This implementation delegates most functionality to the API Span implementation
/// while adding SDK-specific behaviors like span processor notification.
///
/// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
/// span events are being deprecated and will be replaced by the Logging API in future versions.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/
class Span implements APISpan {
  final APISpan _delegate;
  final Tracer _sdkTracer;

  /// Private constructor for creating Span instances.
  ///
  /// @param delegate The API Span implementation to delegate to
  /// @param sdkTracer The SDK Tracer that created this Span
  Span._(APISpan delegate, Tracer sdkTracer)
      : _delegate = delegate,
        _sdkTracer = sdkTracer {
    if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Created new span with name ${delegate.name}');
  }

  /// Gets the resource associated with this span's tracer.
  ///
  /// @return The resource associated with this span
  Resource? get resource => _sdkTracer.resource;

  @override
  void end({DateTime? endTime, SpanStatusCode? spanStatus}) {
    if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Starting to end span ${spanContext.spanId} with name $name');

    if (spanStatus != null) {
      setStatus(spanStatus);
    }

    try {
      if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Calling delegate.end() for span $name');
      _delegate.end(endTime: endTime, spanStatus: spanStatus);
      if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Delegate.end() completed for span $name');

      // Notify span processors that this span has ended
      final provider = _sdkTracer.provider;
      if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Notifying ${provider.spanProcessors.length} span processors');
      for (final processor in provider.spanProcessors) {
        try {
          if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Calling onEnd for processor ${processor.runtimeType}');
          processor.onEnd(this);
          if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Successfully called onEnd for processor ${processor.runtimeType}');
        } catch (e, stackTrace) {
          if (OTelLog.isError()) {
            OTelLog.error('SDKSpan: Error calling onEnd for processor ${processor.runtimeType}: $e');
            OTelLog.error('Stack trace: $stackTrace');
          }
        }
      }
    } catch (e, stackTrace) {
      if (OTelLog.isError()) OTelLog.error('SDKSpan: Error during end(): $e');
      if (OTelLog.isError()) OTelLog.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  set attributes(Attributes newAttributes) => _delegate.attributes = newAttributes;

  @override
  void addAttributes(Attributes attributes) => _delegate.addAttributes(attributes);

  @override
  void addEvent(SpanEvent spanEvent) => _delegate.addEvent(spanEvent);

  @override
  void addEventNow(String name, [Attributes? attributes]) => _delegate.addEventNow(name, attributes);

  @override
  void addEvents(Map<String, Attributes?> spanEvents) => _delegate.addEvents(spanEvents);

  @override
  void addLink(SpanContext spanContext, [Attributes? attributes]) => _delegate.addLink(spanContext, attributes);

  @override
  void addSpanLink(SpanLink spanLink) => _delegate.addSpanLink(spanLink);

  @override
  DateTime? get endTime => _delegate.endTime;

  @override
  bool get isEnded => _delegate.isEnded;

  @override
  bool get isRecording => _delegate.isRecording;

  @override
  SpanKind get kind => _delegate.kind;

  @override
  String get name => _delegate.name;

  @override
  APISpan? get parentSpan => _delegate.parentSpan;

  @override
  void recordException(Object exception,
      {StackTrace? stackTrace, Attributes? attributes, bool? escaped}) =>
          _delegate.recordException(exception,
              stackTrace: stackTrace,
              attributes: attributes,
              escaped: escaped);

  @override
  void setBoolAttribute(String name, bool value) => _delegate.setBoolAttribute(name, value);

  @override
  void setBoolListAttribute(String name, List<bool> value) => _delegate.setBoolListAttribute(name, value);

  @override
  void setDoubleAttribute(String name, double value) => _delegate.setDoubleAttribute(name, value);

  @override
  void setDoubleListAttribute(String name, List<double> value) => _delegate.setDoubleListAttribute(name, value);

  @override
  void setIntAttribute(String name, int value) => _delegate.setIntAttribute(name, value);

  @override
  void setIntListAttribute(String name, List<int> value) => _delegate.setIntListAttribute(name, value);

  @override
  void setStatus(SpanStatusCode statusCode, [String? description]) {
    _delegate.setStatus(statusCode, description);
    if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Set status to $statusCode for span ${spanContext.spanId}');
  }

  @override
  void setStringAttribute<T>(String name, String value) => _delegate.setStringAttribute<T>(name, value);

  @override
  void setStringListAttribute<T>(String name, List<String> value) => _delegate.setStringListAttribute<T>(name, value);

  @override
  void setDateTimeAsStringAttribute(String name, DateTime value) => _delegate.setDateTimeAsStringAttribute(name, value);

  @override
  SpanContext get spanContext => _delegate.spanContext;

  @override
  List<SpanEvent>? get spanEvents => _delegate.spanEvents;

  @override
  SpanId get spanId => _delegate.spanId;

  @override
  List<SpanLink>? get spanLinks => _delegate.spanLinks;

  @override
  DateTime get startTime => _delegate.startTime;

  @override
  SpanStatusCode get status => _delegate.status;

  @override
  String? get statusDescription => _delegate.statusDescription;

  @override
  void updateName(String name) {
    _delegate.updateName(name);

    final provider = _sdkTracer.provider;
    for (final processor in provider.spanProcessors) {
      processor.onNameUpdate(this, name);
    }
  }


  @override
  InstrumentationScope get instrumentationScope => _delegate.instrumentationScope;
  
  @override
  SpanContext? get parentSpanContext => _delegate.parentSpanContext;


  @override
  String toString() {
    final indent = '  ';
    final buffer = StringBuffer()
      ..writeln('Span {')
      ..writeln('$indent name: $name,')
      ..writeln('$indent spanContext: $spanContext,')
      ..writeln('$indent kind: $kind,')
      ..writeln('$indent parentSpan: ${parentSpan?.spanContext ?? "none"},')
      ..writeln('$indent instrumentationScope: $instrumentationScope,')
      ..writeln('$indent startTime: $startTime,')
      ..writeln('$indent endTime: $endTime,')
      ..writeln('$indent status: $status,')
      ..writeln('$indent statusDescription: $statusDescription,')
      ..writeln('$indent attributes: $attributes,');

    // Span Events
    if (spanEvents?.isNotEmpty ?? false) {
      buffer.writeln('$indent spanEvents: [');
      for (final e in spanEvents!) {
        buffer.writeln('$indent$indent$e,');
      }
      buffer.writeln('$indent ],');
    } else {
      buffer.writeln('$indent spanEvents: [],');
    }

    // Span Links
    if (spanLinks?.isNotEmpty ?? false) {
      buffer.writeln('$indent spanLinks: [');
      for (final l in spanLinks!) {
        buffer.writeln('$indent$indent$l,');
      }
      buffer.writeln('$indent ]');
    } else {
      buffer.writeln('$indent spanLinks: []');
    }

    buffer.writeln('}');
    return buffer.toString();
  }



/// Returns whether this span context is valid
  /// A span context is valid when it has a non-zero traceId and a non-zero spanId.
  @override
  bool get isValid => spanContext.isValid;

  @visibleForTesting
  @override
  // ignore: invalid_use_of_visible_for_testing_member
  Attributes get attributes => _delegate.attributes;

  // This check is always true because the method is part of the interface implementation
  // and the delegate is already an APISpan.
  /// Checks if this object is an instance of the specified type.
  /// 
  /// This method is used for type checking and compatibility with the API Span implementation.
  /// It returns true if the specified type is APISpan or the exact runtime type of this object.
  /// 
  /// @param type The type to check against
  /// @return true if this object is an instance of the specified type, false otherwise
  bool isInstanceOf(Type type) => type == APISpan || runtimeType == type;

  @override
  void addAttributeString(String key, String value) {
    _delegate.addAttributeString(key, value);
  }

  @override
  void addAttributeStringList(String key, List<String> value) {
    _delegate.addAttributeStringList(key, value);
  }

  @override
  void addAttributeBool(String key, bool value) {
    _delegate.addAttributeBool(key, value);
  }

  @override
  void addAttributeBoolList(String key, List<bool> value) {
    _delegate.addAttributeBoolList(key, value);
  }

  @override
  void addAttributeInt(String key, int value) {
    _delegate.addAttributeInt(key, value);
  }

  @override
  void addAttributeIntList(String key, List<int> value) {
    _delegate.addAttributeIntList(key, value);
  }

  @override
  void addAttributeDouble(String key, double value) {
    _delegate.addAttributeDouble(key, value);
  }

  @override
  void addAttributeDoubleList(String key, List<double> value) {
    _delegate.addAttributeDoubleList(key, value);
  }


}
