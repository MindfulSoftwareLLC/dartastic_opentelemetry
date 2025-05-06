#!/bin/bash
# Script to run and report only the failing tests

set -e  # Exit on any error

echo "Running failing tests with detailed reporting..."

# Create output directory for test results
mkdir -p test-reports

# Run tests with verbose output and generate JSON report
dart test test-fail/ --reporter=json > test-reports/failing-tests-report.json

# Extract and print failing test names from the JSON report
echo "Extracting failing test names from report..."
dart run << 'EOF'
import 'dart:convert';
import 'dart:io';

void main() {
  final reportFile = File('test-reports/failing-tests-report.json');
  final String reportJson = reportFile.readAsStringSync();
  
  // Parse the JSON report
  final Map<String, dynamic> report = json.decode(reportJson);
  
  // Process test data
  int failedCount = 0;
  Map<String, List<String>> failuresByFile = {};
  
  if (report.containsKey('testEvents')) {
    for (var event in report['testEvents']) {
      if (event['type'] == 'testDone' && event['result'] == 'failure') {
        final test = event['testID'].split('/').last;
        final file = event['testID'].split('/')[0];
        
        if (!failuresByFile.containsKey(file)) {
          failuresByFile[file] = [];
        }
        failuresByFile[file]!.add(test);
        failedCount++;
      }
    }
  }
  
  // Print summary
  print('\n===== FAILING TESTS SUMMARY =====');
  print('Total failing tests: $failedCount\n');
  
  // Print failures by file
  failuresByFile.forEach((file, tests) {
    print('$file: (${tests.length} failures)');
    for (var test in tests) {
      print('  - $test');
    }
    print('');
  });
  
  // Write a simplified report to a text file
  final textReport = StringBuffer();
  textReport.writeln('Total failing tests: $failedCount\n');
  failuresByFile.forEach((file, tests) {
    textReport.writeln('$file: (${tests.length} failures)');
    for (var test in tests) {
      textReport.writeln('  - $test');
    }
    textReport.writeln('');
  });
  
  File('test-reports/failing-tests-summary.txt').writeAsStringSync(textReport.toString());
  print('Detailed report saved to test-reports/failing-tests-summary.txt');
}
EOF

echo "Testing completed. Check test-reports/failing-tests-summary.txt for a summary of failing tests."
