// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';

import '../../../../proto/opentelemetry_proto_dart.dart' as proto;
import '../../../otel.dart';
import '../../readable_log_record.dart';

/// Transforms internal log record representation to OTLP format.
///
/// This transformer converts SDK log records to the OTLP protocol buffer
/// format for export to OpenTelemetry collectors.
class OtlpLogRecordTransformer {
  /// Convert a list of log records to OTLP ExportLogsServiceRequest.
  ///
  /// @param logRecords The log records to transform
  /// @return The OTLP export request
  static proto.ExportLogsServiceRequest transformLogRecords(
      List<ReadableLogRecord> logRecords) {
    final request = proto.ExportLogsServiceRequest();
    if (logRecords.isEmpty) return request;

    // Group log records by their resource first
    final resourceGroups = <String, List<ReadableLogRecord>>{};

    for (final logRecord in logRecords) {
      final resource = logRecord.resource;
      final key = resource != null
          ? _getResourceServiceName(resource.attributes)
          : 'default-service';
      resourceGroups.putIfAbsent(key, () => []).add(logRecord);
    }

    // Process each resource group
    for (final resourceEntry in resourceGroups.entries) {
      final logList = resourceEntry.value;
      if (logList.isEmpty) continue;

      // Extract resource attributes from the log record's resource
      final resource = logList.first.resource;
      final resourceAttrs = resource?.attributes ?? OTel.createAttributes();

      if (OTelLog.isDebug()) {
        OTelLog.debug('LogRecordTransformer: Extracting resource attributes:');
        resourceAttrs.toList().forEach((attr) {
          if (attr.key == 'tenant_id' || attr.key == 'service.name') {
            OTelLog.debug('  ${attr.key}: ${attr.value}');
          }
        });
      }

      // Create resource
      final protoResource = proto.Resource()
        ..attributes.addAll(_transformAttributeMap(resourceAttrs));

      // Group log records by instrumentation scope
      final scopeGroups = <String, List<ReadableLogRecord>>{};
      for (final log in logList) {
        final scopeKey = _instrumentationKey(log);
        scopeGroups.putIfAbsent(scopeKey, () => []).add(log);
      }

      // Create ResourceLogs
      final resourceLogs = proto.ResourceLogs()..resource = protoResource;

      // Process each instrumentation scope group
      for (final scopeEntry in scopeGroups.entries) {
        final scopeLogList = scopeEntry.value;
        if (scopeLogList.isEmpty) continue;

        // Get instrumentation scope information from the first log record
        final scope = scopeLogList.first.instrumentationScope;
        final otlpScope = proto.InstrumentationScope()..name = scope.name;
        if (scope.version != null) {
          otlpScope.version = scope.version!;
        }
        if (scope.schemaUrl != null) {
          resourceLogs.schemaUrl = scope.schemaUrl!;
        }

        // Transform all log records in this scope to OTLP format
        final otlpLogRecords = <proto.LogRecord>[];
        for (final logRecord in scopeLogList) {
          otlpLogRecords.add(_transformLogRecord(logRecord));
        }

        // Create ScopeLogs
        final otlpScopeLogs = proto.ScopeLogs()
          ..scope = otlpScope
          ..logRecords.addAll(otlpLogRecords);

        resourceLogs.scopeLogs.add(otlpScopeLogs);
      }

      request.resourceLogs.add(resourceLogs);
    }

    return request;
  }

  /// Get service name from resource attributes.
  static String _getResourceServiceName(Attributes attributes) {
    for (final attr in attributes.toList()) {
      if (attr.key == 'service.name') {
        return attr.value.toString();
      }
    }
    return 'default-service';
  }

  /// Creates a key for grouping log records by instrumentation scope.
  static String _instrumentationKey(ReadableLogRecord logRecord) {
    final scope = logRecord.instrumentationScope;
    return '${scope.name}:${scope.version ?? ''}';
  }

