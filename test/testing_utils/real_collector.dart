// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Manages a real OpenTelemetry Collector instance for testing
class RealCollector {
  final int port;
  Process? _process;
  final String _outputPath;
  final String _configPath;

  RealCollector({
    this.port = 4316,  // Use non-standard port by default
    required String configPath,
    required String outputPath,
  }) : _configPath = configPath,
       _outputPath = outputPath;

  /// Start the collector
  Future<void> start() async {
    final execPath = '${Directory.current.path}/test/testing_utils/otelcol';
    if (!File(execPath).existsSync()) {
      throw StateError(
          'OpenTelemetry Collector not found at $execPath');
    }

    // Start collector with our config
    _process = await Process.start(
      execPath,
      ['--config', _configPath],
    );

    // Listen for output/errors for debugging
    _process!.stdout.transform(utf8.decoder).listen((line) {
      print('Collector stdout: $line');
      if (line.contains('invalid configuration')) {
        throw Exception('Collector config error: $line');
      }
    });
    _process!.stderr.transform(utf8.decoder).listen((line) {
      print('Collector stderr: $line');
    });

    // Wait a bit for collector to start
    await Future.delayed(Duration(seconds: 1));
  }

  /// Stop the collector
  Future<void> stop() async {
    if (_process != null) {
      try {
        // Send SIGTERM for graceful shutdown
        _process!.kill(ProcessSignal.sigterm);
        // Wait for process to exit
        await _process!.exitCode.timeout(
          Duration(seconds: 5),
          onTimeout: () {
            // Force kill if it doesn't exit gracefully
            _process!.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      } catch (e) {
        print('Error stopping collector: $e');
      } finally {
        _process = null;
      }
    }
  }

  /// Get all spans from the exported data
  Future<List<Map<String, dynamic>>> getSpans() async {
    if (!File(_outputPath).existsSync()) {
      return [];
    }

    final content = await File(_outputPath).readAsString();
    final lines = content.split('\n').where((l) => l.isNotEmpty);
    
    // Parse each line and extract spans
    final allSpans = <Map<String, dynamic>>[];
    for (final line in lines) {
      final data = json.decode(line) as Map<String, dynamic>;
      // Extract spans from OTLP format
      if (data.containsKey('resourceSpans')) {
        for (final resourceSpan in data['resourceSpans'] as List) {
          final resource = resourceSpan['resource'] as Map<String, dynamic>?;
          final resourceAttrs = _parseAttributes(resource?['attributes'] as List?);

          for (final scopeSpans in resourceSpan['scopeSpans'] as List) {
            for (final span in scopeSpans['spans'] as List) {
              // Add resource attributes to each span
              span['resourceAttributes'] = resourceAttrs;
              allSpans.add(span as Map<String, dynamic>);
            }
          }
        }
      }
    }
    return allSpans;
  }

  /// Parse OTLP attribute format into simple key-value pairs
  Map<String, dynamic> _parseAttributes(List? attrs) {
    if (attrs == null) return {};
    final result = <String, dynamic>{};
    for (final attr in attrs) {
      final key = attr['key'] as String;
      final value = attr['value'] as Map<String, dynamic>;
      // Handle different value types
      if (value.containsKey('stringValue')) {
        result[key] = value['stringValue'];
      } else if (value.containsKey('intValue')) {
        result[key] = value['intValue'];
      } else if (value.containsKey('doubleValue')) {
        result[key] = value['doubleValue'];
      } else if (value.containsKey('boolValue')) {
        result[key] = value['boolValue'];
      }
    }
    return result;
  }

  /// Clear all exported spans
  Future<void> clear() async {
    if (File(_outputPath).existsSync()) {
      await File(_outputPath).writeAsString('');
    }
  }

  /// Wait for a certain number of spans to be exported
  Future<void> waitForSpans(int count, {Duration? timeout}) async {
    final deadline = DateTime.now().add(timeout ?? Duration(seconds: 5));
    var attempts = 0;
    
    while (DateTime.now().isBefore(deadline)) {
      attempts++;
      final spans = await getSpans();
      print('waitForSpans attempt $attempts: found ${spans.length} spans');
      
      if (spans.length >= count) {
        return;
      }
      
      // Check if file exists and has content
      final exists = await File(_outputPath).exists();
      if (!exists) {
        print('Output file does not exist');
      } else {
        final size = await File(_outputPath).length();
        print('Output file size: $size bytes');
      }
      
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Final attempt to read spans
    final spans = await getSpans();
    throw TimeoutException(
      'Timed out waiting for $count spans. ' 
      'Found ${spans.length} spans: ${json.encode(spans)}');
  }

  /// Assert that a span matching the given criteria exists
  Future<void> assertSpanExists({
    String? name,
    Map<String, dynamic>? attributes,
    String? traceId,
    String? spanId,
  }) async {
    final spans = await getSpans();
    
    final matching = spans.where((span) {
      if (name != null && span['name'] != name) return false;
      if (traceId != null && span['traceId'] != traceId) return false;
      if (spanId != null && span['spanId'] != spanId) return false;
      
      if (attributes != null) {
        // Check both span attributes and resource attributes
        final spanAttrs = _parseAttributes(span['attributes'] as List?);
        final resourceAttrs = span['resourceAttributes'] as Map<String, dynamic>?;
        final allAttrs = {...?resourceAttrs, ...spanAttrs};
        
        for (final entry in attributes.entries) {
          if (allAttrs[entry.key] != entry.value) {
            print('Attribute mismatch for ${entry.key}: expected ${entry.value}, got ${allAttrs[entry.key]}');
            return false;
          }
        }
      }
      
      return true;
    }).toList();

    if (matching.isEmpty) {
      final criteria = <String, dynamic>{
        if (name != null) 'name': name,
        if (attributes != null) 'attributes': attributes,
        if (traceId != null) 'traceId': traceId,
        if (spanId != null) 'spanId': spanId,
      };
      throw StateError(
          'No matching span found.\nCriteria: ${json.encode(criteria)}\nAll spans: ${json.encode(spans)}');
    }
  }
}