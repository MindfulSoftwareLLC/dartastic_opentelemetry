// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

/// Main entry point for the OpenTelemetry SDK.
///
/// The [OTel] class provides static methods for initializing the SDK and
/// creating OpenTelemetry objects such as Tracers, Spans, Meters, and other
/// components necessary for instrumentation.
///
/// To use the SDK, you must first call [initialize] to set up the global
/// configuration and install the SDK implementation. After initialization,
/// you can use the various factory methods to create OpenTelemetry objects.
///
/// Example usage:
/// ```dart
/// await OTel.initialize(
///   serviceName: 'my-service',
///   serviceVersion: '1.0.0',
///   endpoint: 'https://otel-collector.example.com:4317',
/// );
///
/// final tracer = OTel.tracer();
/// final span = tracer.startSpan('my-operation');
/// // ... perform work ...
/// span.end();
/// ```
///
/// The tenant_id and the resources from platform resource detection are merged
/// with resource attributes with resource attributes taking priority.
/// The values must be valid Attribute types (String, bool, int, double, or
/// List\<String>, List\<bool>, List\<int> or List\<double>).
class OTel {
  static OTelSDKFactory? _otelFactory;
  static Sampler? _defaultSampler;

  /// Default resource for the SDK.
  ///
  /// This is set during initialization and used by tracer and meter providers
  /// that don't have a specific resource set.
  static Resource? defaultResource;

  /// API key for Dartastic.io backend, if used.
  static String? dartasticApiKey;

  /// Default service name used if none is provided.
  static const defaultServiceName = "@dart/dartastic_opentelemetry";

  /// Default OTEL endpoint
  static const defaultEndpoint = "http://localhost:4317";

  /// Default tracer name used if none is provided.
  static const String _defaultTracerName = 'dartastic';

  /// Default tracer name that can be customized.
  static String defaultTracerName = _defaultTracerName;

  /// Default tracer version.
  static String defaultTracerVersion = "1.0.0";

