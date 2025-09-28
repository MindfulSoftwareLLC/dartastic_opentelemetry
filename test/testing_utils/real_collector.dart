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

  // Getter for port to allow access from tests
  int get getPort => port;

  RealCollector({
    this.port = 4316, // Use non-standard port by default
    required String configPath,
    required String outputPath,
  })  : _configPath = configPath,
        _outputPath = outputPath;

  /// Start the collector
  Future<void> start() async {
    // First, ensure any existing ports are cleared
    await _killExistingProcesses();

    // Ensure output directory exists
    final outputDir = File(_outputPath).parent;
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }

    // Ensure output file exists and is empty
    // ignore: avoid_slow_async_io
    await File(_outputPath).writeAsString('');

    final execPath = '${Directory.current.path}/test/testing_utils/otelcol';
    // Verify the binary exists and has execute permissions
    final collectorFile = File(execPath);
    if (!collectorFile.existsSync()) {
      throw StateError('OpenTelemetry Collector not found at $execPath');
    }

    // Make sure it's executable
    try {
      final stat = collectorFile.statSync();
      if (!stat.modeString().contains('x')) {
        print('Fixing collector permissions...');
        // Add execute permission
        await Process.run('chmod', ['+x', execPath]);
      }
    } catch (e) {
      print('Error checking collector permissions: $e');
    }

    // Create temporary config file with port substitution
    final tempConfigPath =
        '${Directory.current.path}/test/testing_utils/otelcol-config-$port.yaml';
    final configContent = await File(_configPath).readAsString();
    final updatedConfig =
        configContent.replaceAll('127.0.0.1:4316', '127.0.0.1:$port');
    await File(tempConfigPath).writeAsString(updatedConfig);

    // Start collector with our config
    try {
      print('Starting collector with config: $tempConfigPath');
      _process = await Process.start(
        execPath,
        ['--config', tempConfigPath],
      );
      print('Collector started with process ID: ${_process!.pid}');
    } catch (e) {
      print('Error starting collector: $e');
      File(tempConfigPath).deleteSync();
      rethrow;
    }

    // Create completer to signal when collector is ready
    final readyCompleter = Completer<bool>();
    bool hasServiceStarted = false;

    // Listen for output/errors for debugging
    _process!.stdout.transform(utf8.decoder).listen((line) {
      print('Collector stdout: $line');
      if (line.contains('invalid configuration')) {
        readyCompleter
            .completeError(Exception('Collector config error: $line'));
      }
      if (line.contains('Everything is ready') && !hasServiceStarted) {
        hasServiceStarted = true;
        readyCompleter.complete(true);
      }
    });

    _process!.stderr.transform(utf8.decoder).listen((line) {
      print('Collector stderr: $line');
      if (line.contains('Everything is ready') && !hasServiceStarted) {
        hasServiceStarted = true;
        readyCompleter.complete(true);
      }
    });

    // Wait for collector to be ready or timeout
    bool started = false;
    try {
      started = await readyCompleter.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Timed out waiting for collector to be ready: $e');
      // Check if process is still running
      if (_process != null && _process!.pid > 0) {
        started = true;
      }
    }

    if (!started) {
      throw StateError('Failed to start collector properly');
    }

    print('Collector started successfully');
    // Clean up temp config file
    try {
      File(tempConfigPath).deleteSync();
    } catch (e) {
      // Ignore errors deleting temp file
    }

    // Allow some time for the collector to stabilize
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  /// Stop the collector
  Future<void> stop() async {
    if (_process != null) {
      try {
        // Send SIGTERM for graceful shutdown
        print('Stopping collector with PID: ${_process!.pid}');
        _process!.kill(ProcessSignal.sigterm);

        // Wait for a short time to allow graceful shutdown
        try {
          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (e) {
          // Ignore, just continue with force kill
        }

        // Check if process exited gracefully
        bool isRunning = true;
        try {
          // Check if process has already exited
          final exitCode = await _process!.exitCode
              .timeout(const Duration(milliseconds: 100));
          print('Collector exited with code: $exitCode');
          isRunning = false;
        } catch (e) {
          // If timeout, process is still running
          isRunning = true;
        }

        // Force kill if still running
        if (isRunning) {
          print('Collector still running, force killing...');
          try {
            _process!.kill(ProcessSignal.sigkill);
            await Future<void>.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            print('Error force killing collector: $e');
          }
        }

        // Find and kill any lingering processes by PID
        if (_process != null) {
          try {
            final pid = _process!.pid;
            await Process.run('kill', ['-9', '$pid']);
          } catch (e) {
            // Ignore errors here
          }
        }
      } catch (e) {
        print('Error stopping collector: $e');
      } finally {
        _process = null;
        // Make sure to clean up by checking for any leftover processes
        await _killExistingProcesses();
      }
    } else {
      // Even if we don't have a process reference, try to clean up
      await _killExistingProcesses();
    }
  }

  /// Kill any existing processes that might be using our ports or collector processes left behind
  Future<void> _killExistingProcesses() async {
    try {
      // Find and kill processes using our gRPC port
      final result = await Process.run('lsof', ['-i', ':$port']);
      if (result.stdout.toString().isNotEmpty) {
        final lines = result.stdout.toString().split('\n');
        for (var line in lines.skip(1)) {
          // Skip header line
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final pid = parts[1];
            if (pid.isNotEmpty) {
              print('Killing process $pid using port $port');
              await Process.run('kill', ['-9', pid]);
            }
          }
        }
      }

      // Find and kill any leftover otelcol processes
      final psResult = await Process.run('ps', ['-ef']);
      if (psResult.stdout.toString().isNotEmpty) {
        final lines = psResult.stdout.toString().split('\n');
        for (var line in lines) {
          if (line.contains('otelcol')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final pid = parts[1];
              if (pid.isNotEmpty) {
                print('Killing leftover otelcol process $pid');
                // Use SIGTERM first for graceful shutdown
                await Process.run('kill', [pid]);
                await Future<void>.delayed(const Duration(milliseconds: 100));
                // Then force kill if still running
                await Process.run('kill', ['-9', pid]);
              }
            }
          }
        }
      }

      // Wait a moment for ports to be released
      await Future<void>.delayed(const Duration(seconds: 1));
    } catch (e) {
      print('Error killing existing processes: $e');
      // Continue anyway
    }
  }

  /// Get all spans from the exported data
  Future<List<Map<String, dynamic>>> getSpans() async {
    print('Reading spans from: $_outputPath');
    if (!File(_outputPath).existsSync()) {
      print('Output file does not exist: $_outputPath');
      return [];
    }

    try {
      final content = await File(_outputPath).readAsString();
      if (content.isEmpty) {
        print('Output file is empty');
        return [];
      }

      final lines = content.split('\n').where((l) => l.isNotEmpty);

      // Parse each line and extract spans
      final allSpans = <Map<String, dynamic>>[];
      for (final line in lines) {
        try {
          final data = json.decode(line) as Map<String, dynamic>;
          // Extract spans from OTLP format
          if (data.containsKey('resourceSpans')) {
            for (final resourceSpan in data['resourceSpans'] as List) {
              final resource =
                  resourceSpan['resource'] as Map<String, dynamic>?;
              final resourceAttrs =
                  _parseAttributes(resource?['attributes'] as List?);

              for (final scopeSpans in resourceSpan['scopeSpans'] as List) {
                for (final span in scopeSpans['spans'] as List) {
                  // Add resource attributes to each span
                  span['resourceAttributes'] = resourceAttrs;
                  allSpans.add(span as Map<String, dynamic>);
                }
              }
            }
          }
        } catch (e) {
          print('Error parsing line: $e\nLine: $line');
          // Continue with other lines
        }
      }
      return allSpans;
    } catch (e) {
      print('Error reading spans file: $e');
      return [];
    }
  }

  /// Parse OTLP attribute format into simple key-value pairs
  // ignore: strict_raw_type
  Map<String, dynamic> _parseAttributes(List? attrs) {
    if (attrs == null) return {};
    final result = <String, dynamic>{};

    for (final attr in attrs) {
      final key = attr['key'] as String;
      final valueMap = attr['value'];

      if (valueMap is! Map) {
        // If not a map (shouldn't happen), just store as is
        result[key] = valueMap;
        continue;
      }

      // Print attribute structure for debugging
      print('Processing attribute: key=$key, valueMap=$valueMap');

      // Extract the actual value based on its type
      if (valueMap['stringValue'] != null) {
        result[key] = valueMap['stringValue'];
        print('  Parsed as string: ${result[key]}');
      } else if (valueMap['intValue'] != null) {
        final intVal = valueMap['intValue'];
        // Ensure numeric types are preserved
        if (intVal is num) {
          result[key] = intVal;
        } else {
          result[key] = int.tryParse(intVal.toString()) ?? intVal;
        }
        print('  Parsed as int: ${result[key]}');
      } else if (valueMap['doubleValue'] != null) {
        final doubleVal = valueMap['doubleValue'];
        if (doubleVal is num) {
          result[key] = doubleVal;
        } else {
          result[key] = double.tryParse(doubleVal.toString()) ?? doubleVal;
        }
        print('  Parsed as double: ${result[key]}');
      } else if (valueMap['boolValue'] != null) {
        final boolVal = valueMap['boolValue'];
        if (boolVal is bool) {
          result[key] = boolVal;
        } else if (boolVal is String) {
          result[key] = boolVal.toLowerCase() == 'true';
        } else {
          result[key] = boolVal;
        }
        print('  Parsed as bool: ${result[key]}');
      } else {
        print(
            '  No value found for attribute $key, keys: ${valueMap.keys.join(', ')}');
      }
    }

    return result;
  }

  /// Clear all exported spans
  Future<void> clear() async {
    if (File(_outputPath).existsSync()) {
      // ignore: avoid_slow_async_io
      // ignore: avoid_slow_async_io
      await File(_outputPath).writeAsString('');
    }
  }

  Future<void> waitForSpans(int count, {Duration? timeout}) async {
    final deadline = DateTime.now().add(timeout ?? const Duration(seconds: 15));
    var attempts = 0;

    // Ensure output file exists
    if (!File(_outputPath).existsSync()) {
      await File(_outputPath).writeAsString('');
    }

    while (DateTime.now().isBefore(deadline)) {
      attempts++;
      var spans = await getSpans();
      print('waitForSpans attempt $attempts: found ${spans.length} spans');

      if (spans.length >= count) {
        print('waitForSpans: found required $count spans');
        return;
      }

      // Check if file exists and has content
      final file = File(_outputPath);
      final exists = file.existsSync();
      if (!exists) {
        print('Output file does not exist');
        // Create empty file
        // ignore: avoid_slow_async_io
        await file.writeAsString('');
      } else {
        final size = await file.length();
        print('Output file size: $size bytes');
        if (size > 0) {
          // File has content but we couldn't parse spans, try to read it directly
          final content = await file.readAsString();
          if (content.length < 1000) {
            // Only print if not too large
            print('Output file content: $content');
          } else {
            print(
                'Output file content is too large to print (${content.length} bytes)');
          }
        }

        // If file exists but is empty after multiple attempts, it might be an issue with collector
        if (size == 0 && attempts > 3) {
          print(
              'Output file is empty after multiple attempts, checking collector status...');
          // Check if collector is still running
          bool isRunning = _process != null;
          if (isRunning) {
            try {
              // On Dart, we can't check process status directly, so we'll try to get the pid
              final exitCode = _process!.pid;
              if (exitCode == 0) isRunning = false;
            } catch (e) {
              // If we get an exception, process is likely dead
              isRunning = false;
            }
          }

          // Check for fallback file
          final String fallbackPath = '$_outputPath.fallback';
          try {
            final fallbackFile = File(fallbackPath);
            print('Backup file exists at: $fallbackPath');
            if (fallbackFile.existsSync()) {
              final fallbackContent = await fallbackFile.readAsString();
              if (fallbackContent.isNotEmpty) {
                // Explicitly specify the type
                final jsonData = json.decode(fallbackContent);
                print('Using backup file content');
                if (jsonData is List) {
                  spans = jsonData.cast<Map<String, dynamic>>();
                  if (spans.length >= count) {
                    print('Found required $count spans in fallback file');
                    return;
                  }
                }
              } else {
                print('Backup file exists but is empty');
              }
            }
          } catch (e) {
            print('Error checking backup file: $e');
          }

          if (!isRunning) {
            print('Collector process is not running, restarting...');
            try {
              await stop(); // Ensure clean stop first
              await Future<void>.delayed(const Duration(
                  milliseconds: 500)); // Wait for resources to be freed
              await start();
              // Make sure the file is cleared after restart
              // ignore: avoid_slow_async_io
              await File(_outputPath).writeAsString('');
              // Allow collector to initialize
              await Future<void>.delayed(const Duration(milliseconds: 1000));
            } catch (e) {
              print('Failed to restart collector: $e');
            }
          }
        }
      }

      // Gradually increase delay between attempts but keep it reasonable
      final delayMs = 250 *
          (1 << (attempts ~/ 3).clamp(0, 4)); // Max ~4 seconds between attempts
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    // Final attempt to read spans
    final spans = await getSpans();
    throw TimeoutException('Timed out waiting for $count spans. '
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

    print('Looking for a span with name: $name');
    for (var span in spans) {
      final spanAttrs = _parseAttributes(span['attributes'] as List?);
      final resourceAttrs = span['resourceAttributes'] as Map<String, dynamic>?;
      final allAttrs = {...?resourceAttrs, ...spanAttrs};
      print(
          'Found span: ${span['name']}, spanId: ${span['spanId']}, traceId: ${span['traceId']}');
      print('  Attributes: $allAttrs');

      // Log the raw attribute structure for debugging
      print('  Raw attributes structure: ${span['attributes']}');

      // Dump all attribute keys to help debugging
      if (attributes != null) {
        print('  Expected attribute keys: ${attributes.keys.join(', ')}');
        print('  Actual attribute keys: ${allAttrs.keys.join(', ')}');

        // Check for missing keys
        for (final key in attributes.keys) {
          if (!allAttrs.containsKey(key)) {
            print('  Attribute $key is missing. Expected: ${attributes[key]}');
          }
        }
      }
    }

    // For more reliable span matching, try to find the first span when expecting a name
    if (name != null && spans.isNotEmpty && spans.length == 1) {
      print(
          'Single span found with name: ${spans[0]['name']}, expected: $name');
    }

    final matching = spans.where((span) {
      if (name != null && span['name'] != name) {
        print(
            'Span ${span['spanId']} has name "${span['name']}" which doesn\'t match expected "$name"');
        return false;
      }
      if (traceId != null && span['traceId'] != traceId) return false;
      if (spanId != null && span['spanId'] != spanId) return false;

      if (attributes != null) {
        // Check both span attributes and resource attributes
        final spanAttrs = _parseAttributes(span['attributes'] as List?);
        final resourceAttrs =
            span['resourceAttributes'] as Map<String, dynamic>?;
        final allAttrs = {...?resourceAttrs, ...spanAttrs};

        for (final entry in attributes.entries) {
          final expectedValue = entry.value;
          final actualValue = allAttrs[entry.key];

          if (actualValue == null) {
            print(
                'Attribute ${entry.key} is missing. Expected: $expectedValue');
            return false;
          }

          // Log types for debugging
          print(
              'Comparing ${entry.key}: expected=$expectedValue (${expectedValue.runtimeType}), actual=$actualValue (${actualValue.runtimeType})');

          // Perform appropriate comparison based on types
          bool match = false;
          if (expectedValue is num && actualValue is num) {
            // For numbers, compare numeric values (handles int vs double)
            match = expectedValue.toDouble() == actualValue.toDouble();
          } else if (expectedValue is bool && actualValue is bool) {
            // Direct comparison for booleans
            match = expectedValue == actualValue;
          } else if (expectedValue is String && actualValue is String) {
            // Direct comparison for strings
            match = expectedValue == actualValue;
          } else {
            // Last resort: string comparison for different types
            match = expectedValue.toString() == actualValue.toString();
          }

          if (!match) {
            print(
                'Attribute mismatch for ${entry.key}: expected $expectedValue (${expectedValue.runtimeType}), got $actualValue (${actualValue.runtimeType})');
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
