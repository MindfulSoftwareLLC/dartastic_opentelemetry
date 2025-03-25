// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:typed_data';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:meta/meta.dart';
import 'package:opentelemetry_api/opentelemetry_api.dart';

/// The [OTel] is the OpenTelemettry SDK entrypoint.
/// The [initialize] method must be called first. Internally it sets the
/// [OTelFactory] to [OTelSDKFactory].
/// The rest of the methods act like factory constructors for OTel classes.
class OTel {
  static OTelSDKFactory? _otelFactory;
  static Sampler? _defaultSampler;
  static Resource? defaultResource;
  static String?
      dartasticApiKey; //TODO - just API key or add headers for apiKey?
  static const defaultServiceName = "@dart/dartastic_opentelemetry";
  static const String _defaultTracerName = 'dartastic';
  static String defaultTracerName = _defaultTracerName;
  static String? defaultTracerVersion;

  /// The [initialize] method must be called before any other methods to
  /// install the SDK.
  ///
  /// The global default TracerProvider and it's tracers will use the provided
  /// parameters.
  /// [endpoint] is a url, defaulting to http://localhost:4317, the default port
  /// for the default gRPC protocol on a localhost.
  /// [serviceName] SHOULD uniquely identify the instrumentation scope, such as
  /// the instrumentation library (e.g. @dart/opentelemetry_api),
  /// package, module or class name.
  /// [serviceVersion] defaults to the matching OTel spec version
  /// plus a release version of this library, currently  1.11.0.0
  /// [tracerName] the name of the default tracer for the global Tracer provider
  /// it defaults to 'dartastic' but should be set to something app-specific.
  /// [tracerVersion] the version of the default tracer for the global Tracer
  /// provider.  Defaults to null.
  /// [resourceAttributes] Resource attributes added to [TracerProvider]s.
  /// The tenant_id and the resources from [detectPlatformResources] are merged
  /// with [resourceAttributes] with [resourceAttributes] taking priority.
  /// The values must be valid Attribute types (String, bool, int, double, or
  /// List\<String>, List\<bool>, List\<int> or List\<double>).
  /// [dartasticApiKey] for Dartastic.io users, the dartastic.io ApiKey
  /// [tenantId] the standard tenantId, for Dartastic.io users this must match
  /// the tenantId for the dartasticApiKey.
  /// [spanProcessor] The SpanProcessor to add to the defaultTracerProvider.
  /// If null, the following batch span processor and OTLP gRPC exporter is
  /// created and added to the default TracerProvider
  /// ```
  //       final exporter = OtlpGrpcSpanExporter(
  //         OtlpGrpcExporterConfig(
  //           endpoint: endpoint,
  //           insecure: true,
  //         ),
  //       );
  //       final spanProcessor = BatchSpanProcessor(
  //         exporter,
  //         BatchSpanProcessorConfig(
  //           maxQueueSize: 2048,
  //           scheduleDelay: Duration(seconds: 1),
  //           maxExportBatchSize: 512,
  //         ),
  //       );
  //       OTel.tracerProvider().addSpanProcessor(spanProcessor);
  /// ```
  /// [sampler] is the sampling strategy to use. Defaults to AlwaysOnSampler.
  /// [spanKind] is the default SpanKind to use. The OTel default is
  /// SpanKind.internal.  This defaults the SpanKind to SpanKind.server.
  /// Note that Flutterrific OTel defaults to SpanKind.client
  /// [detectPlatformResources] whether or not to detect platform resources,
  /// Defaults to true.  If set to false, as of this release, there's no need
  /// to await this initialize call, though this may change a future release.
  ///   os.type: 'android|ios|macos|linux|windows' (from Platform.isXXX)
  ///   os.version: io.Platform.operatingSystemVersion
  ///   process.executable.name: io.Platform.executable
  ///   process.command_line: io.Platform.executableArguments.join(' ')
  ///   process.runtime.name: dart
  ///   process.runtime.version: io.Platform.version
  ///   process.num_threads: io.Platform.numberOfProcessors.toString()
  ///   host.name: io.Platform.localHostname,
  ///   host.arch: io.Platform.localHostname,
  ///   host.processors: io.Platform.numberOfProcessors,
  ///   host.os.name: io.Platform.operatingSystem,
  ///   host.locale: io.Platform.localeName,
  /// [otelLogger] An OTel logger for debugging and testing that that writes
  /// logs and signals to provided functions (debugPrint by default)
  /// [otelFactoryCreationFunction] defaults to a function that constructs
  /// the OTelSDKFactory. A factory method is required for serialization across
  /// execution contexts (isolates).
  static Future<void> initialize({
    String endpoint = OTelFactory.defaultEndpoint,
    bool secure = true,
    String serviceName = OTelFactory.defaultServiceName,
    String? serviceVersion = OTelFactory.defaultServiceVersion,
    String? tracerName,
    String? tracerVersion,
    Attributes? resourceAttributes,
    SpanProcessor? spanProcessor,
    Sampler? sampler,
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
    if (serviceVersion == null || serviceVersion.isEmpty) {
      throw ArgumentError(
          'serviceVersion must not be null or the empty string.');
    }
    final factoryFactory =
        oTelFactoryCreationFunction ?? otelSDKFactoryFactoryFunction;
    // Initialize with default sampler
    _defaultSampler = sampler ?? const AlwaysOnSampler();
    OTel.defaultTracerName = tracerName ?? _defaultTracerName;
    OTel.defaultTracerVersion = tracerVersion;
    OTel.dartasticApiKey = dartasticApiKey;
    OTelFactory.otelFactory = factoryFactory(
        apiEndpoint: endpoint,
        apiServiceName: serviceName,
        apiServiceVersion: serviceVersion);

    var serviceResourceAttributes = {
      'service.name': serviceName,
      'service.version': serviceVersion,
    };
    // Create initial resource with service attributes
    var baseResource = OTel.resource(OTel.attributesFromMap(serviceResourceAttributes));

    if (tenantId != null) {
      // Create a separate tenant_id resource to ensure it's preserved
      var tenantResource = OTel.resource(OTel.attributesFromMap({'tenant_id': tenantId}));
      if (OTelLog.isDebug()) OTelLog.debug('OTel.initialize: Creating tenant_id resource with: $tenantId');
      // Merge tenant into the base resource
      baseResource = baseResource.merge(tenantResource);
    }

    // Initialize with tenant-aware resource
    var mergedResource = baseResource;
    if (detectPlatformResources) {
      final resourceDetector = PlatformResourceDetector.create();
      var platformResource = await resourceDetector.detect();
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
          var tenantResource = OTel.resource(
              OTel.attributesFromMap({'tenant_id': tenantId}));
          OTel.defaultResource = OTel.defaultResource!.merge(tenantResource);
        }
      }
    }

