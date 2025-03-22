// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pbgrpc.dart';
import 'package:dartastic_opentelemetry/proto/common/v1/common.pb.dart' as common;
import 'package:dartastic_opentelemetry/proto/resource/v1/resource.pb.dart' as resource;
import 'package:dartastic_opentelemetry/proto/trace/v1/trace.pb.dart' as proto;
import 'package:synchronized/synchronized.dart';
import 'package:test/test.dart';

import 'mock_collector_behavior.dart';

/// A mock implementation of the trace service for testing
class _MockTraceService extends TraceServiceBase {
  final List<proto.ResourceSpans> _spans;
  final MockCollectorBehavior? _behavior;
  final MockCollector _collector;

  _MockTraceService(this._spans, this._behavior, this._collector);

  @override
  Future<ExportTraceServiceResponse> export(
  grpc.ServiceCall call, ExportTraceServiceRequest request) async {
  // Apply configured delay if present
  if (_behavior?.artificialDelay != null) {
  await Future.delayed(_behavior!.artificialDelay!);
  }

  _collector._incrementAttempts();

  // Print all received spans for debugging
  print('\nReceived spans in _MockTraceService:');
  for (var rs in request.resourceSpans) {
  for (var ss in rs.scopeSpans) {
  for (var span in ss.spans) {
  print(' - ${span.name} with spanId ${_collector._bytesToHex(span.spanId)}');
  }
  }
  }

  // Apply configured behavior if present
  if (_behavior != null) {
  // Get the original span name without modification
  final span = request.resourceSpans.first.scopeSpans.first.spans.first;
  if (_behavior!.shouldFail(span.name)) {
  print('Triggering failure for span: ${span.name}');
  throw grpc.GrpcError.custom(
  _behavior!.failureType,
  _behavior!.failureType.toString(),
  );
  }
  }

  // Add spans to collector's list and return
  print('Received export request with ${request.resourceSpans.length} ResourceSpans');
  // Add spans to collector's list
  await _collector._spanLock.synchronized(() async {
  _collector._spans.addAll(request.resourceSpans);
  });
  _collector.printCurrentSpans();  // Use collector's method instead
  print('Successfully exported spans');
  return ExportTraceServiceResponse();
  }
}

/// A mock OpenTelemetry collector for testing that can validate received spans
class MockCollector {
  final int port;
  final _spans = <proto.ResourceSpans>[];
  final _spanLock = Lock();
  grpc.Server? _server;
  _MockTraceService? _service;
  Completer<void> _readyCompleter = Completer<void>();
  bool _isStopped = false;
  MockCollectorBehavior? behavior;
  int _exportAttempts = 0;
  Completer<void> _statusCompleter = Completer<void>();

  MockCollector({
    this.port = 4317,
    this.behavior,
  });

  int get totalRequests => _exportAttempts;

  void _incrementAttempts() {
    _exportAttempts++;
  }

  void printCurrentSpans() {
    print('\nCurrent spans in collector:');
    for (var rs in _spans) {
      print('ResourceSpan:');
      if (rs.hasResource()) {
        print('  Resource attributes:');
        for (var attr in rs.resource.attributes) {
          print('    ${attr.key}: ${attr.value}');
        }
      }
      for (var ss in rs.scopeSpans) {
        for (var span in ss.spans) {
          print('  Span: ${span.name}');
          print('    ID: ${_bytesToHex(span.spanId)}');
          print('    Trace: ${_bytesToHex(span.traceId)}');
        }
      }
    }
  }

  /// Start the collector server
  Future<void> start() async {
    if (_server != null || _service != null) {
      await stop();
    }
    _isStopped = false;
    _service = _MockTraceService(_spans, behavior, this);
    _server = grpc.Server.create(
      services: [_service!],
      codecRegistry: grpc.CodecRegistry(codecs: [grpc.GzipCodec()]),
    );
    await _server!.serve(port: port, shared: true);
    print('Mock collector listening on port $port');
    _readyCompleter.complete();
  }

  /// Stop the collector server
  Future<void> stop() async {
    await Future.delayed(Duration(milliseconds: 100));
    _isStopped = true;
    await _server?.shutdown();
    _server = null;
    _service = null;
    _readyCompleter = Completer<void>();
    _statusCompleter = Completer<void>();
    await Future.delayed(Duration(milliseconds: 100));
  }

