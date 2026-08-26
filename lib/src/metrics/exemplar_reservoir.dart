// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'data/exemplar.dart';

/// An ExemplarReservoir receives measurements from instruments and samples them
/// to provide Exemplars.
abstract class ExemplarReservoir {
  /// Offers a measurement to the reservoir.
  ///
  /// The reservoir decides whether to retain the measurement as an exemplar.
  ///
  /// @param value The value of the measurement.
  /// @param attributes The attributes associated with the measurement.
  /// @param context The Context associated with the measurement.
  /// @param timestamp The time the measurement was recorded.
  void offerMeasurement(
      num value, Attributes attributes, Context context, DateTime timestamp);

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
  final Random _random = Random();
  int _measurementsSeen = 0;
  final List<_MeasurementData?> _storage;

  SimpleFixedSizeExemplarReservoir(this._size)
      : _storage = List.filled(_size, null);

  @override
  void offerMeasurement(
      num value, Attributes attributes, Context context, DateTime timestamp) {
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
        context: context,
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
            value: data.value,
            measurementAttributes: data.attributes,
            timestamp: data.timestamp,
            aggregationAttributes: pointAttributes,
            spanId: data.context.spanContext?.spanId,
            traceId: data.context.spanContext?.traceId,
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
/// It keeps the last seen measurement per histogram bucket.
class AlignedHistogramBucketExemplarReservoir implements ExemplarReservoir {
  final List<double> _boundaries;
  final List<_MeasurementData?> _storage;

  AlignedHistogramBucketExemplarReservoir(this._boundaries)
      : _storage = List.filled(_boundaries.length + 1, null);

  @override
  void offerMeasurement(
      num value, Attributes attributes, Context context, DateTime timestamp) {
    var bucketIndex = _boundaries.length;
    for (var i = 0; i < _boundaries.length; i++) {
      if (value <= _boundaries[i]) {
        bucketIndex = i;
        break;
      }
    }
    _storage[bucketIndex] = _MeasurementData(
      value: value,
      attributes: attributes,
      context: context,
      timestamp: timestamp,
    );
  }

  @override
  List<Exemplar> collectAndReset(Attributes pointAttributes) {
    final exemplars = <Exemplar>[];
    for (var i = 0; i < _storage.length; i++) {
      final data = _storage[i];
      if (data != null) {
        exemplars.add(
          Exemplar.fromMeasurement(
            value: data.value,
            measurementAttributes: data.attributes,
            timestamp: data.timestamp,
            aggregationAttributes: pointAttributes,
            spanId: data.context.spanContext?.spanId,
            traceId: data.context.spanContext?.traceId,
          ),
        );
        _storage[i] = null;
      }
    }
    return exemplars;
  }
}

class _MeasurementData {
  final num value;
  final Attributes attributes;
  final Context context;
  final DateTime timestamp;

  _MeasurementData({
    required this.value,
    required this.attributes,
    required this.context,
    required this.timestamp,
  });
}
