// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.
import 'package:dartastic_opentelemetry/src/trace/tracer_provider.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import '../metrics/meter_provider.dart';

import '../resource/resource.dart';

/// Factory function that creates an OTelSDKFactory with the specified configuration.
///
/// Application developers should use the OTel class to create object, which uses this factory.
/// This function serves as the default factory for creating OTelSDKFactory instances.
/// It encapsulates the creation logic for the factory to make it simpler to create
/// properly configured instances.
///
/// @param apiEndpoint The endpoint URL for the OpenTelemetry collector
/// @param apiServiceName The name of the service being instrumented
/// @param apiServiceVersion The version of the service being instrumented
/// @return A configured OTelSDKFactory instance
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

/// Factory implementation for creating OpenTelemetry SDK objects.
///
/// The OTelSDKFactory extends the API factory to provide implementations
/// of SDK-specific objects and override API object creation to use SDK implementations.
/// This factory is the primary entry point for creating OpenTelemetry objects in the SDK.
///
/// The OpenTelemetry specification requires the API to work without an SDK installed.
/// When the SDK is installed, this factory replaces the API's factory to provide
/// concrete implementations instead of no-op implementations.
class OTelSDKFactory extends OTelAPIFactory {
  /// Creates a new OTelSDKFactory with the specified configuration.
  ///
  /// @param apiEndpoint The endpoint URL for the OpenTelemetry collector
  /// @param apiServiceName The name of the service being instrumented
  /// @param apiServiceVersion The version of the service being instrumented
  /// @param factoryFactory Optional factory function for creating new instances
  OTelSDKFactory(
      {required super.apiEndpoint,
      required super.apiServiceName,
      required super.apiServiceVersion,
      super.factoryFactory = otelSDKFactoryFactoryFunction});

  /// Creates a new Resource with the specified attributes and schema URL.
  ///
  /// Resources are immutable collections of attributes that describe the entity
  /// producing telemetry. They are an SDK concept that's not present in the API.
  ///
  /// @param attributes The attributes describing the resource
  /// @param schemaUrl Optional schema URL for the resource attributes
  /// @return A new Resource instance with the provided attributes
  Resource resource(Attributes attributes, [String? schemaUrl]) {
    return ResourceCreate.create(attributes, schemaUrl);
  }

  /// Creates an empty resource with no attributes.
  ///
  /// This is a convenience method for quickly creating an empty resource
  /// when no resource attributes are needed.
  ///
  /// @return A new empty Resource instance
  Resource resourceEmpty() {
    return resource(attributesFromMap({}), null);
  }

  /// Creates a TracerProvider with the specified configuration.
  ///
  /// This implementation overrides the API's method to create an SDK TracerProvider
  /// that produces real traces instead of no-op traces.
  ///
  /// @param endpoint The endpoint URL for the OpenTelemetry collector
  /// @param serviceName The name of the service being instrumented
  /// @param serviceVersion The version of the service being instrumented
  /// @param resource Optional resource describing the service
  /// @return A configured TracerProvider instance
  @override
  APITracerProvider tracerProvider(
      {required String endpoint,
      String serviceName =
          "@dart/opentelemetry_api", //TODO - @dart/dartastic_opentelemetry
      String? serviceVersion,
      Resource? resource}) {
    return SDKTracerProviderCreate.create(
        delegate: super.tracerProvider(
            endpoint: endpoint,
            serviceVersion: serviceVersion,
            serviceName: serviceName),
        resource: resource);
  }

  /// Creates a MeterProvider with the specified configuration.
  ///
  /// This implementation overrides the API's method to create an SDK MeterProvider
  /// that produces real metrics instead of no-op metrics.
  ///
  /// @param endpoint The endpoint URL for the OpenTelemetry collector
  /// @param serviceName The name of the service being instrumented
  /// @param serviceVersion The version of the service being instrumented
  /// @param resource Optional resource describing the service
  /// @return A configured MeterProvider instance
  @override
  APIMeterProvider meterProvider(
      {required String endpoint,
      String serviceName = "@dart/opentelemetry_api",
      String? serviceVersion,
      Resource? resource}) {
    return SDKMeterProviderCreate.create(
        delegate: super.meterProvider(
            endpoint: endpoint,
            serviceVersion: serviceVersion,
            serviceName: serviceName),
        resource: resource);
  }
}