  /// Initializes the OpenTelemetry SDK with the specified configuration.
  ///
  /// This method must be called before any other OpenTelemetry operations.
  /// It sets up the global configuration and installs the SDK implementation.
  ///
  /// When OTelLog.debug is true or the environmental variable
  /// OTEL_CONSOLE_EXPORTER is set to true, a ConsoleExporter is added to the
  /// exports to print spans.
  ///
  /// @param endpoint The endpoint URL for the OpenTelemetry collector (default: http://localhost:4317)
  /// @param secure Whether to use TLS for the connection (default: true)
  /// @param serviceName Name that uniquely identifies the service (default: "@dart/dartastic_opentelemetry")
  /// @param serviceVersion Version of the service (defaults to the OTel spec version)
  /// @param tracerName Name of the default tracer (default: "dartastic")
  /// @param tracerVersion Version of the default tracer (default: null)
  /// @param resourceAttributes Additional attributes for the resource
  /// @param spanProcessor Custom span processor (default: BatchSpanProcessor with OtlpGrpcSpanExporter)
  /// @param sampler Sampling strategy to use (default: AlwaysOnSampler)
  /// @param spanKind Default span kind (default: SpanKind.server)
  /// @param metricExporter Custom metric exporter for metrics
  /// @param metricReader Custom metric reader for metrics
  /// @param enableMetrics Whether to enable metrics collection (default: true)
  /// @param dartasticApiKey API key for Dartastic.io backend
  /// @param tenantId Tenant ID for multi-tenant backends (required for Dartastic.io)
  /// @param detectPlatformResources Whether to detect platform resources (default: true)
  /// @param oTelFactoryCreationFunction Factory function for creating OTelSDKFactory instances
  /// @return A Future that completes when initialization is done
  /// @throws StateError if called more than once
  /// @throws ArgumentError if required parameters are invalid
  static Future<void> initialize({
    String? endpoint,
    bool? secure,
    String? serviceName,
    String? serviceVersion,
    String? tracerName,
    String? tracerVersion,
    Attributes? resourceAttributes,
    SpanProcessor? spanProcessor,
    Sampler sampler = const AlwaysOnSampler(),
    SpanKind spanKind = SpanKind.server,
    MetricExporter? metricExporter,
    MetricReader? metricReader,
    bool enableMetrics = true,
    String? dartasticApiKey,
    String? tenantId,
    bool detectPlatformResources = true,
    OTelFactoryCreationFunction? oTelFactoryCreationFunction =
        otelSDKFactoryFactoryFunction,
  }) async {
    // Apply environment variables only if parameters are not provided
    final envServiceName = serviceName == null
        ? OTelEnv.getServiceConfig()['serviceName'] as String?
        : null;
    final envServiceVersion = serviceVersion == null
        ? OTelEnv.getServiceConfig()['serviceVersion'] as String?
        : null;

    serviceName ??= envServiceName;
    serviceVersion ??= envServiceVersion;

    final otlpConfig = (endpoint == null || secure == null)
        ? OTelEnv.getOtlpConfig(signal: 'traces')
        : <String, dynamic>{};
    final envEndpoint =
        endpoint == null ? otlpConfig['endpoint'] as String? : null;
    final envInsecure = secure == null ? otlpConfig['insecure'] as bool? : null;

    endpoint ??= envEndpoint;
    if (secure == null) {
      if (envInsecure != null) {
        secure = !envInsecure;
      } else {
        secure = true;
      }
    }

    // Apply defaults if still null
    serviceName ??= defaultServiceName;
    serviceVersion ??= '1.0.0';
    endpoint ??= defaultEndpoint;
    // secure is guaranteed non-null from above

    // Log environment variable usage
    if (OTelLog.isDebug()) {
      if (envServiceName != null) {
        OTelLog.debug('Using service name from environment: $serviceName');
      }
      if (envServiceVersion != null) {
        OTelLog.debug(
            'Using service version from environment: $serviceVersion');
      }
      if (envEndpoint != null) {
        OTelLog.debug('Using endpoint from environment: $endpoint');
      }
      if (envInsecure != null) {
        OTelLog.debug('Using insecure setting from environment: $envInsecure');
      }
    }

    // Get otlpConfig for exporter creation later
    final otlpConfigForExporter = OTelEnv.getOtlpConfig(signal: 'traces');

    // Get resource attributes from environment and merge with provided ones
    final envResourceAttrs = OTelEnv.getResourceAttributes();
    if (envResourceAttrs.isNotEmpty) {
      if (resourceAttributes != null) {
        // Merge with provided attributes - provided ones take precedence
        final mergedAttrs = Map<String, Object>.from(envResourceAttrs);
        resourceAttributes.toList().forEach((attr) {
          mergedAttrs[attr.key] = attr.value;
        });
        resourceAttributes = OTel.attributesFromMap(mergedAttrs);
      } else {
        resourceAttributes = OTel.attributesFromMap(envResourceAttrs);
      }
    }
    if (OTelFactory.otelFactory != null) {
      throw StateError(
          'OTelAPI can only be initialized once. If you need multiple endpoints or service names or versions create a named TracerProvider');
    }

    if (endpoint.isEmpty) {
      throw ArgumentError(
          'endpoint must not be the empty string.'); //TODO validate url
    }
    if (serviceName.isEmpty) {
      throw ArgumentError('serviceName must not be the empty string.');
    }
    if (serviceVersion.isEmpty) {
      throw ArgumentError('serviceVersion must not be the empty string.');
    }
    final factoryFactory =
        oTelFactoryCreationFunction ?? otelSDKFactoryFactoryFunction;
    // Initialize with default sampler
    _defaultSampler = sampler;
    OTel.defaultTracerName = tracerName ?? _defaultTracerName;
    OTel.defaultTracerVersion = tracerVersion ?? defaultTracerVersion;
    OTel.dartasticApiKey = dartasticApiKey;
    // Initialize logging from environment variables if needed
    initializeLogging();

    OTelFactory.otelFactory = factoryFactory(
        apiEndpoint: endpoint,
        apiServiceName: serviceName,
        apiServiceVersion: serviceVersion);

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OTel initialized with endpoint: $endpoint, service: $serviceName');
    }

    final serviceResourceAttributes = {
      'service.name': serviceName,
      'service.version': serviceVersion,
    };
    // Create initial resource with service attributes
    var baseResource =
        OTel.resource(OTel.attributesFromMap(serviceResourceAttributes));