    if (spanProcessor == null) {
      // Configure the exporter to use the same endpoint
      final exporter = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(
          endpoint: endpoint,
          insecure: !secure, //TODO change to secure
        ),
      );
      spanProcessor = BatchSpanProcessor(
        //TODO - flag console
        CompositeExporter([exporter, ConsoleExporter()]),
        BatchSpanProcessorConfig(
          maxQueueSize: 2048,
          scheduleDelay: Duration(seconds: 1),
          maxExportBatchSize: 512,
        ),
      );
    }

    // Create and configure TracerProvider
    OTel.tracerProvider().addSpanProcessor(spanProcessor);

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

  /// Create a [Resource] with the provided [Attributes] and [schemaUrl] //TODO Attributes optional
  static Resource resource(Attributes? attributes, [String? schemaUrl]) {
    _getAndCacheOtelFactory();
    return (_otelFactory as OTelSDKFactory)
        .resource(attributes ?? OTel.attributes(), schemaUrl);
  }

  /// Creates a new [ContextKey] with the given name.
  /// Each instance will be unique, even with the same name, per spec.
  /// The name is for debugging purposes only.
  static ContextKey<T> contextKey<T>(String name) {
    _getAndCacheOtelFactory();
    return _otelFactory!.contextKey(name, ContextKey.generateContextKeyId());
  }

  /// Creates a new [Context] with optional [Baggage]
  static Context context({Baggage? baggage, SpanContext? spanContext}) {
    _getAndCacheOtelFactory();
    var context = OTelFactory.otelFactory!.context(baggage: baggage);
    if (spanContext != null) {
      context = context.copyWithSpanContext(spanContext);
    }
    return context;
  }

  /// Gets a TracerProvider.  If name is null, this returns
  /// the global default [TracerProvider], which shares the
  /// endpoint, serviceName, serviceVersion, sampler and resource set in [intialize].
  /// If the name is not null, it returns a TracerProvider for the name
  /// that was added with addTracerProvider.
  /// The endpoint, serviceName, serviceVersion, sampler and resource set flow down
  /// to the [Tracer]s created by the TracerProvider and the [Span]
  /// created by those tracers
  static TracerProvider tracerProvider({String? name}) {
    var tracerProvider = OTelAPI.tracerProvider(name) as TracerProvider;

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

  /// Gets a MeterProvider.  If name is null, this returns
  /// the global default [MeterProvider], which shares the
  /// endpoint, serviceName, serviceVersion and resource set in [initialize].
  /// If the name is not null, it returns a MeterProvider for the name
  /// that was added with addMeterProvider.
  static MeterProvider meterProvider({String? name}) {
    var meterProvider = OTelAPI.meterProvider(name) as MeterProvider;
    meterProvider.resource ??= defaultResource;
    return meterProvider;
  }

  /// Adds or replaces a named tracer provider
  /// [endpoint] optionally use a different endpoint than global
  /// [serviceName] optionally override the default instrumentation scope name
  /// [serviceVersion] optionally override the default instrumentation scope version
  static TracerProvider addTracerProvider(
    String name, {
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    Resource? resource,
    Sampler? sampler,
  }) {
    var sdkTracerProvider = OTelAPI.addTracerProvider(name) as TracerProvider;
    sdkTracerProvider.resource = resource ?? defaultResource;
    sdkTracerProvider.sampler = sampler ?? _defaultSampler;
    return sdkTracerProvider;
  }

  /// Gets the default Tracer from the default TracerProvider.
  /// The endpoint, serviceName, serviceVersion, sampler and resource all
  /// flow down from the OTel defaults to the [Tracer]s created by the
  /// [TracerProvider] and the [Span]s created by those tracers
  static Tracer tracer() {
    return tracerProvider().getTracer(
      defaultTracerName,
      version: defaultTracerVersion,
    );
  }

  /// Adds or replaces a named meter provider
  /// [endpoint] optionally use a different endpoint than global
  /// [serviceName] optionally override the default instrumentation scope name
  /// [serviceVersion] optionally override the default instrumentation scope version
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

  /// Gets the default Meter from the default MeterProvider.
  /// The endpoint, serviceName, serviceVersion and resource all
  /// flow down from the OTel defaults to the [Meter]s created by the
  /// [MeterProvider].
  static Meter meter([String? name]) {
    return meterProvider().getMeter(
        name: name ?? defaultTracerName,
        version: defaultTracerVersion) as Meter;
  }

  /// The API MUST implement methods to create a SpanContext. These methods
  /// SHOULD be the only way to create a SpanContext. This functionality MUST be
  /// fully implemented in the API, and SHOULD NOT be overridable.
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

  /// Create a child SpanContext from a parent context
  static SpanContext spanContextFromParent(SpanContext parent) {
    _getAndCacheOtelFactory();
    return OTelFactory.otelFactory!.spanContextFromParent(parent);
  }

  /// Create an invalid [SpanContext] as required but the spec
  static SpanContext spanContextInvalid() {
    _getAndCacheOtelFactory();
    return OTelFactory.otelFactory!.spanContextInvalid();
  }

  static SpanEvent spanEventNow(String name, Attributes attributes) {
    _getAndCacheOtelFactory();
    return spanEvent(name, attributes, DateTime.now());
  }

  /// Creates a span event
  static SpanEvent spanEvent(String name,
      [Attributes? attributes, DateTime? timestamp]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.spanEvent(name, attributes, timestamp);
  }

  /// Creates an `Baggage` with the given `name` and `keyValuePairs` which
  /// are converted into `BaggeEntry`s without metadata.
  static Baggage baggageForMap(Map<String, String> keyValuePairs) {
    _getAndCacheOtelFactory();
    return _otelFactory!.baggageForMap(keyValuePairs);
  }

  /// Creates an `BaggageEntry` with the given `value` and optional `metadata`.
  static BaggageEntry baggageEntry(String value, [String? metadata]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.baggageEntry(value, metadata);
  }

  /// Creates an `Baggage` with the given `name` and `entries`.
  static Baggage baggage([Map<String, BaggageEntry>? entries]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.baggage(entries);
  }

  /// Creates a baggage instance from a JSON representation.
  static baggageFromJson(Map<String, dynamic> json) {
    return OTelAPI.baggageFromJson(json);
  }

  /// Create a string attribute key
  static Attribute<String> attributeString(String name, String value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeString(name, value);
  }

  /// Create a boolean attribute key
  static Attribute<bool> attributeBool(String name, bool value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeBool(name, value);
  }

  /// Create an integer attribute key
  static Attribute<int> attributeInt(String name, int value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeInt(name, value);
  }

  /// Create a double attribute key
  static Attribute<double> attributeDouble(String name, double value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeDouble(name, value);
  }

  /// Create a string list attribute key
  static Attribute<List<String>> attributeStringList(
      String name, List<String> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeStringList(name, value);
  }

  /// Create a boolean list attribute key
  static Attribute<List<bool>> attributeBoolList(
      String name, List<bool> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeBoolList(name, value);
  }

  /// Create an integer list attribute key
  static Attribute<List<int>> attributeIntList(String name, List<int> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeIntList(name, value);
  }

  /// Create a double list attribute key
  static Attribute<List<double>> attributeDoubleList(
      String name, List<double> value) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeDoubleList(name, value);
  }

  /// Creates an empty `Attributes` collection
  static Attributes createAttributes() {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributes();
  }

  /// Creates an `Attributes` collection from a list of [Attribute]s.
  static Attributes attributes([List<Attribute>? entries]) {
    // Cheating here since Attributes is unlikely to be overriden in a
    // factory and is often called before initialize
    return _otelFactory == null
        ? AttributesCreate.create(entries ?? [])
        : _otelFactory!.attributes(entries);
  }

  /// Creates an empty `Attributes` collection from a named set of values.
  /// Alternatively, consider using the toAttributes()
  /// extension on \<String, Map>{}.
  /// String, bool, int and double or Lists of those types get turned into
  /// the matching typed attribute.
  /// DateTime gets converted to an Attribute\<String> with the UTC time string.
  /// Attributes get added as-is (note - that would be unnecessary code)
  /// Anything else gets converted to an Attribute\<String> via its toString.
  static Attributes attributesFromMap(Map<String, Object> namedMap) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributesFromMap(namedMap);
  }

  static Attributes attributesFromList(List<Attribute> attributeList) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributesFromList(attributeList);
  }

  static TraceState traceState(Map<String, String>? entries) {
    _getAndCacheOtelFactory();
    return _otelFactory!.traceState(entries);
  }

  static TraceFlags traceFlags([int? flags]) {
    _getAndCacheOtelFactory();
    return _otelFactory!.traceFlags(flags ?? TraceFlags.NONE_FLAG);
  }

  static TraceId traceId() {
    return traceIdOf(IdGenerator.generateTraceId());
  }

  static TraceId traceIdOf(Uint8List traceId) {
    _getAndCacheOtelFactory();
    if (traceId.length != TraceId.traceIdLength) {
      throw ArgumentError(
          'Trace ID must be exactly ${TraceId.traceIdLength} bytes, got ${traceId.length} bytes');
    }
    return OTelFactory.otelFactory!.traceId(traceId);
  }

  /// Creates a new [TraceId] from a hex string
  static TraceId traceIdFrom(String hexString) {
    return OTelAPI.traceIdFrom(hexString);
  }

  /// Creates an invalid [Trace] (all zeros)
  static TraceId traceIdInvalid() {
    return traceIdOf(TraceId.invalidTraceIdBytes);
  }

  /// Generate a new random SpanId
  static SpanId spanId() {
    return spanIdOf(IdGenerator.generateSpanId());
  }

  /// SpanId of 8 bytes.
  static SpanId spanIdOf(Uint8List spanId) {
    _getAndCacheOtelFactory();
    if (spanId.length != 8) {
      throw ArgumentError(
          'Span ID must be exactly 8 bytes, got ${spanId.length} bytes');
    }
    return _otelFactory!.spanId(spanId);
  }

  /// SpanId of 8 bytes.
  static SpanId spanIdFrom(String hexString) {
    return OTelAPI.spanIdFrom(hexString);
  }

  /// Creates an invalid [SpanId] (all zeros)
  static SpanId spanIdInvalid() {
    return spanIdOf(SpanId.invalidSpanIdBytes);
  }

  static SpanLink spanLink(SpanContext spanContext, {Attributes? attributes}) {
    _getAndCacheOtelFactory();
    return _otelFactory!.spanLink(spanContext, attributes: attributes);
  }

  static OTelFactory _getAndCacheOtelFactory() {
    if (_otelFactory != null) {
      return _otelFactory!;
    }
    if (OTelFactory.otelFactory == null) {
      throw StateError('initialize() must be called first.');
    }
    return _otelFactory = OTelFactory.otelFactory! as OTelSDKFactory;
  }

  /// Reset API state (only public for testing)
  @visibleForTesting
  static Future<void> reset() async {
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Resetting state');

    // Shutdown any tracer providers to clean up span processors
    try {
      final tracerProvider = OTelAPI.tracerProvider() as TracerProvider;
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Shutting down tracer provider');
      try {
        await tracerProvider.forceFlush();
        if (OTelLog.isDebug()) OTelLog.debug('OTel: Tracer provider flush complete');
      } catch (e) {
        if (OTelLog.isDebug()) OTelLog.debug('OTel: Error during tracer provider flush: $e');
      }

      try {
        await tracerProvider.shutdown();
        if (OTelLog.isDebug()) OTelLog.debug('OTel: Tracer provider shutdown complete');
      } catch (e) {
        if (OTelLog.isDebug()) OTelLog.debug('OTel: Error during tracer provider shutdown: $e');
      }
    } catch (e) {
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Error accessing tracer provider: $e');
    }

    // Shutdown meter providers to clean up metric readers and exporters
    try {
      final meterProvider = OTelAPI.meterProvider() as MeterProvider;
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Shutting down meter provider');
      await meterProvider.shutdown();
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Meter provider shutdown complete');
    } catch (e) {
      if (OTelLog.isDebug()) OTelLog.debug('OTel: Error during meter provider shutdown: $e');
    }

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

    // Add a short delay to ensure resources are released
    await Future.delayed(Duration(milliseconds: 250));
    if (OTelLog.isDebug()) OTelLog.debug('OTel: Reset complete');
  }
}
