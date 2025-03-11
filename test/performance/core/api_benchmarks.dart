// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:dartastic_opentelemetry/src/otel.dart';

/// Benchmarks for attributes
class AttributesBenchmark extends BenchmarkBase {
  AttributesBenchmark() : super('Attributes Benchmark');

  late String stringKey;
  late String intKey;
  late String boolKey;

  @override
  void setup() {
    stringKey = 'key1';
    intKey = 'key2';
    boolKey = 'key3';
  }

  @override
  void run() {
    final attributes = OTel.attributesFromMap({stringKey: 'value1', intKey: 42, boolKey: true});
    attributes.getString(stringKey);
    attributes.getInt(intKey);
    attributes.getBool(boolKey);
  }
}

void main() {
  AttributesBenchmark().report();
}
