// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';

import '../../../../proto/opentelemetry_proto_dart.dart' as proto;
import '../../../otel.dart';
import '../../span.dart';

/// Transforms internal span representation to OTLP format
class OtlpSpanTransformer {
  /// Convert a list of spans to OTLP ExportTraceServiceRequest
  static proto.ExportTraceServiceRequest transformSpans(List<Span> spans) {
    final exportTraceServiceRequest = proto.ExportTraceServiceRequest();
    if (spans.isEmpty) return exportTraceServiceRequest;

    // Group spans by their resource first
    final resourceGroups = <String, List<Span>>{};

    for (final span in spans) {
      final resource = span.resource;
      final key = resource != null
          ? _getResourceServiceName(resource.attributes)
          : 'default-service';
      resourceGroups.putIfAbsent(key, () => []).add(span);
    }

    // Process each resource group
    for (final resourceEntry in resourceGroups.entries) {
      final spanList = resourceEntry.value;
      if (spanList.isEmpty) continue;

      // Extract resource attributes from the span's resource
      final resource = spanList.first.resource;
      final resourceAttrs = resource?.attributes ?? OTel.createAttributes();

      if (OTelLog.isDebug()) {
        OTelLog.debug('Extracting resource attributes for export:');
        resourceAttrs.toList().forEach((attr) {
          if (attr.key == 'tenant_id' || attr.key == 'service.name') {
            OTelLog.debug('  ${attr.key}: ${attr.value}');
          }
        });
      }

      if (OTelLog.isDebug()) {
        OTelLog.debug('Extracting resource attributes for export:');
        resourceAttrs.toList().forEach((attr) {
          if (attr.key == 'tenant_id' || attr.key == 'service.name') {
            OTelLog.debug('  ${attr.key}: ${attr.value}');
          }
        });
      }

      // Create resource
      final protoResource = proto.Resource()
        ..attributes.addAll(transformAttributeMap(resourceAttrs));

      // Group spans by instrumentation scope
      final scopeGroups = <String, List<Span>>{};
      for (final span in spanList) {
        final scopeKey = _instrumentationKey(span);
        scopeGroups.putIfAbsent(scopeKey, () => []).add(span);
      }

      // Create ResourceSpans
      final resourceSpan = proto.ResourceSpans()..resource = protoResource;

      // Process each instrumentation scope group
      for (final scopeEntry in scopeGroups.entries) {
        final scopeSpanList = scopeEntry.value;
        if (scopeSpanList.isEmpty) continue;

        // Get instrumentation scope information from the first span
        final scope = scopeSpanList.first.instrumentationScope;
        final otlpScope = proto.InstrumentationScope()..name = scope.name;
        if (scope.version != null) {
          otlpScope.version = scope.version!;
        }

        // Transform all spans in this scope to OTLP format
        final otlpSpans = <proto.Span>[];
        for (final span in scopeSpanList) {
          otlpSpans.add(transformSpan(span));
        }

        // Create ScopeSpans
        final otlpScopeSpans = proto.ScopeSpans()
          ..scope = otlpScope
          ..spans.addAll(otlpSpans);

        resourceSpan.scopeSpans.add(otlpScopeSpans);
      }

      exportTraceServiceRequest.resourceSpans.add(resourceSpan);
    }

    return exportTraceServiceRequest;
  }

  /// Get service name from resource attributes
  static String _getResourceServiceName(Attributes attributes) {
    for (final attr in attributes.toList()) {
      if (attr.key == 'service.name') {
        return attr.value.toString();
      }
    }
    return 'default-service';
  }

  /// Creates a key for grouping spans by instrumentation scope
  static String _instrumentationKey(Span span) {
    final scope = span.instrumentationScope;
    return '${scope.name}:${scope.version ?? ''}';
  }

