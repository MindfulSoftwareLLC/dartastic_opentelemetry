// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';
import '../metrics/meter_provider.dart';

import '../resource/resource.dart';

OTelFactory otelSDKFactoryFactoryFunction({
  required String apiEndpoint,
  required String apiServiceName,
  required String apiServiceVersion,
}) {
  return OTelSDKFactory(
    apiEndpoint: apiEndpoint,
    apiServiceName: apiServiceName,
    apiServiceVersion: apiServiceVersion,
  );
}


/// The factory used when no SDK is installed. The OpenTelemetry specification
/// requires the API to work without an SDK installed
/// All construction APIs use the factory, such as builders or 'from' helpers.
class OTelSDKFactory extends OTelAPIFactory {
  OTelSDKFactory({
    required super.apiEndpoint,
    required super.apiServiceName,
    required super.apiServiceVersion,
    super.factoryFactory = otelSDKFactoryFactoryFunction
  });


  /// Create a new [Resource] with [attributes] and the [schemaUrl]
  Resource resource(Attributes attributes, [String? schemaUrl]) {
    return ResourceCreate.create(attributes, schemaUrl);
  }

  /// Quickly create an empty resource
  Resource resourceEmpty() {
    return resource(attributesFromMap({}), null);
  }

  @override
  APITracerProvider tracerProvider({
    required String endpoint,
    String serviceName = "@dart/opentelemetry_api",
    String? serviceVersion = '1.11.0.0',
    Resource? resource
  }) {
    return SDKTracerProviderCreate.create(
      delegate: super.tracerProvider(
        endpoint: endpoint,
        serviceVersion: serviceVersion,
        serviceName: serviceName),
      resource: resource
    );
  }

  @override
  APIMeterProvider meterProvider({
    required String endpoint,
    String serviceName = "@dart/opentelemetry_api",
    String? serviceVersion = '1.11.0.0',
    Resource? resource
  }) {
    return SDKMeterProviderCreate.create(
        delegate: super.meterProvider(
            endpoint: endpoint,
            serviceVersion: serviceVersion,
            serviceName: serviceName),
        resource: resource
    );
  }
}
