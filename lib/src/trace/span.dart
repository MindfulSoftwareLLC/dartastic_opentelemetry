// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:meta/meta.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

import '../resource/resource.dart';
import '../util/otel_log.dart';
import 'tracer.dart';

part 'span_create.dart';

class Span implements APISpan {
  final APISpan _delegate;
  final Tracer _sdkTracer;

  Span._(APISpan delegate, Tracer sdkTracer)
      : _delegate = delegate,
        _sdkTracer = sdkTracer {
    if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Created new span with name ${delegate.name}');
  }

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

      // Verify the provider type
      final provider = _sdkTracer.provider;
      if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Provider type is ${provider.runtimeType}');

      if (provider is TracerProvider) {
        final processors = provider.spanProcessors;
        if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Found ${processors.length} processors');

        for (final processor in processors) {
          if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Notifying processor ${processor.runtimeType} of span end');
          processor.onEnd(this);
        }
      } else {
        if (OTelLog.isDebug()) OTelLog.debug('SDKSpan: Provider is not SDKTracerProvider, it is ${provider.runtimeType}');
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
  void setStringAttribute<T>(String name, String value) => _delegate.setStringAttribute(name, value);

  @override
  void setStringListAttribute<T>(String name, List<String> value) => _delegate.setStringListAttribute(name, value);

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
    if (provider is TracerProvider) {
      for (final processor in provider.spanProcessors) {
        processor.onNameUpdate(this, name);
      }
    }
  }


  @override
  InstrumentationScope get instrumentationScope => _delegate.instrumentationScope;
  
  @override
  SpanContext? get parentSpanContext => _delegate.parentSpanContext;


  @override
  String toString() {
    return  _delegate.toString();
  }

  /// Returns whether this span context is valid
  /// A span context is valid when it has a non-zero traceId and a non-zero spanId.
  @override
  bool get isValid => spanContext.isValid;

  @visibleForTesting
  @override
  // ignore: invalid_use_of_visible_for_testing_member
  Attributes get attributes => _delegate.attributes;

}