  /// Convert a single span to OTLP Span
  static proto.Span transformSpan(Span span) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Transforming span: ${span.name}');
    }
    final context = span.spanContext;

    final otlpSpan = proto.Span()
      ..traceId = context.traceId.bytes
      ..spanId = context.spanId.bytes
      ..name = span.name
      ..kind = transformSpanKind(span.kind)
      ..startTimeUnixNano = Int64(span.startTime.microsecondsSinceEpoch * 1000);

    if (span.endTime != null) {
      otlpSpan.endTimeUnixNano =
          Int64(span.endTime!.microsecondsSinceEpoch * 1000);
    }

    // First check if we have a parent span
    final parentSpan = span.parentSpan;
    if (parentSpan != null && parentSpan.spanContext.isValid) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Setting parentSpanId from parentSpan for ${span.name}');
      }
      otlpSpan.parentSpanId = parentSpan.spanContext.spanId.bytes;
    }
    // If we don't have a parent span but have a parent span ID in our context
    else if (context.parentSpanId != null && context.parentSpanId!.isValid) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Setting parentSpanId from context for ${span.name}');
      }
      otlpSpan.parentSpanId = context.parentSpanId!.bytes;
    }

    // Add attributes
    final attrs = span.attributes;
    otlpSpan.attributes.addAll(transformAttributeMap(attrs));

    // Add events
    final events = span.spanEvents;
    if (events != null && events.isNotEmpty) {
      otlpSpan.events.addAll(transformEvents(events));
    }

    // Add links
    final links = span.spanLinks;
    if (links != null && links.isNotEmpty) {
      otlpSpan.links.addAll(transformLinks(links));
    }

    // Add status
    final status = span.status;
    otlpSpan.status = transformStatus(status, span.statusDescription);

    return otlpSpan;
  }

  /// Convert span status to OTLP Status
  static proto.Status transformStatus(
      SpanStatusCode status, String? description) {
    final otlpStatus = proto.Status();

    switch (status) {
      case SpanStatusCode.Ok:
        otlpStatus.code = proto.Status_StatusCode.STATUS_CODE_OK;
        break;
      case SpanStatusCode.Error:
        otlpStatus.code = proto.Status_StatusCode.STATUS_CODE_ERROR;
        // TODO The OTel spec requires the description for error statuses
        if (description != null) {
          otlpStatus.message = description;
        }
        break;
      case SpanStatusCode.Unset:
        otlpStatus.code = proto.Status_StatusCode.STATUS_CODE_UNSET;
        break;
    }

    return otlpStatus;
  }

  /// Convert span kind to OTLP SpanKind
  static proto.Span_SpanKind transformSpanKind(SpanKind kind) {
    switch (kind) {
      case SpanKind.internal:
        return proto.Span_SpanKind.SPAN_KIND_INTERNAL;
      case SpanKind.server:
        return proto.Span_SpanKind.SPAN_KIND_SERVER;
      case SpanKind.client:
        return proto.Span_SpanKind.SPAN_KIND_CLIENT;
      case SpanKind.producer:
        return proto.Span_SpanKind.SPAN_KIND_PRODUCER;
      case SpanKind.consumer:
        return proto.Span_SpanKind.SPAN_KIND_CONSUMER;
    }
  }

  /// Convert events to OTLP Event list
  static List<proto.Span_Event> transformEvents(List<SpanEvent> events) {
    return events.map((event) {
      final spanEvent = proto.Span_Event()
        ..timeUnixNano = Int64(event.timestamp.microsecondsSinceEpoch * 1000)
        ..name = event.name;

      if (event.attributes != null) {
        spanEvent.attributes.addAll(transformAttributeMap(event.attributes!));
      }

      return spanEvent;
    }).toList();
  }

  /// Convert links to OTLP Link list
  static List<proto.Span_Link> transformLinks(List<dynamic> links) {
    return links.map((link) {
      final spanLink = proto.Span_Link();

      if (link is SpanLink) {
        final spanContext = link.spanContext;
        spanLink
          ..traceId = spanContext.traceId.bytes
          ..spanId = spanContext.spanId.bytes;

        spanLink.attributes.addAll(transformAttributeMap(link.attributes));
      }

      return spanLink;
    }).toList();
  }

  /// Convert attribute map to OTLP KeyValue list
  static List<proto.KeyValue> transformAttributeMap(Attributes attributes) {
    final result = <proto.KeyValue>[];

    attributes.toList().forEach((attr) {
      final keyValue = proto.KeyValue()
        ..key = attr.key
        ..value = _transformAttributeValue(attr);

      result.add(keyValue);
    });

    return result;
  }

  /// Convert AttributeValue to OTLP AnyValue
  static proto.AnyValue _transformAttributeValue(Attribute attr) {
    final anyValue = proto.AnyValue();

    if (attr.value is String) {
      anyValue.stringValue = attr.value as String;
    } else if (attr.value is bool) {
      anyValue.boolValue = attr.value as bool;
    } else if (attr.value is int) {
      anyValue.intValue = Int64(attr.value as int);
    } else if (attr.value is double) {
      anyValue.doubleValue = attr.value as double;
    } else if (attr.value is List<String>) {
      final arrayValue = proto.ArrayValue();
      arrayValue.values.addAll((attr.value as List<String>)
          .map((v) => proto.AnyValue()..stringValue = v));
      anyValue.arrayValue = arrayValue;
    } else if (attr.value is List<bool>) {
      final arrayValue = proto.ArrayValue();
      arrayValue.values.addAll((attr.value as List<bool>)
          .map((v) => proto.AnyValue()..boolValue = v));
      anyValue.arrayValue = arrayValue;
    } else if (attr.value is List<int>) {
      final arrayValue = proto.ArrayValue();
      arrayValue.values.addAll((attr.value as List<int>)
          .map((v) => proto.AnyValue()..intValue = Int64(v)));
      anyValue.arrayValue = arrayValue;
    } else if (attr.value is List<double>) {
      final arrayValue = proto.ArrayValue();
      arrayValue.values.addAll((attr.value as List<double>)
          .map((v) => proto.AnyValue()..doubleValue = v));
      anyValue.arrayValue = arrayValue;
    } else {
      // For any other type, convert to string
      anyValue.stringValue = attr.value.toString();
    }

    return anyValue;
  }
}