  /// Get the count of received spans
  Future<int> get spanCount async {
    return await _spanLock.synchronized(() async {
      return _spans.fold<int>(
          0, (count, resourceSpans) => count + _countSpans(resourceSpans));
    });
  }

  int _countSpans(proto.ResourceSpans resourceSpans) {
    return resourceSpans.scopeSpans
        .fold<int>(0, (count, scope) => count + scope.spans.length);
  }

  /// Wait for a specified number of spans to be received
  Future<void> waitForSpans(int expectedCount,
  {Duration timeout = const Duration(seconds: 5)}) async {
  // Wait for server to be ready
  await _readyCompleter.future;

  final deadline = DateTime.now().add(timeout);
  print('\nMockCollector: Waiting for $expectedCount spans (timeout: ${timeout.inSeconds}s)');

  int lastCount = 0;
  while (DateTime.now().isBefore(deadline) && !_isStopped) {
  final current = await spanCount;
  if (current != lastCount) {
  print('MockCollector: Current span count: $current/$expectedCount');
  await _spanLock.synchronized(() {
    printCurrentSpans();  // Print spans whenever count changes
    });
    lastCount = current;
  }

  if (current >= expectedCount) {
  print('MockCollector: Received expected number of spans');
  // Add a small delay to ensure all spans are processed
    await Future.delayed(const Duration(milliseconds: 100));
    return;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }

  final currentCount = await spanCount;
    print('MockCollector: Timeout reached. Current span count: $currentCount/$expectedCount');
    throw TimeoutException(
        'Timed out waiting for $expectedCount spans. Only received $currentCount');
  }

  /// Assert that a span with the given criteria exists
  Future<void> assertSpanExists({
    bool requireExactMatch = false,
    String? name,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    Map<String, dynamic>? attributes,
    Map<String, String>? resourceAttributes,
    proto.Status_StatusCode? status,
    String? statusMessage,
  }) async {
    print('\nLooking for span with criteria:');
    if (name != null) print('  name: $name');
    if (traceId != null) print('  traceId: $traceId');
    if (spanId != null) print('  spanId: $spanId');
    if (parentSpanId != null) print('  parentSpanId: $parentSpanId');
    if (attributes != null) print('  attributes: $attributes');
    if (resourceAttributes != null) {
      print('  resourceAttributes: $resourceAttributes');
    }
    if (status != null) print('  status: $status');
    if (statusMessage != null) print('  statusMessage: $statusMessage');

    await _spanLock.synchronized(() async {
      print('\nCurrent spans in collector:');
      for (var rs in _spans) {
        print('ResourceSpan:');
        for (var ss in rs.scopeSpans) {
          for (var span in ss.spans) {
            print('  Span: ${span.name}');
            print('    traceId: ${_bytesToHex(span.traceId)}');
            print('    spanId: ${_bytesToHex(span.spanId)}');
            if (span.parentSpanId.isNotEmpty) {
              print('    parentSpanId: ${_bytesToHex(span.parentSpanId)}');
            }
            if (span.attributes.isNotEmpty) {
              print('    attributes:');
              for (var attr in span.attributes) {
                print('      ${attr.key}: ${_getAttributeValue(attr.value)}');
              }
            }
            if (span.hasStatus()) {
              print('    status: ${span.status.code}');
              if (span.status.hasMessage()) {
                print('    statusMessage: ${span.status.message}');
              }
            }
          }
        }
      }

      final matchingSpans = _spans.where((resourceSpans) {
        if (resourceAttributes != null && resourceSpans.hasResource()) {
          if (!_matchResourceAttributes(
              resourceSpans.resource, resourceAttributes)) {
            return false;
          }
        }

        return resourceSpans.scopeSpans.any((scopeSpans) => scopeSpans.spans.any(
            (span) => _matchSpan(span,
                requireExactMatch: requireExactMatch,
                name: name,
                traceId: traceId,
                spanId: spanId,
                parentSpanId: parentSpanId,
                attributes: attributes,
                status: status,
                statusMessage: statusMessage)));
      }).toList();

      expect(matchingSpans, isNotEmpty,
          reason: 'No span found matching the specified criteria');
    });
  }

  /// Reset the collector's state
  Future<void> clear() async {
    await _spanLock.synchronized(() {
      _spans.clear();
    });
    _exportAttempts = 0;
    behavior?.reset();

    // Stop and restart server with fresh state
    await stop();
    await start();
  }

  bool _matchSpan(
    proto.Span span, {
    bool requireExactMatch = false,
    String? name,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    Map<String, dynamic>? attributes,
    proto.Status_StatusCode? status,
    String? statusMessage,
  }) {
    if (name != null) {
      if (requireExactMatch) {
        if (span.name != name) {
          print('Exact name mismatch - expected: "$name", got: "${span.name}"');
          return false;
        }
      } else if (!span.name.contains(name)) {
        print('Name mismatch - expected to contain: "$name", got: "${span.name}"');
        return false;
      }
    }
    if (traceId != null && _bytesToHex(span.traceId) != traceId) return false;
    if (spanId != null && _bytesToHex(span.spanId) != spanId) return false;
    if (parentSpanId != null &&
        _bytesToHex(span.parentSpanId) != parentSpanId) {
      return false;
    }

    if (attributes != null) {
      final spanAttributes = Map<String, dynamic>.fromEntries(
        span.attributes
            .map((kv) => MapEntry(kv.key, _getAttributeValue(kv.value))),
      );

      print('\nMatching attributes:');
      print('  Expected: $attributes');
      print('  Actual: $spanAttributes');

      if (!_matchAttributeValues(spanAttributes, attributes)) {
        return false;
      }
    }

    if (status != null && span.status.code != status) {
      print('Status mismatch: expected $status, got ${span.status.code}');
      return false;
    }

    if (statusMessage != null && span.status.message != statusMessage) {
      print(
          'Status message mismatch: expected $statusMessage, got ${span.status.message}');
      return false;
    }

    return true;
  }

  bool _matchAttributeValues(
      Map<String, dynamic> actual, Map<String, dynamic> expected) {
    for (final entry in expected.entries) {
      if (!actual.containsKey(entry.key)) {
        print('  Failed: Key ${entry.key} not found');
        return false;
      }

      final actualValue = actual[entry.key];
      final expectedValue = entry.value;

      // Handle Int64 values
      if (actualValue is Int64 && expectedValue is num) {
        if (actualValue.toInt() != expectedValue) {
          print('  Failed: Value mismatch for ${entry.key}');
          print('    Expected: $expectedValue (${expectedValue.runtimeType})');
          print('    Actual: $actualValue (${actualValue.runtimeType})');
          return false;
        }
        continue;
      }

      // Handle numeric value comparisons including strings
      if (expectedValue is num) {
        if (actualValue is String) {
          try {
            final actualNum = num.parse(actualValue);
            if (actualNum == expectedValue) {
              continue;
            }
          } catch (_) {}
        } else if (actualValue is num && actualValue.toDouble() == expectedValue.toDouble()) {
          continue;
        }
      }

      if (actualValue.toString() != expectedValue.toString()) {
        print('  Failed: Value mismatch for ${entry.key}');
        print('    Expected: $expectedValue (${expectedValue.runtimeType})');
        print('    Actual: $actualValue (${actualValue.runtimeType})');
        return false;
      }
    }
    print('  All attributes matched');
    return true;
  }

  bool _matchResourceAttributes(
      resource.Resource resource, Map<String, String> expected) {
    final actualAttributes = Map<String, String>.fromEntries(
      resource.attributes
          .where((kv) => kv.value.hasStringValue())
          .map((kv) => MapEntry(kv.key, kv.value.stringValue)),
    );

    return expected.entries
        .every((entry) => actualAttributes[entry.key] == entry.value);
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  dynamic _getAttributeValue(common.AnyValue value) {
    if (value.hasStringValue()) return value.stringValue;
    if (value.hasIntValue()) return value.intValue.toInt();
    if (value.hasDoubleValue()) return value.doubleValue;
    if (value.hasBoolValue()) return value.boolValue;
    if (value.hasArrayValue()) {
      return value.arrayValue.values.map(_getAttributeValue).toList();
    }
    return null;
  }
}