    if (tenantId != null) {
      // Create a separate tenant_id resource to ensure it's preserved
      final tenantResource =
          OTel.resource(OTel.attributesFromMap({'tenant_id': tenantId}));
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'OTel.initialize: Creating tenant_id resource with: $tenantId');
      }
      // Merge tenant into the base resource
      baseResource = baseResource.merge(tenantResource);
    }

    // Initialize with tenant-aware resource
    var mergedResource = baseResource;
    if (detectPlatformResources) {
      final resourceDetector = PlatformResourceDetector.create();
      final platformResource = await resourceDetector.detect();
      // Merge platform resource with our service resource - our service resource takes precedence
      mergedResource = platformResource.merge(mergedResource);

      if (OTelLog.isDebug()) {
        OTelLog.debug('Resource after platform merge:');
        mergedResource.attributes.toList().forEach((attr) {
          if (attr.key == 'tenant_id' || attr.key == 'service.name') {
            OTelLog.debug('  ${attr.key}: ${attr.value}');
          }
        });
      }
    }
    if (resourceAttributes != null) {
      final initResources = OTel.resource(resourceAttributes);
      // Merge user-provided attributes - they have highest priority
      mergedResource = mergedResource.merge(initResources);

      if (OTelLog.isDebug()) {
        OTelLog.debug('Resource after user attributes merge:');
        mergedResource.attributes.toList().forEach((attr) {
          if (attr.key == 'tenant_id' || attr.key == 'service.name') {
            OTelLog.debug('  ${attr.key}: ${attr.value}');
          }
        });
      }
    }
    // Set the final merged resource as default
    OTel.defaultResource = mergedResource;

    if (OTelLog.isDebug()) {
      // Final check to ensure tenant_id is preserved
      if (tenantId != null && OTel.defaultResource != null) {
        bool hasTenantId = false;
        OTel.defaultResource!.attributes.toList().forEach((attr) {
          if (attr.key == 'tenant_id') {
            hasTenantId = true;
            if (OTelLog.isDebug()) {
              OTelLog.debug(
                  'Final resource check - tenant_id is present: ${attr.value}');
            }
          }
        });

        if (!hasTenantId) {
          // As a last resort, add the tenant_id directly
          if (OTelLog.isDebug()) {
            OTelLog.debug('tenant_id was missing - adding it as fallback');
          }
          final tenantResource =
              OTel.resource(OTel.attributesFromMap({'tenant_id': tenantId}));
          OTel.defaultResource = OTel.defaultResource!.merge(tenantResource);
        }
      }
    }

    if (spanProcessor == null) {
      // Determine which exporter to create based on environment or defaults
      final exporterType = OTelEnv.getExporter(signal: 'traces') ?? 'otlp';

      if (exporterType != 'none') {
        // Determine protocol - default to http/protobuf if not set
        final protocol =
            otlpConfigForExporter['protocol'] as String? ?? 'http/protobuf';

        SpanExporter exporter;
        if (exporterType == 'console') {
          exporter = ConsoleExporter();
        } else if (exporterType == 'otlp') {
          // Create appropriate exporter based on protocol
          if (protocol == 'grpc') {
            exporter = OtlpGrpcSpanExporter(
              OtlpGrpcExporterConfig(
                endpoint: endpoint,
                insecure: !secure,
                headers:
                    otlpConfigForExporter['headers'] as Map<String, String>? ??
                        {},
                timeout: otlpConfigForExporter['timeout'] as Duration? ??
                    const Duration(seconds: 10),
                compression: otlpConfigForExporter['compression'] == 'gzip',
                certificate: otlpConfigForExporter['certificate'] as String?,
                clientKey: otlpConfigForExporter['clientKey'] as String?,
                clientCertificate:
                    otlpConfigForExporter['clientCertificate'] as String?,
              ),
            );
          } else {
            // Default to http/protobuf
            // For HTTP, adjust endpoint if it's the gRPC default
            String httpEndpoint = endpoint;
            if (endpoint == defaultEndpoint) {
              httpEndpoint = 'http://localhost:4318';
            }
            exporter = OtlpHttpSpanExporter(
              OtlpHttpExporterConfig(
                endpoint: httpEndpoint,
                headers:
                    otlpConfigForExporter['headers'] as Map<String, String>? ??
                        {},
                timeout: otlpConfigForExporter['timeout'] as Duration? ??
                    const Duration(seconds: 10),
                compression: otlpConfigForExporter['compression'] == 'gzip',
                certificate: otlpConfigForExporter['certificate'] as String?,
                clientKey: otlpConfigForExporter['clientKey'] as String?,
                clientCertificate:
                    otlpConfigForExporter['clientCertificate'] as String?,
              ),
            );
          }
        } else {
          // Fallback to gRPC for backward compatibility
          exporter = OtlpGrpcSpanExporter(
            OtlpGrpcExporterConfig(
              endpoint: endpoint,
              insecure: !secure,
            ),
          );
        }

        // Only add ConsoleExporter in debug mode or if explicitly requested
        final exporters = <SpanExporter>[exporter];
        if (OTelLog.isDebug() ||
            const bool.fromEnvironment('OTEL_CONSOLE_EXPORTER',
                defaultValue: false)) {
          exporters.add(ConsoleExporter());
        }

        spanProcessor = BatchSpanProcessor(
          exporters.length == 1 ? exporter : CompositeExporter(exporters),
          const BatchSpanProcessorConfig(
            maxQueueSize: 2048,
            scheduleDelay: Duration(seconds: 1),
            maxExportBatchSize: 512,
          ),
        );
      }
      // If exporterType == 'none', spanProcessor remains null and no processor is added
    }

    // Create and configure TracerProvider
    if (spanProcessor != null) {
      OTel.tracerProvider().addSpanProcessor(spanProcessor);
    }

    // Configure metrics if enabled
    if (enableMetrics) {
      // If no explicit metric exporter is provided, create one with the same endpoint
      if (metricExporter == null && metricReader == null) {
        MetricsConfiguration.configureMeterProvider(
          endpoint: endpoint,
          secure: secure,
          resource: OTel.defaultResource,
        );
      } else {
        // Use the provided exporter and/or reader
        MetricsConfiguration.configureMeterProvider(
          endpoint: endpoint,
          secure: secure,
          metricExporter: metricExporter,
          metricReader: metricReader,
          resource: OTel.defaultResource,
        );
      }
    }
  }

  /// Creates a Resource with the specified attributes and schema URL.
  ///
  /// Resources represent the entity producing telemetry, such as a service,
  /// process, or device. They are a collection of attributes that provide
  /// identifying information about the entity.
  ///
  /// @param attributes Attributes describing the resource
  /// @param schemaUrl Optional URL of the schema defining the attributes
  /// @return A new Resource instance
  static Resource resource(Attributes? attributes, [String? schemaUrl]) {
    _getAndCacheOtelFactory();
    return (_otelFactory as OTelSDKFactory)
        .resource(attributes ?? OTel.attributes(), schemaUrl);
  }

  /// Creates a new ContextKey with the given name.
  ///
  /// Context keys are used to store and retrieve values in a Context.
  /// Each instance will be unique, even with the same name, per the OTel spec.
  /// The name is for debugging purposes only.
  ///
  /// @param name The name of the context key (for debugging only)
  /// @return A new ContextKey instance
  static ContextKey<T> contextKey<T>(String name) {
    _getAndCacheOtelFactory();
    return _otelFactory!.contextKey(name, ContextKey.generateContextKeyId());
  }

  /// Creates a new Context with optional Baggage and SpanContext.
  ///
  /// Contexts are used to propagate information across the execution path,
  /// such as trace context, baggage, and other cross-cutting concerns.
  ///
  /// @param baggage Optional baggage to include in the context
  /// @param spanContext Optional span context to include in the context
  /// @return A new Context instance
  static Context context({Baggage? baggage, SpanContext? spanContext}) {
    _getAndCacheOtelFactory();
    var context = OTelFactory.otelFactory!.context(baggage: baggage);
    if (spanContext != null) {
      context = context.copyWithSpanContext(spanContext);
    }
    return context;
  }

  /// Gets a TracerProvider for creating Tracers.
  ///
  /// If name is null, this returns the global default TracerProvider, which shares
  /// the endpoint, serviceName, serviceVersion, sampler and resource set in initialize().
  /// If the name is not null, it returns a TracerProvider for the name that was added
  /// with addTracerProvider.
  ///
  /// The endpoint, serviceName, serviceVersion, sampler and resource set flow down
  /// to the [Tracer]s created by the TracerProvider and the [Span]
  /// created by those tracers
  /// @param name Optional name of a specific TracerProvider
  /// @return The TracerProvider instance
  static TracerProvider tracerProvider({String? name}) {
    final tracerProvider = OTelAPI.tracerProvider(name) as TracerProvider;
    // Ensure the resource is properly set
    if (tracerProvider.resource == null && defaultResource != null) {
      tracerProvider.resource = defaultResource;
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTel.tracerProvider: Setting resource from default');
        if (defaultResource != null) {
          defaultResource!.attributes.toList().forEach((attr) {
            if (attr.key == 'tenant_id' || attr.key == 'service.name') {
              OTelLog.debug('  ${attr.key}: ${attr.value}');
            }
          });
        }
      }
    }

    tracerProvider.sampler ??= _defaultSampler;
    return tracerProvider;
  }

  /// Gets a MeterProvider for creating Meters.
  ///
  /// If name is null, this returns the global default MeterProvider, which shares
  /// the endpoint, serviceName, serviceVersion and resource set in initialize().
  /// If the name is not null, it returns a MeterProvider for the name that was added
  /// with addMeterProvider.
  ///
  /// @param name Optional name of a specific MeterProvider
  /// @return The MeterProvider instance
  static MeterProvider meterProvider({String? name}) {
    final meterProvider = OTelAPI.meterProvider(name) as MeterProvider;
    meterProvider.resource ??= defaultResource;
    return meterProvider;
  }

  /// Adds or replaces a named TracerProvider.
  ///
  /// This allows for creating multiple TracerProviders with different configurations,
  /// which can be useful for sending telemetry to different backends or with different
  /// settings.
  ///
  /// @param name The name of the TracerProvider
  /// @param endpoint Optional custom endpoint URL
  /// @param serviceName Optional custom service name
  /// @param serviceVersion Optional custom service version
  /// @param resource Optional custom resource
  /// @param sampler Optional custom sampler
  /// @return The newly created or replaced TracerProvider
  static TracerProvider addTracerProvider(
    String name, {
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    Resource? resource,
    Sampler? sampler,
  }) {
    final sdkTracerProvider = OTelAPI.addTracerProvider(name) as TracerProvider;
    sdkTracerProvider.resource = resource ?? defaultResource;
    sdkTracerProvider.sampler = sampler ?? _defaultSampler;
    return sdkTracerProvider;
  }

  /// @return the [TracerProvider]s, the global default and named ones.
  static List<APITracerProvider> tracerProviders() {
    return OTelAPI.tracerProviders();
  }

  /// Gets the default Tracer from the default TracerProvider.
  ///
  /// This is a convenience method for getting a Tracer with the default configuration.
  /// The endpoint, serviceName, serviceVersion, sampler and resource all flow down
  /// from the OTel defaults set during initialization.
  ///
  /// @return The default Tracer instance
  static Tracer tracer() {
    return tracerProvider().getTracer(
      defaultTracerName,
      version: defaultTracerVersion,
    );
  }

  /// Adds or replaces a named MeterProvider.
  ///
  /// This allows for creating multiple MeterProviders with different configurations,
  /// which can be useful for sending metrics to different backends or with different
  /// settings.
  ///
  /// @param name The name of the MeterProvider
  /// @param endpoint Optional custom endpoint URL
  /// @param serviceName Optional custom service name
  /// @param serviceVersion Optional custom service version
  /// @param resource Optional custom resource
  /// @return The newly created or replaced MeterProvider
  static MeterProvider addMeterProvider(
    String name, {
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    Resource? resource,
  }) {
    _getAndCacheOtelFactory();
    final mp = _otelFactory!.addMeterProvider(name,
        endpoint: endpoint,
        serviceName: serviceName,
        serviceVersion: serviceVersion) as MeterProvider;
    mp.resource = resource ?? defaultResource;
    return mp;
  }

  /// @return the [MeterProvider]s, the global default and named ones.
  static List<APIMeterProvider> meterProviders() {
    return OTelAPI.meterProviders();
  }

  /// Gets the default Meter from the default MeterProvider.
  ///
  /// This is a convenience method for getting a Meter with the default configuration.
  /// The endpoint, serviceName, serviceVersion and resource all flow down from
  /// the OTel defaults set during initialization.
  ///
  /// @param name Optional custom name for the meter (defaults to defaultTracerName)
  /// @return The default Meter instance
  static Meter meter([String? name]) {
    return meterProvider().getMeter(
        name: name ?? defaultTracerName,
        version: defaultTracerVersion) as Meter;
  }

  /// Creates a SpanContext with the specified parameters.
  ///
  /// A SpanContext represents the portion of a span that must be propagated
  /// to descendant spans and across process boundaries. It contains the
  /// traceId, spanId, traceFlags, and traceState.
  ///
  /// @param traceId The trace ID (defaults to a new random ID)
  /// @param spanId The span ID (defaults to a new random ID)
  /// @param parentSpanId The parent span ID (defaults to an invalid span ID)
  /// @param traceFlags Trace flags (defaults to NONE_FLAG)
  /// @param traceState Trace state
  /// @param isRemote Whether this context was received from a remote source
  /// @return A new SpanContext instance
  static SpanContext spanContext(
      {TraceId? traceId,
      SpanId? spanId,
      SpanId? parentSpanId,
      TraceFlags? traceFlags,
      TraceState? traceState,
      bool? isRemote}) {
    return OTelAPI.spanContext(
      traceId: traceId ?? OTel.traceId(),
      spanId: spanId ?? OTel.spanId(),
      parentSpanId: parentSpanId ?? spanIdInvalid(),
      traceFlags: traceFlags ?? OTelAPI.traceFlags(),
      traceState: traceState,
      isRemote: isRemote,
    );
  }

  /// Creates a child SpanContext from a parent context.
  ///
  /// This creates a new SpanContext that shares the same traceId as the parent,
  /// but has a new spanId and the parentSpanId set to the parent's spanId.
  ///
  /// @param parent The parent SpanContext
  /// @return A new child SpanContext
  static SpanContext spanContextFromParent(SpanContext parent) {
    _getAndCacheOtelFactory();
    return OTelFactory.otelFactory!.spanContextFromParent(parent);
  }

  /// Creates an invalid SpanContext (all zeros).
  ///
  /// An invalid SpanContext represents the absence of a trace context.
  ///
  /// @return An invalid SpanContext instance
  static SpanContext spanContextInvalid() {
    _getAndCacheOtelFactory();
    return OTelFactory.otelFactory!.spanContextInvalid();
  }

  /// Creates a SpanEvent with the current timestamp.
  ///
  /// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
  /// span events are being deprecated and will be replaced by the Logging API in future versions.
  ///
  /// @param name The name of the event
  /// @param attributes Attributes to associate with the event
  /// @return A new SpanEvent instance with the current timestamp
  static SpanEvent spanEventNow(String name, Attributes attributes) {
    _getAndCacheOtelFactory();
    return spanEvent(name, attributes, DateTime.now());
  }

  /// Creates a SpanEvent with the specified parameters.
  ///
  /// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
  /// span events are being deprecated and will be replaced by the Logging API in future versions.
  ///
  /// @param name The name of the event
  /// @param attributes Optional attributes to associate with the event
  /// @param timestamp Optional timestamp for the event (defaults to null)
  /// @return A new SpanEvent instance
  static SpanEvent spanEvent(String name,
      [Attributes? attributes, DateTime? timestamp]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.spanEvent(name, attributes, timestamp);
  }

  /// Creates a Baggage with key-value pairs.
  ///
  /// Baggage is a set of key-value pairs that can be propagated across service boundaries
  /// along with the trace context. It can be used to add contextual information to traces.
  ///
  /// @param keyValuePairs A map of key-value pairs to include in the baggage
  /// @return A new Baggage instance
  static Baggage baggageForMap(Map<String, String> keyValuePairs) {
    _getAndCacheOtelFactory();
    return _otelFactory!.baggageForMap(keyValuePairs);
  }

  /// Creates a BaggageEntry with the specified value and optional metadata.
  ///
  /// @param value The value of the baggage entry
  /// @param metadata Optional metadata for the baggage entry
  /// @return A new BaggageEntry instance
  static BaggageEntry baggageEntry(String value, [String? metadata]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.baggageEntry(value, metadata);
  }

  /// Creates a Baggage with the specified entries.
  ///
  /// @param entries Optional map of baggage entries
  /// @return A new Baggage instance
  static Baggage baggage([Map<String, BaggageEntry>? entries]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.baggage(entries);
  }

  /// Creates a Baggage instance from a JSON representation.
  ///
  /// @param json JSON representation of a baggage
  /// @return A new Baggage instance
  static Baggage baggageFromJson(Map<String, dynamic> json) {
    return OTelAPI.baggageFromJson(json);
  }

  /// Creates a string attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The string value of the attribute
  /// @return A new Attribute instance
  static Attribute<String> attributeString(String name, String value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeString(name, value);
  }

  /// Creates a boolean attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The boolean value of the attribute
  /// @return A new Attribute instance
  static Attribute<bool> attributeBool(String name, bool value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeBool(name, value);
  }

  /// Creates an integer attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The integer value of the attribute
  /// @return A new Attribute instance
  static Attribute<int> attributeInt(String name, int value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeInt(name, value);
  }

  /// Creates a double attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The double value of the attribute
  /// @return A new Attribute instance
  static Attribute<double> attributeDouble(String name, double value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeDouble(name, value);
  }

  /// Creates a string list attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The list of string values
  /// @return A new Attribute instance
  static Attribute<List<String>> attributeStringList(
      String name, List<String> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeStringList(name, value);
  }

  /// Creates a boolean list attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The list of boolean values
  /// @return A new Attribute instance
  static Attribute<List<bool>> attributeBoolList(
      String name, List<bool> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeBoolList(name, value);
  }

  /// Creates an integer list attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The list of integer values
  /// @return A new Attribute instance
  static Attribute<List<int>> attributeIntList(String name, List<int> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeIntList(name, value);
  }

  /// Creates a double list attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The list of double values
  /// @return A new Attribute instance
  static Attribute<List<double>> attributeDoubleList(
      String name, List<double> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeDoubleList(name, value);
  }

  /// Creates an empty Attributes collection.
  ///
  /// @return A new empty Attributes collection
  static Attributes createAttributes() {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributes();
  }

  /// Creates an Attributes collection from a list of Attribute objects.
  ///
  /// @param entries Optional list of Attribute objects
  /// @return A new Attributes collection
  static Attributes attributes([List<Attribute>? entries]) {
    // Cheating here since Attributes is unlikely to be overriden in a
    // factory and is often called before initialize
    return _otelFactory == null
        ? AttributesCreate.create(entries ?? [])
        : _otelFactory!.attributes(entries);
  }

  /// Creates an Attributes collection from a map of named values.
  ///
  /// String, bool, int, double, or Lists of those types get converted
  /// to the matching typed attribute. DateTime gets converted to a
  /// String attribute with the UTC time string.
  ///
  /// Unlike most methods, this does not create the OTelFactory if
  /// one does not exist, instead it uses the OTelAPI's attributesFromMap.
  ///
  /// Alternatively, consider using the toAttributes()
  /// extension on \<String, Map>{}.
  /// @param namedMap Map of attribute names to values
  /// @return A new Attributes collection
  static Attributes attributesFromMap(Map<String, Object> namedMap) {
    if (_otelFactory == null) {
      return OTelAPI.attributesFromMap(namedMap);
    } else {
      return _otelFactory!.attributesFromMap(namedMap);
    }
  }

  /// Creates an Attributes collection from a list of Attribute objects.
  ///
  /// @param attributeList List of Attribute objects
  /// @return A new Attributes collection
  static Attributes attributesFromList(List<Attribute> attributeList) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributesFromList(attributeList);
  }

  /// Creates a TraceState with the specified entries.
  ///
  /// TraceState carries vendor-specific trace identification data across systems.
  ///
  /// @param entries Optional map of key-value pairs for the trace state
  /// @return A new TraceState instance
  static TraceState traceState(Map<String, String>? entries) {
    _getAndCacheOtelFactory();
    return _otelFactory!.traceState(entries);
  }

  /// Creates TraceFlags with the specified flags.
  ///
  /// TraceFlags are used to encode bit field flags in the trace context.
  /// The most commonly used flag is SAMPLED_FLAG, which indicates
  /// that the trace should be sampled.
  ///
  /// @param flags Optional flags value (default: NONE_FLAG)
  /// @return A new TraceFlags instance
  static TraceFlags traceFlags([int? flags]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.traceFlags(flags ?? TraceFlags.NONE_FLAG);
  }

  /// Generates a new random TraceId.
  ///
  /// @return A new random TraceId
  static TraceId traceId() {
    return traceIdOf(IdGenerator.generateTraceId());
  }

  /// Creates a TraceId from the specified bytes.
  ///
  /// @param traceId The bytes for the trace ID (must be exactly 16 bytes)
  /// @return A new TraceId instance
  /// @throws ArgumentError if traceId is not exactly 16 bytes
  static TraceId traceIdOf(Uint8List traceId) {
    _getAndCacheOtelFactory();
    if (traceId.length != TraceId.traceIdLength) {
      throw ArgumentError(
          'Trace ID must be exactly ${TraceId.traceIdLength} bytes, got ${traceId.length} bytes');
    }
    return OTelFactory.otelFactory!.traceId(traceId);
  }

  /// Creates a TraceId from a hex string.
  ///
  /// @param hexString Hexadecimal representation of the trace ID
  /// @return A new TraceId instance
  static TraceId traceIdFrom(String hexString) {
    return OTelAPI.traceIdFrom(hexString);
  }

  /// Creates an invalid TraceId (all zeros).
  ///
  /// @return An invalid TraceId instance
  static TraceId traceIdInvalid() {
    return traceIdOf(TraceId.invalidTraceIdBytes);
  }

  /// Generates a new random SpanId.
  ///
  /// @return A new random SpanId
  static SpanId spanId() {
    return spanIdOf(IdGenerator.generateSpanId());
  }

  /// Creates a SpanId from the specified bytes.
  ///
  /// @param spanId The bytes for the span ID (must be exactly 8 bytes)
  /// @return A new SpanId instance
  /// @throws ArgumentError if spanId is not exactly 8 bytes
  static SpanId spanIdOf(Uint8List spanId) {
    _getAndCacheOtelFactory();
    if (spanId.length != 8) {
      throw ArgumentError(
          'Span ID must be exactly 8 bytes, got ${spanId.length} bytes');
    }
    return _otelFactory!.spanId(spanId);
  }

  /// Creates a SpanId from a hex string.
  ///
  /// @param hexString Hexadecimal representation of the span ID
  /// @return A new SpanId instance
  static SpanId spanIdFrom(String hexString) {
    return OTelAPI.spanIdFrom(hexString);
  }

  /// Creates an invalid SpanId (all zeros).
  ///
  /// @return An invalid SpanId instance
  static SpanId spanIdInvalid() {
    return spanIdOf(SpanId.invalidSpanIdBytes);
  }

  /// Creates a SpanLink with the specified SpanContext and optional attributes.
  ///
  /// SpanLinks are used to associate spans that may be causally related
  /// but not via a parent-child relationship.
  ///
  /// @param spanContext The SpanContext to link to
  /// @param attributes Optional attributes to associate with the link
  /// @return A new SpanLink instance
  static SpanLink spanLink(SpanContext spanContext, {Attributes? attributes}) {
    _getAndCacheOtelFactory();
    return _otelFactory!.spanLink(spanContext, attributes: attributes);
  }

  /// Retrieves and caches the OTelFactory instance.
  ///
  /// @return The OTelFactory instance
  /// @throws StateError if initialize() has not been called
  static OTelFactory _getAndCacheOtelFactory() {
    if (_otelFactory != null) {
      return _otelFactory!;
    }
    if (OTelFactory.otelFactory == null) {
      throw StateError('initialize() must be called first.');
    }
    return _otelFactory = OTelFactory.otelFactory! as OTelSDKFactory;
  }

  /// Initializes logging based on environment variables.
  ///
  /// This can be called separately from initialize(), but initialize() will
  /// call it automatically if not already done.
  static void initializeLogging() {
    // Initialize log settings from environment variables
    OTelEnv.initializeLogging();

    if (OTelLog.isDebug()) {
      OTelLog.debug('OTel logging initialized');
    }
  }

  /// Flushes and shuts down trace and metric providers,
  /// processors and exporters.  Typically called from [OTel.shutdown]
  static Future<void> shutdown() async {
    // Shutdown any tracer providers to clean up span processors
    try {
      final tracerProviders = OTel.tracerProviders();
      for (final tracerProvider in tracerProviders) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('OTel: Shutting down tracer providers');
        }
        if (tracerProvider is TracerProvider) {
          try {
            await tracerProvider.forceFlush();
            if (OTelLog.isDebug()) {
              OTelLog.debug('OTel: Tracer provider flush complete');
            }
          } catch (e) {
            if (OTelLog.isDebug()) {
              OTelLog.debug('OTel: Error during tracer provider flush: $e');
            }
          }
        }
        try {
          await tracerProvider.shutdown();
          if (OTelLog.isDebug()) {
            OTelLog.debug('OTel: Tracer provider shutdown complete');
          }
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug('OTel: Error during tracer provider shutdown: $e');
          }
        }
      }
    } catch (e) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTel: Error accessing tracer provider: $e');
      }
    }

    // Shutdown meter providers to clean up metric readers and exporters
    final meterProviders = OTel.meterProviders();
    for (var meterProvider in meterProviders) {
      try {
        if (OTelLog.isDebug()) {
          OTelLog.debug('OTel: Shutting down meter provider');
        }
        await meterProvider.shutdown();
        if (OTelLog.isDebug()) {
          OTelLog.debug('OTel: Meter provider shutdown complete');
        }
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('OTel: Error during meter provider shutdown: $e');
        }
      }
    }
  }

  /// Resets the OTel state for testing purposes.
  ///
  /// This method should only be used in tests to reset the state between test runs.
  /// It shuts down all tracer and meter providers and resets all static fields.
  ///
  /// @return A Future that completes when the reset is done
  @visibleForTesting
  static Future<void> reset() async {
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Resetting state');

    await shutdown();

    // Reset all static fields
    _otelFactory = null;
    _defaultSampler = null;
    defaultResource = null;
    dartasticApiKey = null;
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Reset static fields');

    // Reset API state
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      OTelAPI.reset();
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Reset OTelAPI');
    } catch (e) {
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Error resetting OTelAPI: $e');
    }

    // Reset OTelFactory
    OTelFactory.otelFactory = null;
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Reset OTelFactory');

    // Clear test environment to prevent test pollution
    EnvironmentService.instance.clearTestEnvironment();
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Cleared test environment');

    // Add a short delay to ensure resources are released
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Reset complete');
  }

  /// Creates a new InstrumentationScope.
  ///
  /// [name] is required and represents the instrumentation scope name (e.g. 'io.opentelemetry.contrib.mongodb')
  /// [version] is optional and specifies the version of the instrumentation scope, defaults to '1.0.0'
  /// [schemaUrl] is optional and specifies the Schema URL
  /// [attributes] is optional and specifies instrumentation scope attributes
  static InstrumentationScope instrumentationScope(
      {required String name,
      String version = '1.0.0',
      String? schemaUrl,
      Attributes? attributes}) {
    return OTelAPI.instrumentationScope(
        name: name,
        version: version,
        schemaUrl: schemaUrl,
        attributes: attributes);
  }
}