  /// Convert a single log record to OTLP LogRecord.
  static proto.LogRecord _transformLogRecord(ReadableLogRecord logRecord) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('LogRecordTransformer: Transforming log record');
    }

    final otlpLog = proto.LogRecord();

    // Set timestamps
    if (logRecord.timestamp != null) {
      otlpLog.timeUnixNano = logRecord.timestamp!;
    }
    if (logRecord.observedTimestamp != null) {
      otlpLog.observedTimeUnixNano = logRecord.observedTimestamp!;
    }

    // Set severity
    if (logRecord.severityNumber != null) {
      otlpLog.severityNumber = _transformSeverity(logRecord.severityNumber!);
    }
    if (logRecord.severityText != null) {
      otlpLog.severityText = logRecord.severityText!;
    }

    // Set body
    if (logRecord.body != null) {
      otlpLog.body = _transformBody(logRecord.body);
    }

    // Set attributes
    if (logRecord.attributes != null) {
      otlpLog.attributes.addAll(_transformAttributeMap(logRecord.attributes!));
    }

    // Set dropped attributes count
    otlpLog.droppedAttributesCount = logRecord.droppedAttributesCount;

    // Set trace context
    if (logRecord.traceId != null && logRecord.traceId!.isValid) {
      otlpLog.traceId = logRecord.traceId!.bytes;
    }
    if (logRecord.spanId != null && logRecord.spanId!.isValid) {
      otlpLog.spanId = logRecord.spanId!.bytes;
    }
    if (logRecord.traceFlags != null) {
      otlpLog.flags = logRecord.traceFlags!.asByte;
    }

    return otlpLog;
  }

  /// Transform severity to OTLP SeverityNumber.
  static proto.SeverityNumber _transformSeverity(Severity severity) {
    // Map API Severity to proto SeverityNumber
    switch (severity) {
      case Severity.UNSPECIFIED:
        return proto.SeverityNumber.SEVERITY_NUMBER_UNSPECIFIED;
      case Severity.TRACE:
        return proto.SeverityNumber.SEVERITY_NUMBER_TRACE;
      case Severity.TRACE2:
        return proto.SeverityNumber.SEVERITY_NUMBER_TRACE2;
      case Severity.TRACE3:
        return proto.SeverityNumber.SEVERITY_NUMBER_TRACE3;
      case Severity.TRACE4:
        return proto.SeverityNumber.SEVERITY_NUMBER_TRACE4;
      case Severity.DEBUG:
        return proto.SeverityNumber.SEVERITY_NUMBER_DEBUG;
      case Severity.DEBUG2:
        return proto.SeverityNumber.SEVERITY_NUMBER_DEBUG2;
      case Severity.DEBUG3:
        return proto.SeverityNumber.SEVERITY_NUMBER_DEBUG3;
      case Severity.DEBUG4:
        return proto.SeverityNumber.SEVERITY_NUMBER_DEBUG4;
      case Severity.INFO:
        return proto.SeverityNumber.SEVERITY_NUMBER_INFO;
      case Severity.INFO2:
        return proto.SeverityNumber.SEVERITY_NUMBER_INFO2;
      case Severity.INFO3:
        return proto.SeverityNumber.SEVERITY_NUMBER_INFO3;
      case Severity.INFO4:
        return proto.SeverityNumber.SEVERITY_NUMBER_INFO4;
      case Severity.WARN:
        return proto.SeverityNumber.SEVERITY_NUMBER_WARN;
      case Severity.WARN2:
        return proto.SeverityNumber.SEVERITY_NUMBER_WARN2;
      case Severity.WARN3:
        return proto.SeverityNumber.SEVERITY_NUMBER_WARN3;
      case Severity.WARN4:
        return proto.SeverityNumber.SEVERITY_NUMBER_WARN4;
      case Severity.ERROR:
        return proto.SeverityNumber.SEVERITY_NUMBER_ERROR;
      case Severity.ERROR2:
        return proto.SeverityNumber.SEVERITY_NUMBER_ERROR2;
      case Severity.ERROR3:
        return proto.SeverityNumber.SEVERITY_NUMBER_ERROR3;
      case Severity.ERROR4:
        return proto.SeverityNumber.SEVERITY_NUMBER_ERROR4;
      case Severity.FATAL:
        return proto.SeverityNumber.SEVERITY_NUMBER_FATAL;
      case Severity.FATAL2:
        return proto.SeverityNumber.SEVERITY_NUMBER_FATAL2;
      case Severity.FATAL3:
        return proto.SeverityNumber.SEVERITY_NUMBER_FATAL3;
      case Severity.FATAL4:
        return proto.SeverityNumber.SEVERITY_NUMBER_FATAL4;
    }
  }

  /// Transform body to OTLP AnyValue.
  static proto.AnyValue _transformBody(dynamic body) {
    final anyValue = proto.AnyValue();

    if (body == null) {
      return anyValue;
    } else if (body is String) {
      anyValue.stringValue = body;
    } else if (body is bool) {
      anyValue.boolValue = body;
    } else if (body is int) {
      anyValue.intValue = Int64(body);
    } else if (body is double) {
      anyValue.doubleValue = body;
    } else if (body is List) {
      final arrayValue = proto.ArrayValue();
      for (final item in body) {
        arrayValue.values.add(_transformBody(item));
      }
      anyValue.arrayValue = arrayValue;
    } else if (body is Map) {
      final kvList = proto.KeyValueList();
      body.forEach((key, value) {
        kvList.values.add(proto.KeyValue()
          ..key = key.toString()
          ..value = _transformBody(value));
      });
      anyValue.kvlistValue = kvList;
    } else {
      // For any other type, convert to string
      anyValue.stringValue = body.toString();
    }

    return anyValue;
  }

  /// Convert attribute map to OTLP KeyValue list.
  static List<proto.KeyValue> _transformAttributeMap(Attributes attributes) {
    final result = <proto.KeyValue>[];

    attributes.toList().forEach((attr) {
      final keyValue = proto.KeyValue()
        ..key = attr.key
        ..value = _transformAttributeValue(attr);

      result.add(keyValue);
    });

    return result;
  }

  /// Convert AttributeValue to OTLP AnyValue.
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
