// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:io';

/// Runs the tests in sequence to avoid resource conflicts and memory issues
Future<void> main() async {
  print('🔍 Running tests in sequence to avoid resource conflicts');
  
  // First clean up any leftover processes that might be causing issues
  await _cleanUpProcesses();

  // Define test groups that need to be run in isolation
  final isolatedTests = [
    'test/trace/export/otlp/*_test.dart',
    'test/trace/sampling/*_test.dart',
  ];

  // Run tests that need isolation sequentially
  for (final testPattern in isolatedTests) {
    print('\n🧪 Running isolated tests: $testPattern');
    
    // Find matching test files
    final testFiles = await _findTests(testPattern);
    
    // Run each test file individually
    for (final testFile in testFiles) {
      print('\n⏳ Running isolated test: $testFile');
      final result = await _runTest(testFile);
      
      // Check result
      if (!result) {
        print('❌ Test failed: $testFile');
      } else {
        print('✅ Test passed: $testFile');
      }
      
      // Make sure all processes are cleaned up between tests
      await _cleanUpProcesses();
      
      // Add delay between tests to allow for resource cleanup
      print('   Waiting for resources to be freed...');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
  
  // Run other tests in parallel (excluded the isolated ones)
  print('\n🧪 Running other tests');
  final excludePatterns = isolatedTests.map((p) => '--exclude-tags="$p"').join(' ');
  final result = await Process.run('dart', ['test', excludePatterns]);
  
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  
  print('\n🏁 Test run complete');
  exit(result.exitCode);
}

/// Find test files matching the given pattern
Future<List<String>> _findTests(String pattern) async {
  final result = await Process.run('find', ['test', '-path', pattern]);
  final output = (result.stdout as String).trim();
  if (output.isEmpty) {
    return [];
  }
  return output.split('\n');
}

/// Run a single test file
Future<bool> _runTest(String testFile) async {
  // Add environment variable to prevent memory issues
  final env = Map<String, String>.from(Platform.environment);
  env['DART_VM_OPTIONS'] = '--old-gen-heap-size=512'; // Limit heap size
  
  final result = await Process.run(
    'dart', 
    ['test', '-j', '1', testFile],
    environment: env,
  );
  
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  
  return result.exitCode == 0;
}

/// Clean up any leftover processes
Future<void> _cleanUpProcesses() async {
  print('🧹 Cleaning up processes...');
  
  // Kill collector processes
  try {
    final result = await Process.run('ps', ['-ef']);
    if (result.stdout.toString().isNotEmpty) {
      final lines = result.stdout.toString().split('\n');
      for (var line in lines) {
        if (line.contains('otelcol')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final pid = parts[1];
            if (pid.isNotEmpty) {
              print('   Killing leftover otelcol process $pid');
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
  } catch (e) {
    print('   Error cleaning up processes: $e');
  }
  
  // Wait for cleanup to complete
  await Future<void>.delayed(const Duration(seconds: 1));
}
