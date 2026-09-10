// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'data/exemplar.dart';

/// An ExemplarReservoir receives measurements from instruments and samples them
/// to provide Exemplars.
///
/// Note for future extension (Issues #151, #153): The reservoir choice should be
/// user-configurable via a View. Currently, storage constructors hardcode the reservoir
/// types. Once View parameters are fully wired up, this should be driven by the resolved View.
abstract class ExemplarReservoir {
  /// Offers a measurement to the reservoir.
  ///
  /// The reservoir decides whether to retain the measurement as an exemplar.
  ///
  /// @param value The value of the measurement.
  /// @param attributes The attributes associated with the measurement.
  /// @param context The Context associated with the measurement.
  /// @param timestamp The time the measurement was recorded.
  /// @param bucketIndex Optional pre-computed histogram bucket index.
  void offerMeasurement(
      num value, Attributes attributes, Context context, DateTime timestamp,
      [int? bucketIndex]);

  /// Returns the currently sampled exemplars and clears the reservoir.
  ///
  /// @param pointAttributes The attributes associated with the metric point.
  /// @return A list of the sampled exemplars.
  List<Exemplar> collectAndReset(Attributes pointAttributes);
}

/// A reservoir that retains a fixed number of exemplars.
///
/// If more measurements are offered than the fixed size, this implementation
/// uses a simple random sampling algorithm to decide which exemplars to replace.
class SimpleFixedSizeExemplarReservoir implements ExemplarReservoir {
  final int _size;
  final Random _random;
  int _measurementsSeen = 0;
  final List<_MeasurementData?> _storage;

  SimpleFixedSizeExemplarReservoir(this._size, {Random? random})
      : _random = random ?? Random(),
        _storage = List.filled(_size, null);

  @override
  void offerMeasurement(
      num value, Attributes attributes, Context context, DateTime timestamp,
      [int? bucketIndex]) {
    int bucket;
    if (_measurementsSeen < _size) {
      bucket = _measurementsSeen;
    } else {
      bucket = _random.nextInt(_measurementsSeen + 1);
    }

    if (bucket < _size) {
      _storage[bucket] = _MeasurementData(
        value: value,
        attributes: attributes,
        traceId: context.spanContext?.traceId,
        spanId: context.spanContext?.spanId,
        timestamp: timestamp,
      );
    }
    _measurementsSeen++;
  }

  @override
  List<Exemplar> collectAndReset(Attributes pointAttributes) {
    final exemplars = <Exemplar>[];
    for (var i = 0; i < _storage.length; i++) {
      final data = _storage[i];
      if (data != null) {
        exemplars.add(
          Exemplar.fromMeasurement(
            measurement: OTelAPI.createMeasurement(data.value, data.attributes),
            timestamp: data.timestamp,
            aggregationAttributes: pointAttributes,
            spanId: data.spanId,
            traceId: data.traceId,
          ),
        );
        _storage[i] = null;
      }
    }
    _measurementsSeen = 0;
    return exemplars;
  }
}

/// A reservoir that is aligned to histogram buckets.
///
/// It MUST store at most one measurement that falls within a histogram bucket,
/// and SHOULD use a uniformly-weighted sampling algorithm based on the number
/// of measurements the bucket has seen so far.
class AlignedHistogramBucketExemplarReservoir implements ExemplarReservoir {
  final List<double> _boundaries;
  final List<_MeasurementData?> _storage;
  final List<int> _counts;
  final Random _random;

  AlignedHistogramBucketExemplarReservoir(this._boundaries, {Random? random})
      : _storage = List.filled(_boundaries.length + 1, null),
        _counts = List.filled(_boundaries.length + 1, 0),
        _random = random ?? Random();

  @override
  void offerMeasurement(
      num value, Attributes attributes, Context context, DateTime timestamp,
      [int? bucketIndex]) {
    int index;
    if (bucketIndex != null) {
      index = bucketIndex;
    } else {
      index = _boundaries.length;
      for (var i = 0; i < _boundaries.length; i++) {
        if (value <= _boundaries[i]) {
          index = i;
          break;
        }
      }
    }

    final measurementsSeenBucket = _counts[index];
    if (measurementsSeenBucket == 0 ||
        _random.nextInt(measurementsSeenBucket + 1) == 0) {
      _storage[index] = _MeasurementData(
        value: value,
        attributes: attributes,
        traceId: context.spanContext?.traceId,
        spanId: context.spanContext?.spanId,
        timestamp: timestamp,
      );
    }
    _counts[index]++;
  }

  @override
  List<Exemplar> collectAndReset(Attributes pointAttributes) {
    final exemplars = <Exemplar>[];
    for (var i = 0; i < _storage.length; i++) {
      final data = _storage[i];
      if (data != null) {
        exemplars.add(
          Exemplar.fromMeasurement(
            measurement: OTelAPI.createMeasurement(data.value, data.attributes),
            timestamp: data.timestamp,
            aggregationAttributes: pointAttributes,
            spanId: data.spanId,
            traceId: data.traceId,
          ),
        );
        _storage[i] = null;
      }
      _counts[i] = 0;
    }
    return exemplars;
  }
}

class _MeasurementData {
  final num value;
  final Attributes attributes;
  final TraceId? traceId;
  final SpanId? spanId;
  final DateTime timestamp;

  _MeasurementData({
    required this.value,
    required this.attributes,
    this.traceId,
    this.spanId,
    required this.timestamp,
  });
}
