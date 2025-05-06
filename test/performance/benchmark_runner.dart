// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

/// Base class for all Dartastic performance benchmarks
abstract class DartasticBenchmark extends BenchmarkBase {
  DartasticBenchmark(super.name);

  @override
  ScoreEmitter get emitter => const PrintEmitter();

  @override
  double measure() {
    setup();
    final stopwatch = Stopwatch()..start();
    run();
    stopwatch.stop();
    teardown();
    return stopwatch.elapsedMicroseconds.toDouble();
  }

  /// The actual benchmark implementation
  @override
  void run();

  @override
  void warmup() {
    exercise();
  }

  /// Run the benchmark and print results with context
  void runAndPrint() {
    // Print benchmark configuration
    print('\nRunning benchmark: $name');
    printConfig();

    // Measure memory before
    final memBefore = MemorySnapshot();

    // Run the benchmark and store result
    final double microseconds = measure();

    // Measure memory after
    final memAfter = MemorySnapshot();

    // Print results with context
    print('Results:');
    print('  Average time: ${microseconds.toStringAsFixed(2)} μs');
    print('  Memory impact:');
    print('    RSS delta: ${(memAfter.rss - memBefore.rss) ~/ 1024} KB');
    print('    Heap delta: ${(memAfter.heap - memBefore.heap) ~/ 1024} KB');
    printExtraStats();

    print(''); // Empty line for readability
  }

  /// Print any benchmark-specific configuration
  void printConfig() {}

  /// Print any additional statistics
  void printExtraStats() {}
}

/// Utility for memory measurements
class MemorySnapshot {
  final int rss;
  final int heap;

  MemorySnapshot()
      : rss = _getCurrentRss(),
        heap = _getCurrentHeap();

  static int _getCurrentRss() {
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        final result =
            Process.runSync('ps', ['-o', 'rss=', '-p', pid.toString()]);
        if (result.exitCode == 0 && result.stdout != null) {
          return int.parse((result.stdout as String).trim()) *
              1024; // Convert KB to bytes
        }
      } catch (e) {
        print('Warning: Failed to measure RSS: $e');
      }
    } else if (Platform.isWindows) {
      try {
        final result = Process.runSync('wmic',
            ['process', 'where', 'ProcessId=$pid', 'get', 'WorkingSetSize']);
        if (result.exitCode == 0 && result.stdout != null) {
          final lines = (result.stdout as String).trim().split('\n');
          if (lines.length > 1) {
            return int.parse(lines[1].trim());
          }
        }
      } catch (e) {
        print('Warning: Failed to measure RSS: $e');
      }
    }
    return 0;
  }

  static int _getCurrentHeap() {
    // Note: For more accurate heap measurements, you should use the VM service protocol
    // This is a rough approximation based on RSS for now
    return _getCurrentRss();
  }
}
