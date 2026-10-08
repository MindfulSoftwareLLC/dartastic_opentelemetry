// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

part of 'meter_provider.dart';

/// Internal constructor access for TracerProvider
@internal
class SDKMeterProviderCreate {
  /// Creates a TracerProvider, only accessible within library
  static MeterProvider create({
    required APIMeterProvider delegate,
    required String endpoint,
    required String serviceName,
    String? serviceVersion,
    Resource? resource,
  }) {
    return MeterProvider._(
      delegate: delegate,
      endpoint: endpoint,
      serviceName: serviceName,
      serviceVersion: serviceVersion,
      resource: resource,
    );
  }
}
