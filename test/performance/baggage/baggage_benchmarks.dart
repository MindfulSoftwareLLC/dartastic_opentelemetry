// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../benchmark_runner.dart';

/// Measures the overhead of baggage creation and manipulation
class BaggageOperationsBenchmark extends DartasticBenchmark {
  static const int numOperations = 1000;
  final int numEntries;

  late Baggage _testBaggage;

  BaggageOperationsBenchmark({this.numEntries = 10})
      : super('Baggage Operations ($numEntries entries)');

  @override
  void setup() {
    _testBaggage = OTel.baggage();
    for (var i = 0; i < numEntries; i++) {
      _testBaggage = _testBaggage.copyWith(
        'key.$i',
        'value.$i',
        'metadata.$i',
      );
    }
  }

  @override
  void run() {
    for (var i = 0; i < numOperations; i++) {
      _testBaggage = _testBaggage.copyWith('test.key', 'test.value');
      _testBaggage.getEntry('key.1');
      _testBaggage = _testBaggage.copyWithout('test.key');
      _testBaggage.getAllEntries();
    }
  }

  @override
  void printConfig() {
    print('  Number of entries: $numEntries');
    print('  Operations per run: $numOperations');
  }
}

/// Measures the impact of baggage size on cross-isolate performance
class BaggageIsolateBenchmark extends DartasticBenchmark {
  static const int numIterations = 100;
  final int numEntries;

  BaggageIsolateBenchmark({this.numEntries = 10})
      : super('Baggage Isolate Crossing ($numEntries entries)');

  @override
  void setup() {
    Baggage baggage = OTel.baggage();
    for (var i = 0; i < numEntries; i++) {
      baggage = baggage.copyWith(
        'key.$i',
        'value.$i',
        'metadata.$i',
      );
    }
  }

  @override
  void run() async {
    for (var i = 0; i < numIterations; i++) {
      await Context.current.runIsolate(() async {
        return Context.currentWithBaggage().baggage!.getAllEntries().length;
      });
    }
  }

  @override
  void printConfig() {
    print('  Number of baggage entries: $numEntries');
    print('  Number of isolate crossings: $numIterations');
  }
}

/// Measures memory impact of baggage with different cardinalities
class BaggageMemoryBenchmark extends DartasticBenchmark {
  final int numUniqueKeys;
  final int numValuesPerKey;
  late List<Baggage> _baggages;

  BaggageMemoryBenchmark({
    this.numUniqueKeys = 100,
    this.numValuesPerKey = 1000,
  }) : super('Baggage Memory ($numUniqueKeys keys × $numValuesPerKey values)');

  @override
  void setup() {
    _baggages = [];
    for (var i = 0; i < numValuesPerKey; i++) {
      var baggage = OTel.baggage();
      for (var j = 0; j < numUniqueKeys; j++) {
        baggage = baggage.copyWith('key.$j', 'value.$i.$j');
      }
      _baggages.add(baggage);
    }
  }

  @override
  void run() {
    for (var baggage in _baggages.take(100)) {
      baggage.getAllEntries();
    }
  }

  @override
  void printConfig() {
    print('  Number of unique keys: $numUniqueKeys');
    print('  Values per key: $numValuesPerKey');
    print('  Total baggage instances: ${_baggages.length}');
  }

  @override
  void printExtraStats() {
    final snapshot = MemorySnapshot();
    print('  Current memory usage:');
    print('    RSS: ${snapshot.rss ~/ 1024} KB');
    print('    Heap: ${snapshot.heap ~/ 1024} KB');
    print(
        '  Average memory per entry: ${(snapshot.heap / (numUniqueKeys * numValuesPerKey)).toStringAsFixed(2)} bytes');
  }
}

/// Run all baggage benchmarks with different configurations
void main() {
  // Basic operations benchmarks
  BaggageOperationsBenchmark(numEntries: 5).runAndPrint();
  BaggageOperationsBenchmark(numEntries: 50).runAndPrint();
  BaggageOperationsBenchmark(numEntries: 500).runAndPrint();

  // Cross-isolate benchmarks
  BaggageIsolateBenchmark(numEntries: 5).runAndPrint();
  BaggageIsolateBenchmark(numEntries: 50).runAndPrint();

  // Memory impact benchmarks
  BaggageMemoryBenchmark(
    numUniqueKeys: 10,
    numValuesPerKey: 100,
  ).runAndPrint();
  BaggageMemoryBenchmark(
    numUniqueKeys: 100,
    numValuesPerKey: 1000,
  ).runAndPrint();
}
