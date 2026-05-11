// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

import '../dartastic_opentelemetry.dart';

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
  /// Cached factory reference. Typed as the base `OTelFactory` because
  /// pre-`OTel.initialize`, the API layer's lazy-noop default
  /// (`OTelAPIFactory`) is what's installed — and that is NOT an
  /// `OTelSDKFactory`. SDK-specific factory methods (e.g.
  /// `OTelSDKFactory.resource(...)`) are accessed at their call sites
  /// with explicit casts; methods that exist on the base interface
  /// (`contextKey`, `attributes`, `spanEvent`, etc.) work uniformly on
  /// both API and SDK factories.
  static OTelFactory? _otelFactory;
  static Sampler? _defaultSampler;
  static TimeProvider? _defaultTimeProvider;

  /// Tracks whether [initialize] has been called explicitly. Distinct
  /// from "is a factory installed" — the API layer's
  /// `_getAndCacheOtelFactory` auto-installs a noop factory on first
  /// access per the OTel spec ("in the absence of an installed SDK,
  /// the Trace API is a 'no-op' API"). That auto-install does NOT count
  /// as SDK initialization, so a subsequent [initialize] call legitimately
  /// upgrades from noop to a real SDK factory exactly once.
  static bool _userInitialized = false;

  /// Whether [initialize] has been called explicitly. Returns `false` if
  /// only the auto-installed noop default is in place (the spec-compliant
  /// pre-initialization state). Useful for library code that owns its
  /// own initialization and wants to guard against double-init without
  /// try/catch.
  static bool get isInitialized => _userInitialized;

  /// Cached late-binding proxy providers — one per (signal, name)
  /// pair. These are what callers receive from [tracerProvider] /
  /// [meterProvider] / [loggerProvider]; they re-resolve to the
  /// current underlying real provider on every call, so a reference
  /// captured pre-`initialize` keeps working post-init. Identity is
  /// stable across `initialize`; cleared only on [reset].
  static final Map<String?, LateBindingTracerProvider>
      _proxyTracerProviders = {};
  static final Map<String, LateBindingTracer> _proxyTracers = {};
  static LateBindingMeterProvider? _proxyMeterProvider;
  static LateBindingLoggerProvider? _proxyLoggerProvider;
  static final Map<String, LateBindingLogger> _proxyLoggers = {};

  /// Cached noop SDK wrappers around the API noop factory's providers
  /// — what [internalResolveRealTracerProvider] (and the meter / logger
  /// equivalents) hand back when no SDK factory has been installed yet.
  /// Cached so identity is stable during the pre-init window; cleared
  /// on [initialize] (the real factory replaces them) and [reset].
  static final Map<String?, TracerProvider> _noopSdkTracerProviders = {};
  static MeterProvider? _noopSdkMeterProvider;
  static LoggerProvider? _noopSdkLoggerProvider;

  /// Identity-tracked sets of providers that have already had the OTel
  /// defaults (resource, sampler, timeProvider) applied. Each provider
  /// — whether the SDK noop wrapper installed pre-init or the real SDK
  /// provider installed by `initialize` — gets defaults exactly once.
  /// Without this, applying defaults on every [internalResolveRealXxx]
  /// call would silently overwrite user mutations (e.g. setting
  /// `provider.resource = null` to test ensureResourceIsSet would be
  /// reverted before the next access).
  static final Set<TracerProvider> _tracerProvidersWithDefaults =
      Set.identity();
  static final Set<MeterProvider> _meterProvidersWithDefaults = Set.identity();
  static final Set<LoggerProvider> _loggerProvidersWithDefaults =
      Set.identity();

  /// Whether print interception is enabled (set via initialize).
  static bool _logPrintEnabled = false;

  /// OTelLogger name for print interception (set via initialize).
  static String _logPrintLoggerName = 'dart.print';

  /// Lazily initialized DartLogBridge for print interception.
  static DartLogBridge? _logBridge;

  /// Lazily initialized zone specification for print interception.
  static ZoneSpecification? _printInterceptionZoneSpec;

  /// Default resource for the SDK.
  ///
  /// This is set during initialization and used by tracer and meter providers
  /// that don't have a specific resource set.
  static Resource? defaultResource;

  /// API key for Dartastic.io backend, if used.
  static String? dartasticApiKey;

  /// Default service name used if none is provided.
  static const defaultServiceName = '@dart/dartastic_opentelemetry';

  /// Default OTEL endpoint.
  ///
  /// Defaults to the OTLP/HTTP port (4318) since http/protobuf is the default
  /// protocol per the OpenTelemetry specification. When using gRPC, override
  /// this with port 4317.
  static const defaultEndpoint = 'http://localhost:4318';

  /// Default tracer name used if none is provided.
  static const String _defaultTracerName = 'dartastic';

  /// Default tracer name that can be customized.
  static String defaultTracerName = _defaultTracerName;

  /// Default tracer version.
  static String defaultTracerVersion = '1.0.0';

  /// Initializes the OpenTelemetry SDK with the specified configuration.
  ///
  /// This method must be called before any other OpenTelemetry operations.
  /// It sets up the global configuration and installs the SDK implementation.
  ///
  /// When OTelLog.debug is true or the environmental variable
  /// OTEL_CONSOLE_EXPORTER is set to true, a ConsoleExporter is added to the
  /// exports to print spans.
  ///
  /// @param endpoint The endpoint URL for the OpenTelemetry collector (default: http://localhost:4318)
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
  /// @param enableLogs Whether to enable logs collection and auto-configure exporter (default: true).
  ///   When enabled, the logs exporter is configured based on OTEL_LOGS_EXPORTER env var.
  /// @param logRecordExporter Custom log record exporter (overrides OTEL_LOGS_EXPORTER)
  /// @param logRecordProcessor Custom log record processor (overrides auto-configuration)
  /// @param dartasticApiKey API key for Dartastic.io backend
  /// @param tenantId Tenant ID for multi-tenant backends (required for Dartastic.io)
  /// @param detectPlatformResources Whether to detect platform resources (default: true)
  /// @param logPrint Whether to intercept print() calls and route them to OTel logs (default: false).
  ///   When enabled, all print() calls within [runWithPrintInterception] will be captured
  ///   as INFO level logs. Set to true to automatically bridge print statements to OpenTelemetry.
  /// @param logPrintLoggerName OTelLogger name for print-intercepted logs (default: 'dart.print')
  /// @param timeProvider Clock used for span start, end, and event timestamps.
  ///   When omitted, defaults to the platform-aware `defaultTimeProvider`:
  ///   `SystemTimeProvider` (`DateTime.now`, microsecond floor) on native;
  ///   `WebTimeProvider` (`window.performance.now()` + `timeOrigin`, sub-
  ///   millisecond) on Dart-on-JS web and Wasm — so web users pick up sub-
  ///   ms span timing automatically with no opt-in. Pass a custom provider
  ///   only to override the platform default, e.g. a fake clock in tests.
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
    bool enableLogs = true,
    LogRecordExporter? logRecordExporter,
    LogRecordProcessor? logRecordProcessor,
    String? dartasticApiKey,
    String? tenantId,
    bool detectPlatformResources = true,
    bool logPrint = false,
    String logPrintLoggerName = 'dart.print',
    TimeProvider? timeProvider,
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
          'Using service version from environment: $serviceVersion',
        );
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
    if (_userInitialized) {
      throw StateError(
        'OTelAPI can only be initialized once. If you need multiple endpoints or service names or versions create a named TracerProvider',
      );
    }

    if (endpoint.isEmpty) {
      throw ArgumentError(
        'endpoint must not be the empty string.',
      ); //TODO validate url
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
    _defaultTimeProvider = timeProvider;
    OTel.defaultTracerName = tracerName ?? _defaultTracerName;
    OTel.defaultTracerVersion = tracerVersion ?? defaultTracerVersion;
    OTel.dartasticApiKey = dartasticApiKey;
    // Initialize logging from environment variables if needed
    initializeLogging();

    // Replaces whatever's installed — including the lazy noop default
    // that `_getAndCacheOtelFactory` may have installed on a pre-init
    // API access. The `_userInitialized` flag (not the factory pointer)
    // gates double-initialization.
    OTelFactory.otelFactory = factoryFactory(
      apiEndpoint: endpoint,
      apiServiceName: serviceName,
      apiServiceVersion: serviceVersion,
    );
    _userInitialized = true;
    // Refresh the local SDK factory cache so SDK-specific casts (e.g.
    // `OTel.resource` -> `_otelFactory as OTelSDKFactory`) hit the
    // freshly-installed real factory rather than the stale API noop
    // that any pre-init access may have cached.
    _otelFactory = OTelFactory.otelFactory;
    // Drop any noop SDK wrappers that were issued pre-init; the
    // late-binding proxies will re-resolve to real SDK providers
    // backed by the new SDK factory on their next call. The proxy
    // instances themselves are intentionally NOT cleared — captured
    // pre-init references must keep working after init.
    _noopSdkTracerProviders.clear();
    _noopSdkMeterProvider = null;
    _noopSdkLoggerProvider = null;
    // Forget that the (now-discarded) noop wrappers had defaults
    // applied so the real SDK providers get their defaults applied on
    // the next resolve. Real providers stay in the set until [reset].
    _tracerProvidersWithDefaults.clear();
    _meterProvidersWithDefaults.clear();
    _loggerProvidersWithDefaults.clear();

    if (OTelLog.isDebug()) {
      OTelLog.debug(
        'OTel initialized with endpoint: $endpoint, service: $serviceName',
      );
    }

    final serviceResourceAttributes = {
      'service.name': serviceName,
      'service.version': serviceVersion,
    };
    // Create initial resource with service attributes
    var baseResource = OTel.resource(
      OTel.attributesFromMap(serviceResourceAttributes),
    );

    if (tenantId != null) {
      // Create a separate tenant_id resource to ensure it's preserved
      final tenantResource = OTel.resource(
        OTel.attributesFromMap({'tenant_id': tenantId}),
      );
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'OTel.initialize: Creating tenant_id resource with: $tenantId',
        );
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
        var hasTenantId = false;
        OTel.defaultResource!.attributes.toList().forEach((attr) {
          if (attr.key == 'tenant_id') {
            hasTenantId = true;
            if (OTelLog.isDebug()) {
              OTelLog.debug(
                'Final resource check - tenant_id is present: ${attr.value}',
              );
            }
          }
        });

        if (!hasTenantId) {
          // As a last resort, add the tenant_id directly
          if (OTelLog.isDebug()) {
            OTelLog.debug('tenant_id was missing - adding it as fallback');
          }
          final tenantResource = OTel.resource(
            OTel.attributesFromMap({'tenant_id': tenantId}),
          );
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
            // http/protobuf (default) or http/json (opt-in via env-var).
            // Anything else falls back to http/protobuf — the spec-
            // recommended default per `specification/protocol/exporter.md`.
            final httpProtocol = otlpHttpProtocolFromString(protocol) ??
                OtlpHttpProtocol.httpProtobuf;
            exporter = OtlpHttpSpanExporter(
              OtlpHttpExporterConfig(
                endpoint: endpoint,
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
                protocol: httpProtocol,
              ),
            );
          }
        } else {
          // Fallback to gRPC for backward compatibility
          exporter = OtlpGrpcSpanExporter(
            OtlpGrpcExporterConfig(endpoint: endpoint, insecure: !secure),
          );
        }

        // Only add ConsoleExporter in debug mode or if explicitly requested
        final exporters = <SpanExporter>[exporter];
        if (OTelLog.isDebug() ||
            const bool.fromEnvironment(
              'OTEL_CONSOLE_EXPORTER',
              defaultValue: false,
            )) {
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

    // Configure logs if enabled
    if (enableLogs) {
      LogsConfiguration.configureLoggerProvider(
        endpoint: endpoint,
        secure: secure,
        logRecordExporter: logRecordExporter,
        logRecordProcessor: logRecordProcessor,
        resource: OTel.defaultResource,
      );
    }

    // Store print interception configuration (lazily initialized when needed)
    _logPrintEnabled = logPrint;
    _logPrintLoggerName = logPrintLoggerName;

    if (logPrint && OTelLog.isDebug()) {
      OTelLog.debug(
          'OTel: Print interception enabled with logger: $logPrintLoggerName');
    }
  }

  /// Ensures the print interception bridge is initialized.
  /// Called lazily when runWithPrintInterception is first used.
  static void _ensurePrintInterceptionInitialized() {
    if (_logBridge != null) return;

    final logger = OTel.logger(_logPrintLoggerName);
    _logBridge = DartLogBridge.install(
      logger,
      minimumSeverity: Severity.TRACE,
    );
    _printInterceptionZoneSpec = _logBridge!.createZoneSpecification();

    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'OTel: Print interception bridge initialized with logger: $_logPrintLoggerName');
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
    return (_otelFactory as OTelSDKFactory).resource(
      attributes ?? OTel.attributes(),
      schemaUrl,
    );
  }

  /// Creates a new ContextKey with the given name.
  ///
  /// Context keys are used to store and retrieve values in a Context.
  /// Each instance will be unique, even with the same name, per the OTel spec.
  /// The name is for debugging purposes only.
  ///
  /// @param name The name of the context key (for debugging only)
  /// @param isTransferable When `true`, values stored under this key transfer
  ///   across isolate boundaries via `Context.runIsolate()`. Defaults to `false`
  ///   (custom keys are local to their isolate). Built-in `Baggage` and
  ///   `SpanContext` always transfer regardless of this flag.
  /// @return A new ContextKey instance
  static ContextKey<T> contextKey<T>(String name,
      {bool isTransferable = false}) {
    _getAndCacheOtelFactory();
    return _otelFactory!.contextKey<T>(
      name,
      ContextKey.generateContextKeyId(),
      isTransferable: isTransferable,
    );
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
  /// created by those tracers.
  ///
  /// Returns a [LateBindingTracerProvider] proxy whose identity is stable
  /// across `OTel.initialize`. Each method/getter/setter on the returned
  /// proxy resolves to the current underlying SDK provider — a noop SDK
  /// wrapper around the API noop factory pre-init, the real SDK provider
  /// post-init. This means library code that captures
  /// `OTel.tracerProvider()` at module load (Genkit-style) continues to
  /// work after a later `OTel.initialize` without re-fetching.
  ///
  /// @param name Optional name of a specific TracerProvider
  /// @return The TracerProvider instance (a late-binding proxy)
  static TracerProvider tracerProvider({String? name}) {
    return _proxyTracerProviders.putIfAbsent(
      name,
      () => LateBindingTracerProvider(name),
    );
  }

  /// Internal: resolve the current real (non-proxy) [TracerProvider] for
  /// the named provider. Used by [LateBindingTracerProvider] and
  /// [LateBindingTracer] to forward calls to whatever provider is
  /// installed *right now* — the SDK factory's provider post-init, or a
  /// cached SDK noop wrapper pre-init. Defaults (resource, sampler,
  /// timeProvider) are applied exactly once per provider instance
  /// (tracked via [_tracerProvidersWithDefaults]). Not part of the
  /// public API.
  @internal
  static TracerProvider internalResolveRealTracerProvider(String? name) {
    final apiTp = OTelAPI.tracerProvider(name);
    final tp = apiTp is TracerProvider
        ? apiTp
        : _noopSdkTracerProviders.putIfAbsent(
            name,
            () => SDKTracerProviderCreate.create(delegate: apiTp),
          );
    if (_tracerProvidersWithDefaults.add(tp)) {
      _applyTracerProviderDefaults(tp);
    }
    return tp;
  }

  /// Internal: get-or-create a cached [LateBindingTracer] proxy for the
  /// given identifying tuple. Called by [LateBindingTracerProvider.getTracer].
  /// Cache key matches the underlying SDK [TracerProvider.getTracer]
  /// (`name:version`) so the first call's `schemaUrl` / `attributes` /
  /// `sampler` win for the lifetime of the cached entry. Not part of
  /// the public API.
  @internal
  static LateBindingTracer internalGetCachedLateBindingTracer({
    required String? providerName,
    required String name,
    String? version,
    String? schemaUrl,
    Attributes? attributes,
    Sampler? sampler,
  }) {
    final key = '${providerName ?? ''}|$name|${version ?? ''}';
    return _proxyTracers.putIfAbsent(
      key,
      () => LateBindingTracer(
        providerName: providerName,
        name: name,
        version: version,
        schemaUrl: schemaUrl,
        attributes: attributes,
        sampler: sampler,
      ),
    );
  }

  /// Applies the OTel defaults (resource, sampler, timeProvider) to a
  /// freshly-resolved real TracerProvider. Idempotent — every getter
  /// uses null-or-default semantics so repeated calls are a no-op.
  static void _applyTracerProviderDefaults(TracerProvider tp) {
    if (tp.resource == null && defaultResource != null) {
      tp.resource = defaultResource;
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
    tp.sampler ??= _defaultSampler;
    if (_defaultTimeProvider != null) {
      tp.timeProvider = _defaultTimeProvider!;
    }
  }

  /// Gets a MeterProvider for creating Meters.
  ///
  /// Returns a [LateBindingMeterProvider] proxy — see [tracerProvider]
  /// for the late-binding rationale. Pre-init the proxy resolves to a
  /// noop SDK MeterProvider wrapper; post-init it resolves to the real
  /// SDK provider installed by `OTel.initialize`. Named MeterProviders
  /// are not yet supported via the late-binding path; pass [name] to
  /// fall back to the legacy direct-return behavior.
  ///
  /// @param name Optional name of a specific MeterProvider
  /// @return The MeterProvider instance
  static MeterProvider meterProvider({String? name}) {
    if (name != null) {
      // Named providers fall back to the legacy direct-return pattern.
      // Late binding for named meter providers can be added if a
      // concrete consumer needs it.
      final apiMp = OTelAPI.meterProvider(name);
      final mp = apiMp is MeterProvider
          ? apiMp
          : SDKMeterProviderCreate.create(delegate: apiMp);
      mp.resource ??= defaultResource;
      return mp;
    }
    return _proxyMeterProvider ??= LateBindingMeterProvider();
  }

  /// Internal: resolve the current real (non-proxy) [MeterProvider].
  /// Used by [LateBindingMeterProvider] to forward calls. Defaults
  /// (resource) are applied exactly once per provider instance —
  /// tracked via [_meterProvidersWithDefaults] so user mutations stick.
  /// Not part of the public API.
  @internal
  static MeterProvider internalResolveRealMeterProvider() {
    final apiMp = OTelAPI.meterProvider();
    final mp = apiMp is MeterProvider
        ? apiMp
        : (_noopSdkMeterProvider ??=
            SDKMeterProviderCreate.create(delegate: apiMp));
    if (_meterProvidersWithDefaults.add(mp)) {
      mp.resource ??= defaultResource;
    }
    return mp;
  }


  /// Adds or replaces a named TracerProvider.
  ///
  /// This allows for creating multiple TracerProviders with different configurations,
  /// which can be useful for sending telemetry to different backends or with different
  /// settings.
  ///
  /// Returns a late-binding [TracerProvider] proxy keyed by [name] (the
  /// same one [tracerProvider] returns); the underlying SDK provider is
  /// created or replaced as a side effect, and the proxy resolves to it
  /// on subsequent calls.
  ///
  /// @param name The name of the TracerProvider
  /// @param endpoint Optional custom endpoint URL
  /// @param serviceName Optional custom service name
  /// @param serviceVersion Optional custom service version
  /// @param resource Optional custom resource
  /// @param sampler Optional custom sampler
  /// @return The newly created or replaced TracerProvider (a late-binding proxy)
  static TracerProvider addTracerProvider(
    String name, {
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    Resource? resource,
    Sampler? sampler,
  }) {
    final apiTp = OTelAPI.addTracerProvider(name);
    final sdkTracerProvider = apiTp is TracerProvider
        ? apiTp
        : (_noopSdkTracerProviders[name] ??=
            SDKTracerProviderCreate.create(delegate: apiTp));
    sdkTracerProvider.resource = resource ?? defaultResource;
    sdkTracerProvider.sampler = sampler ?? _defaultSampler;
    if (_defaultTimeProvider != null) {
      sdkTracerProvider.timeProvider = _defaultTimeProvider!;
    }
    return _proxyTracerProviders.putIfAbsent(
      name,
      () => LateBindingTracerProvider(name),
    );
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
  /// Returns a [LateBindingTracer] proxy — see [tracerProvider] for the
  /// rationale. The proxy identity stays stable across `OTel.initialize`,
  /// so a captured reference keeps producing real spans after init.
  ///
  /// @return The default Tracer instance (a late-binding proxy)
  static Tracer tracer() {
    return internalGetCachedLateBindingTracer(
      providerName: null,
      name: defaultTracerName,
      version: defaultTracerVersion,
    );
  }

  /// Activates [span] for the duration of [fn] (so `Context.current.span`
  /// returns it inside `fn`) and records any thrown exception with
  /// `SpanStatusCode.Error`. The caller is still responsible for
  /// `span.end()` — typically in a `finally` block.
  ///
  /// Convenience over `OTel.tracer().withSpan(span, fn)` for callers
  /// that don't already have a [Tracer] reference.
  static T withSpan<T>(APISpan span, T Function() fn) =>
      tracer().withSpan(span, fn);

  /// Async variant of [withSpan]. Propagates the active span across
  /// `await` boundaries via Zone-based context.
  static Future<T> withSpanAsync<T>(
    APISpan span,
    Future<T> Function() fn,
  ) =>
      tracer().withSpanAsync(span, fn);

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
    final apiMp = _otelFactory!.addMeterProvider(
      name,
      endpoint: endpoint,
      serviceName: serviceName,
      serviceVersion: serviceVersion,
    );
    final mp = apiMp is MeterProvider
        ? apiMp
        : SDKMeterProviderCreate.create(delegate: apiMp);
    mp.resource = resource ?? defaultResource;
    return mp;
  }

  /// @return the [MeterProvider]s, the global default and named ones.
  static List<APIMeterProvider> meterProviders() {
    return OTelAPI.meterProviders();
  }

  /// Gets the default Meter from the default MeterProvider.
  ///
  /// Returns the *real* SDK [Meter] (not a proxy) — resolved at call
  /// time from the current underlying [MeterProvider]. References
  /// captured pre-`OTel.initialize` will NOT auto-update across init;
  /// fetch the meter again after init if you need one. See
  /// `lib/src/metrics/late_binding_meter.dart` for the rationale on
  /// why metrics opts out of meter-level late binding (instruments
  /// hold `instrument.meter` back-references that must match the
  /// real Meter object).
  ///
  /// @param name Optional custom name for the meter (defaults to defaultTracerName)
  /// @return The default Meter instance (real, not proxied)
  static Meter meter([String? name]) {
    return internalResolveRealMeterProvider().getMeter(
      name: name ?? defaultTracerName,
      version: defaultTracerVersion,
    ) as Meter;
  }

  /// Gets a LoggerProvider for creating Loggers.
  ///
  /// Returns a [LateBindingLoggerProvider] proxy — see [tracerProvider]
  /// for the late-binding rationale. Named LoggerProviders fall back to
  /// the legacy direct-return pattern.
  ///
  /// @param name Optional name of a specific LoggerProvider
  /// @return The LoggerProvider instance
  static LoggerProvider loggerProvider({String? name}) {
    if (name != null) {
      final apiLp = OTelAPI.loggerProvider(name);
      final lp = apiLp is LoggerProvider
          ? apiLp
          : SDKLoggerProviderCreate.create(delegate: apiLp);
      lp.resource ??= defaultResource;
      return lp;
    }
    return _proxyLoggerProvider ??= LateBindingLoggerProvider();
  }

  /// Internal: resolve the current real (non-proxy) [LoggerProvider].
  /// Defaults (resource) applied exactly once per provider instance.
  @internal
  static LoggerProvider internalResolveRealLoggerProvider() {
    final apiLp = OTelAPI.loggerProvider();
    final lp = apiLp is LoggerProvider
        ? apiLp
        : (_noopSdkLoggerProvider ??=
            SDKLoggerProviderCreate.create(delegate: apiLp));
    if (_loggerProvidersWithDefaults.add(lp)) {
      lp.resource ??= defaultResource;
    }
    return lp;
  }

  /// Internal: get-or-create a cached [LateBindingLogger] proxy. Cache
  /// key matches the underlying SDK [LoggerProvider.getLogger]
  /// (`name:version`) so first-call `schemaUrl` / `attributes` win.
  @internal
  static LateBindingLogger internalGetCachedLateBindingLogger({
    required String name,
    String? version,
    String? schemaUrl,
    Attributes? attributes,
  }) {
    final key = '$name|${version ?? ''}';
    return _proxyLoggers.putIfAbsent(
      key,
      () => LateBindingLogger(
        name: name,
        version: version,
        schemaUrl: schemaUrl,
        attributes: attributes,
      ),
    );
  }

  /// Adds or replaces a named LoggerProvider.
  ///
  /// This allows for creating multiple LoggerProviders with different configurations,
  /// which can be useful for sending logs to different backends or with different
  /// settings.
  ///
  /// @param name The name of the LoggerProvider
  /// @param endpoint Optional custom endpoint URL
  /// @param serviceName Optional custom service name
  /// @param serviceVersion Optional custom service version
  /// @param resource Optional custom resource
  /// @return The newly created or replaced LoggerProvider
  static LoggerProvider addLoggerProvider(
    String name, {
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    Resource? resource,
  }) {
    _getAndCacheOtelFactory();
    final apiLp = _otelFactory!.addLogProvider(name,
        endpoint: endpoint,
        serviceName: serviceName,
        serviceVersion: serviceVersion);
    final lp = apiLp is LoggerProvider
        ? apiLp
        : SDKLoggerProviderCreate.create(delegate: apiLp);
    lp.resource = resource ?? defaultResource;
    return lp;
  }

  /// Gets the default OTelLogger from the default LoggerProvider.
  ///
  /// Returns a [LateBindingLogger] proxy — captured references survive
  /// `OTel.initialize`.
  ///
  /// @param name Optional custom name for the logger (defaults to defaultTracerName)
  /// @return The default OTelLogger instance (a late-binding proxy)
  static OTelLogger logger([String? name]) {
    return internalGetCachedLateBindingLogger(
      name: name ?? defaultTracerName,
      version: defaultTracerVersion,
    );
  }

  /// Whether print interception is enabled.
  ///
  /// Returns true if [initialize] was called with `logPrint: true`.
  static bool get isLogPrintEnabled => _logPrintEnabled;

  /// Gets the current DartLogBridge instance, if print interception is enabled.
  ///
  /// Returns null if print interception was not enabled during initialization.
  static DartLogBridge? get logBridge => _logBridge;

  /// Runs the given callback in a zone that intercepts print() calls.
  ///
  /// When [initialize] is called with `logPrint: true`, this method runs
  /// the callback in a zone where all `print()` calls are captured and
  /// routed to OpenTelemetry logs as INFO level messages.
  ///
  /// If print interception is not enabled, the callback is run directly
  /// without any interception.
  ///
  /// Example usage:
  /// ```dart
  /// await OTel.initialize(
  ///   serviceName: 'my-service',
  ///   logPrint: true,
  /// );
  ///
  /// OTel.runWithPrintInterception(() {
  ///   print('This will be captured as an OTel log');
  /// });
  /// ```
  ///
  /// @param callback The code to run with print interception
  /// @return The result of the callback
  static R runWithPrintInterception<R>(R Function() callback) {
    if (!_logPrintEnabled) {
      return callback();
    }
    _ensurePrintInterceptionInitialized();
    return runZoned(callback, zoneSpecification: _printInterceptionZoneSpec);
  }

  /// Runs the given async callback in a zone that intercepts print() calls.
  ///
  /// This is the async version of [runWithPrintInterception].
  ///
  /// @param callback The async code to run with print interception
  /// @return A Future containing the result of the callback
  static Future<R> runWithPrintInterceptionAsync<R>(
      Future<R> Function() callback) {
    if (!_logPrintEnabled) {
      return callback();
    }
    _ensurePrintInterceptionInitialized();
    return runZoned(callback, zoneSpecification: _printInterceptionZoneSpec);
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
  static SpanContext spanContext({
    TraceId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    TraceFlags? traceFlags,
    TraceState? traceState,
    bool? isRemote,
  }) {
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
  static SpanEvent spanEvent(
    String name, [
    Attributes? attributes,
    DateTime? timestamp,
  ]) {
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
    String name,
    List<String> value,
  ) {
    _getAndCacheOtelFactory();
    return _otelFactory!.attributeStringList(name, value);
  }

  /// Creates a boolean list attribute.
  ///
  /// @param name The name of the attribute
  /// @param value The list of boolean values
  /// @return A new Attribute instance
  static Attribute<List<bool>> attributeBoolList(
    String name,
    List<bool> value,
  ) {
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
    String name,
    List<double> value,
  ) {
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

  /// Creates an [Attributes] from a map keyed by [OTelSemantic] enum values
  /// (e.g. `HttpResource.requestMethod`). Each enum's `.key` is used as the
  /// attribute name. Lets you write
  ///
  /// ```dart
  /// OTel.attributesFromSemanticMap({
  ///   HttpResource.requestMethod: 'GET',
  ///   HttpResource.responseStatusCode: 200,
  /// })
  /// ```
  ///
  /// instead of `attributesFromMap({HttpResource.requestMethod.key: 'GET', …})`.
  /// Mixing enum types in one map is fine — the param is `Map<OTelSemantic, Object>`,
  /// and every semconv enum implements `OTelSemantic`.
  ///
  /// Passthrough to [OTelAPI.attributesFromSemanticMap] for symmetry with
  /// the [attributesFromMap] convenience.
  static Attributes attributesFromSemanticMap(
    Map<OTelSemantic, Object> semanticMap,
  ) {
    return OTelAPI.attributesFromSemanticMap(semanticMap);
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
        'Trace ID must be exactly ${TraceId.traceIdLength} bytes, got ${traceId.length} bytes',
      );
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
        'Span ID must be exactly 8 bytes, got ${spanId.length} bytes',
      );
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
    // Trigger the API's canonical lazy-install logic by calling its
    // `ensureFactoryInstalled` helper — installs the spec-mandated
    // noop API factory if no SDK factory has been registered yet.
    OTelAPI.ensureFactoryInstalled();
    // We cache whatever's installed — SDK factory or noop API factory.
    // SDK-specific factory methods (e.g. `OTelSDKFactory.resource(...)`)
    // are cast at their per-call-site boundaries; methods on the base
    // `OTelFactory` interface work uniformly.
    return _otelFactory = OTelFactory.otelFactory!;
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

    // Shut down all LoggerProviders — default plus any named ones added
    // via `OTel.addLoggerProvider(name)`. Without this, each provider's
    // BatchLogRecordProcessor `Timer.periodic` keeps the Dart isolate
    // alive after `main()` returns, so short-lived CLI binaries hang
    // indefinitely after `await OTel.shutdown()` (issue #33).
    //
    // Note: enumeration relies on `OTelAPI.loggerProviders()`, added in
    // API `1.0.0-beta.4`. Earlier versions only had access to the default
    // provider, which is why beta.1 of this SDK left this as a documented
    // gap — closed here.
    try {
      final loggerProviders = OTelAPI.loggerProviders();
      for (final loggerProvider in loggerProviders) {
        try {
          if (OTelLog.isDebug()) {
            OTelLog.debug('OTel: Shutting down logger provider');
          }
          await loggerProvider.shutdown();
          if (OTelLog.isDebug()) {
            OTelLog.debug('OTel: Logger provider shutdown complete');
          }
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug('OTel: Error during logger provider shutdown: $e');
          }
        }
      }
    } catch (e) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTel: Error accessing logger providers: $e');
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
    _defaultTimeProvider = null;
    _userInitialized = false;
    _proxyTracerProviders.clear();
    _proxyTracers.clear();
    _proxyMeterProvider = null;
    _proxyLoggerProvider = null;
    _proxyLoggers.clear();
    _noopSdkTracerProviders.clear();
    _noopSdkMeterProvider = null;
    _noopSdkLoggerProvider = null;
    _tracerProvidersWithDefaults.clear();
    _meterProvidersWithDefaults.clear();
    _loggerProvidersWithDefaults.clear();
    defaultResource = null;
    dartasticApiKey = null;

    // Reset print interception state
    if (_logBridge != null) {
      DartLogBridge.uninstall();
    }
    _logBridge = null;
    _printInterceptionZoneSpec = null;
    _logPrintEnabled = false;
    _logPrintLoggerName = 'dart.print';
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
  static InstrumentationScope instrumentationScope({
    required String name,
    String version = '1.0.0',
    String? schemaUrl,
    Attributes? attributes,
  }) {
    return OTelAPI.instrumentationScope(
      name: name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: attributes,
    );
  }
}
