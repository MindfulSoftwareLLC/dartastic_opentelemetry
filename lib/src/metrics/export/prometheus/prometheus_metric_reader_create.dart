// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

part of 'prometheus_metric_reader.dart';

/// Internal constructor access for the SDK factory.
@internal
class PrometheusMetricReaderCreate {
  /// Creates a reader; registration starts its listener.
  static PrometheusMetricReader create(
          {required String host, required int port}) =>
      PrometheusMetricReader._(host: host, port: port);
}
