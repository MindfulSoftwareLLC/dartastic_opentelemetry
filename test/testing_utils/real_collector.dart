// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/src/util/otel_log.dart';

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
    // Verify the binary exists and has execute permissions
    final collectorFile = File(execPath);
    if (!collectorFile.existsSync()) {
      throw StateError(
          'OpenTelemetry Collector not found at $execPath');
    }

    // Make sure it's executable
    try {
      final stat = await collectorFile.stat();
      if (!stat.modeString().contains('x')) {
        print('Fixing collector permissions...');
        // Add execute permission
        await Process.run('chmod', ['+x', execPath]);
      }
    } catch (e) {
      print('Error checking collector permissions: $e');
    }

    // Start collector with our config
    try {
      print('Starting collector with config: $_configPath');
      _process = await Process.start(
        execPath,
        ['--config', _configPath],
      );
      print('Collector started with process ID: ${_process!.pid}');
    } catch (e) {
      print('Error starting collector: $e');
      rethrow;
    }

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

    // Wait for collector to start and verify it's running
    bool started = false;
    for (int i = 0; i < 10; i++) {
      await Future.delayed(Duration(milliseconds: 300));
      try {
        // Check if process is still running
        if (_process != null && _process!.pid > 0) {
          started = true;
          break;
        }
      } catch (e) {
        print('Error checking collector process: $e');
      }
    }

    if (!started) {
      throw StateError('Failed to start collector properly');
    }

    print('Collector started successfully');
    await Future.delayed(Duration(seconds: 1));
  }

  /// Stop the collector
  Future<void> stop() async {
    if (_process != null) {
      try {
        // Send SIGTERM for graceful shutdown
        _process!.kill(ProcessSignal.sigterm);
        // Wait for a short time to allow graceful shutdown
        try {
        await Future.delayed(Duration(seconds: 2));
        } catch (e) {
        // Ignore, just continue with force kill
        }

        // Force kill if still running
        if (_process != null) {
        try {
          _process!.kill(ProcessSignal.sigkill);
        } catch (e) {
          // Ignore, just continue
        }
      }
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
    final deadline = DateTime.now().add(timeout ?? Duration(seconds: 10));
    var attempts = 0;

    while (DateTime.now().isBefore(deadline)) {
      attempts++;
      final spans = await getSpans();
      print('waitForSpans attempt $attempts: found ${spans.length} spans');

      if (spans.length >= count) {
        print('waitForSpans: found required $count spans');
        return;
      }

      // Check if file exists and has content
      final exists = await File(_outputPath).exists();
      if (!exists) {
        print('Output file does not exist');
        // Create empty file
        await File(_outputPath).writeAsString('');
      } else {
        final size = await File(_outputPath).length();
        print('Output file size: $size bytes');

        // If file exists but is empty after multiple attempts, it might be an issue with collector
        if (size == 0 && attempts > 5) {
          print('Output file is empty after multiple attempts, checking collector status...');
          // Check if collector is still running
          bool isRunning = _process != null;
          if (isRunning) {
            try {
              // On Dart, we can't check process status directly, so we'll try a no-op signal
              final exitCode = _process!.pid;
              if (exitCode == 0) isRunning = false;
            } catch (e) {
              // If we get an exception, process is likely dead
              isRunning = false;
            }
          }

          if (!isRunning) {
            print('Collector process is not running, restarting...');
            try {
              await start();
              // Allow collector to initialize
              await Future.delayed(Duration(seconds: 2));
            } catch (e) {
              print('Failed to restart collector: $e');
            }
          }
        }
      }

      // Gradually increase delay between attempts
      final delayMs = 100 * (1 << (attempts ~/ 3).clamp(0, 6)); // Max ~6.4 seconds between attempts
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    // Final attempt to read spans
    final spans = await getSpans();
    throw TimeoutException(
      'Timed out waiting for $count spans. '
      'Found ${spans.length} spans: ${spans.map((s) => s['name']).toList()}');
  }

  /// Assert that a span matching the given criteria exists
  Future<void> assertSpanExists({
    String? name,
    Map<String, dynamic>? attributes,
    String? traceId,
    String? spanId,
  }) async {
    final spans = await getSpans();

    if (OTelLog.isDebug()) {
      OTelLog.debug('Looking for a span with name: $name');
      for (var span in spans) {
        OTelLog.debug(
            'Found span: ${span['name']}, spanId: ${span['spanId']}, traceId: ${span['traceId']}');
      }
    }

    final matching = spans.where((span) {
      if (name != null && span['name'] != name) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'Span ${span['spanId']} has name "${span['name']}" which doesn\'t match expected "$name"');
        }
        return false;
      }
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
      // If there's exactly one span and a name mismatch, suggest the correct name
      if (spans.length == 1 && name != null) {
        final actualName = spans.first['name'];
        throw StateError(
            // ignore: prefer_adjacent_string_concatenation
            'No matching span found with name "$name". Found span named "$actualName" instead. ' +
            'Consider updating the test to use the correct span name.');
      }

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
