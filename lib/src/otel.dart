// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:typed_data';

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
/// The resources from platform resource detection are merged
/// with resource attributes with resource attributes taking priority.
/// The values must be valid Attribute types (String, bool, int, double, or
/// List\<String>, List\<bool>, List\<int> or List\<double>).
class OTel {
  static OTelSDKFactory? _otelFactory;
  static Sampler? _defaultSampler;
  static TimeProvider? _defaultTimeProvider;

  /// The global default exception handling options applied by the withSpan
  /// family of methods. Configured via `OTel.initialize(...)` and propagated
  /// to TracerProviders. Per-call `exceptionOptions` override this. Null
  /// until set by initialize(); the Tracer falls back to
  /// [SpanExceptionOptions.defaults] when unset.
  static SpanExceptionOptions? _defaultSpanExceptionOptions;

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

  /// Default service name used if none is provided.
  static const defaultServiceName = '@dart/dartastic_opentelemetry';

  /// Default OTEL endpoint.
  ///
  /// Defaults to the OTLP/HTTP port (4318) since http/protobuf is the default
  /// protocol per the OpenTelemetry specification. When using gRPC, this is
  /// replaced by [defaultGrpcEndpoint] (port 4317).
  static const defaultEndpoint = 'http://localhost:4318';

  /// Default OTLP/gRPC endpoint.
  ///
  /// Per the OpenTelemetry specification
  /// (specification/protocol/exporter.md#configuration-options), the default
  /// endpoint is `http://localhost:4317` for OTLP/gRPC and
  /// `http://localhost:4318` for the two HTTP protocols. The endpoint default
  /// is picked per signal after the protocol is resolved (issue #220).
  static const defaultGrpcEndpoint = 'http://localhost:4317';

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
  /// @param endpoint The endpoint URL for the OpenTelemetry collector (default: http://localhost:4318)
  /// @param secure Transport security for OTLP/gRPC when the endpoint carries
  ///   no scheme. This is the code equivalent of `OTEL_EXPORTER_OTLP_INSECURE`
  ///   (inverted - `secure: true` means `insecure=false`) and takes precedence
  ///   over it, per the spec rule that every environment variable has a direct
  ///   code configuration equivalent.
  ///
  ///   The option is deliberately narrow, per the OTLP exporter specification
  ///   (`protocol/exporter.md`, "Insecure"):
  ///
  ///   - **OTLP/HTTP ignores it entirely** - the endpoint's scheme always
  ///     decides, so `https://host:4318` is TLS and `http://host:4318` is not.
  ///   - **A scheme on the endpoint wins over this parameter.** The spec says
  ///     an `https` or `http` scheme "takes precedence over the `insecure`
  ///     configuration setting", so passing `secure: true` alongside
  ///     `http://host:4317` does not produce TLS.
  ///   - It therefore applies only to **OTLP/gRPC with a scheme-less
  ///     endpoint**, such as `my-collector:4317` - the native gRPC form, and
  ///     the one case where nothing else can express the choice.
  ///
  ///   Leave it null (the default) to let the endpoint scheme decide, then
  ///   `OTEL_EXPORTER_OTLP_INSECURE`, then the spec default. That default is
  ///   *secure*, but the default endpoint is `http://localhost:4317`, whose
  ///   scheme wins - so an unconfigured SDK talks plaintext to a local
  ///   collector, which is what you want for local development.
  /// @param serviceName Name that uniquely identifies the service (default: "@dart/dartastic_opentelemetry")
  /// @param serviceVersion Version of the service (defaults to the OTel spec version)
  /// @param tracerName Name of the default tracer (default: "dartastic")
  /// @param tracerVersion Version of the default tracer (default: null)
  /// @param resourceAttributes Additional attributes for the resource
  /// @param spanProcessor Custom span processor (default: BatchSpanProcessor with OtlpGrpcSpanExporter)
  /// @param sampler Sampling strategy to use (default: ParentBased(root=AlwaysOn) per the spec)
  /// @param spanKind Default span kind (default: SpanKind.server)
  /// @param metricExporter Custom metric exporter for metrics
  /// @param metricReader Custom metric reader for metrics
  /// @param enableMetrics Whether to enable metrics collection (default: true)
  /// @param enableLogs Whether to enable logs collection and auto-configure exporter (default: true).
  ///   When enabled, the logs exporter is configured based on OTEL_LOGS_EXPORTER env var.
  /// @param logRecordExporter Custom log record exporter (overrides OTEL_LOGS_EXPORTER)
  /// @param logRecordProcessor Custom log record processor (overrides auto-configuration)
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
    Sampler? sampler,
    SpanExceptionOptions spanExceptionOptions = const SpanExceptionOptions(),
    SpanKind spanKind = SpanKind.server,
    MetricExporter? metricExporter,
    MetricReader? metricReader,
    bool enableMetrics = true,
    bool enableLogs = true,
    LogRecordExporter? logRecordExporter,
    LogRecordProcessor? logRecordProcessor,
    bool detectPlatformResources = true,
    bool logPrint = false,
    String logPrintLoggerName = 'dart.print',
    List<String>? otlpHeaderLogAllowlist,
    TimeProvider? timeProvider,
    OTelFactoryCreationFunction? oTelFactoryCreationFunction =
        otelSDKFactoryFactoryFunction,
  }) async {
    // Has to run before anything logs OTLP headers.
    OTelEnv.applyHeaderLogAllowlist(otlpHeaderLogAllowlist);
    // Apply OTEL_LOG_LEVEL before the env parsing below emits its debug
    // output — otherwise an env-configured debug level misses exactly the
    // lines that diagnose env configuration.
    initializeLogging();

    final sdkDisabled = OTelEnv.isSdkDisabled();
    if (sdkDisabled && OTelLog.isDebug()) {
      OTelLog.debug('OTel: OTEL_SDK_DISABLED=true, skipping all signal setup');
    }

    // Apply environment variables exactly once
    final envServiceConfig = OTelEnv.getServiceConfig();
    const OtlpEnvironmentValues emptyOtlp = (
      endpoint: null,
      protocol: null,
      headers: null,
      insecure: null,
      timeout: null,
      compression: null,
      certificate: null,
      clientKey: null,
      clientCertificate: null
    );
    const BlrpEnvironmentValues emptyBlrp = (
      scheduleDelay: null,
      exportTimeout: null,
      maxQueueSize: null,
      maxExportBatchSize: null
    );
    const BspEnvironmentValues emptyBsp = (
      scheduleDelay: null,
      exportTimeout: null,
      maxQueueSize: null,
      maxExportBatchSize: null
    );

    final otlpTracesConfig =
        !sdkDisabled ? OTelEnv.getOtlpConfig(signal: 'traces') : emptyOtlp;
    final otlpMetricsConfig = enableMetrics && !sdkDisabled
        ? OTelEnv.getOtlpConfig(signal: 'metrics')
        : emptyOtlp;
    final otlpLogsConfig = enableLogs && !sdkDisabled
        ? OTelEnv.getOtlpConfig(signal: 'logs')
        : emptyOtlp;
    final tracesExporters = !sdkDisabled
        ? (OTelEnv.getExporters(signal: 'traces') ?? ['otlp'])
        : <String>[];
    final metricsExporters = enableMetrics && !sdkDisabled
        ? (OTelEnv.getExporters(signal: 'metrics') ?? ['otlp'])
        : <String>[];
    final logsExporters = enableLogs && !sdkDisabled
        ? (OTelEnv.getExporters(signal: 'logs') ?? ['otlp'])
        : <String>[];
    final blrpConfig =
        enableLogs && !sdkDisabled ? OTelEnv.getBlrpConfig() : emptyBlrp;
    final bspConfig = !sdkDisabled ? OTelEnv.getBspConfig() : emptyBsp;

    final envServiceName =
        serviceName == null ? envServiceConfig.serviceName : null;
    final envServiceVersion =
        serviceVersion == null ? envServiceConfig.serviceVersion : null;

    serviceName ??= envServiceName;
    serviceVersion ??= envServiceVersion;

    final envEndpoint = endpoint == null ? otlpTracesConfig.endpoint : null;
    final envInsecure = secure == null ? otlpTracesConfig.insecure : null;

    endpoint ??= envEndpoint;
    // Keep the caller's explicit choice (null when not given): the
    // metrics/logs configurations resolve security against their own
    // per-signal endpoints and env vars, so they must receive the
    // original parameter rather than the traces-resolved value (#253).
    final explicitSecure = secure;
    secure = OTelEnv.resolveOtlpSecure(
      explicitSecure: secure,
      envInsecure: envInsecure,
      endpoint: endpoint,
    );

    // Apply defaults if still null.
    serviceName ??= defaultServiceName;
    serviceVersion ??= '1.0.0';

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

    // The API auto-installs its OTelAPIFactory if API-only code runs
    // before the SDK initializes. The SDK must upgrade it to the SDK (per spec).
    final existingFactory = OTelFactory.otelFactory;
    if (existingFactory != null && !existingFactory.isAPIFactory) {
      throw StateError(
        'OTel.initialize() can only be called once. If you need multiple endpoints or service names or versions create a named TracerProvider',
      );
    }
    if (existingFactory != null && OTelLog.isDebug()) {
      OTelLog.debug(
        'OTel.initialize: replacing the auto-installed no-op API factory '
        'with the SDK factory. API objects obtained before initialize() '
        'remain no-ops.',
      );
    }

    if (endpoint != null && endpoint.isEmpty) {
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
    _defaultSampler = sampler ?? ParentBasedSampler(const AlwaysOnSampler());
    _defaultSpanExceptionOptions = spanExceptionOptions;
    _defaultTimeProvider = timeProvider;
    OTel.defaultTracerName = tracerName ?? _defaultTracerName;
    OTel.defaultTracerVersion = tracerVersion ?? defaultTracerVersion;

    final createdFactory = factoryFactory(
      apiEndpoint: endpoint ?? defaultEndpoint,
      apiServiceName: serviceName,
      apiServiceVersion: serviceVersion,
    );
    OTelFactory.otelFactory = createdFactory;
    if (createdFactory is OTelSDKFactory) {
      _otelFactory = createdFactory;
    }

    _installGlobalPropagator();

    if (OTelLog.isDebug()) {
      final traceProtocol = otlpTracesConfig.protocol ?? 'http/protobuf';
      OTelLog.debug(
        'OTel initialized with endpoint: '
        '${endpoint ?? (traceProtocol == 'grpc' ? defaultGrpcEndpoint : defaultEndpoint)}, '
        'service: $serviceName',
      );
    }

    // Initialize resource with correct precedence
    var mergedResource = OTel.resource(OTel.attributes());

    if (detectPlatformResources) {
      final resourceDetector = PlatformResourceDetector.create();
      final platformResource = await resourceDetector.detect();
      mergedResource = mergedResource.merge(platformResource);
    }

    // Always run EnvVarResourceDetector for OTEL_RESOURCE_ATTRIBUTES
    final envVarResource =
        await CompositeResourceDetector([EnvVarResourceDetector()]).detect();
    mergedResource = mergedResource.merge(envVarResource);

    // Apply OTEL_SERVICE_NAME (and VERSION) via service name variables
    final serviceResourceAttributes = {
      Service.serviceName.key: serviceName,
      Service.serviceVersion.key: serviceVersion,
    };
    mergedResource = mergedResource.merge(
        OTel.resource(OTel.attributesFromMap(serviceResourceAttributes)));

    // Finally, explicit programmatic arguments outrank everything
    if (resourceAttributes != null) {
      final initResources = OTel.resource(resourceAttributes);
      mergedResource = mergedResource.merge(initResources);
    }

    OTel.defaultResource = mergedResource;

    if (OTelLog.isDebug()) {
      OTelLog.debug('Final resource:');
      mergedResource.attributes.toList().forEach((attr) {
        if (attr.key == Service.serviceName.key) {
          OTelLog.debug('  ${attr.key}: ${attr.value}');
        }
      });
    }

    if (!sdkDisabled) {
      TracesConfiguration.configureTracerProvider(
        endpoint: endpoint,
        secure: secure,
        spanProcessor: spanProcessor,
        sampler: sampler,
        spanExceptionOptions: spanExceptionOptions,
        resource: OTel.defaultResource,
        otlpConfig: otlpTracesConfig,
        exporters: tracesExporters,
        bspConfig: bspConfig,
      );
    }

    if (enableMetrics && !sdkDisabled) {
      MetricsConfiguration.configureMeterProvider(
        endpoint: endpoint,
        secure: explicitSecure,
        metricExporter: metricExporter,
        metricReader: metricReader,
        resource: OTel.defaultResource,
        otlpConfig: otlpMetricsConfig,
        exporters: metricsExporters,
      );
    }

    if (enableLogs && !sdkDisabled) {
      LogsConfiguration.configureLoggerProvider(
        endpoint: endpoint,
        secure: explicitSecure,
        logRecordExporter: logRecordExporter,
        logRecordProcessor: logRecordProcessor,
        resource: OTel.defaultResource,
        otlpConfig: otlpLogsConfig,
        exporters: logsExporters,
        blrpConfig: blrpConfig,
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
  /// created by those tracers
  /// @param name Optional name of a specific TracerProvider
  /// @return The TracerProvider instance
  static TracerProvider tracerProvider({String? name}) {
    _getAndCacheOtelFactory();
    final tracerProvider = OTelAPI.tracerProvider(name) as TracerProvider;
    // Ensure the resource is properly set
    if (tracerProvider.resource == null && defaultResource != null) {
      tracerProvider.resource = defaultResource;
      if (OTelLog.isDebug()) {
        OTelLog.debug('OTel.tracerProvider: Setting resource from default');
        if (defaultResource != null) {
          defaultResource!.attributes.toList().forEach((attr) {
            if (attr.key == Service.serviceName.key) {
              OTelLog.debug('  ${attr.key}: ${attr.value}');
            }
          });
        }
      }
    }

    tracerProvider.sampler ??= _defaultSampler;
    tracerProvider.spanExceptionOptions ??= _defaultSpanExceptionOptions;
    if (_defaultTimeProvider != null) {
      tracerProvider.timeProvider = _defaultTimeProvider!;
    }
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
    _getAndCacheOtelFactory();
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
  /// @param spanExceptionOptions Optional default exception handling options;
  ///   defaults to the options set in initialize()
  /// @return The newly created or replaced TracerProvider
  static TracerProvider addTracerProvider(
    String name, {
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    Resource? resource,
    Sampler? sampler,
    SpanExceptionOptions? spanExceptionOptions,
  }) {
    _getAndCacheOtelFactory();
    final sdkTracerProvider = OTelAPI.addTracerProvider(name) as TracerProvider;
    sdkTracerProvider.resource = resource ?? defaultResource;
    sdkTracerProvider.sampler = sampler ?? _defaultSampler;
    sdkTracerProvider.spanExceptionOptions =
        spanExceptionOptions ?? _defaultSpanExceptionOptions;
    if (_defaultTimeProvider != null) {
      sdkTracerProvider.timeProvider = _defaultTimeProvider!;
    }
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

  /// Activates [span] for the duration of [fn] (so `Context.current.span`
  /// returns it inside `fn`) and records any thrown exception with
  /// `SpanStatusCode.Error`. The caller is still responsible for
  /// `span.end()` — typically in a `finally` block.
  ///
  /// Convenience over `OTel.tracer().withSpan(span, fn)` for callers
  /// that don't already have a [Tracer] reference.
  ///
  /// [exceptionOptions] controls how a thrown exception is recorded and
  /// whether the span status is set; see [SpanExceptionOptions].
  static T withSpan<T>(
    APISpan span,
    T Function() fn, {
    SpanExceptionOptions? exceptionOptions,
  }) =>
      tracer().withSpan(span, fn, exceptionOptions: exceptionOptions);

  /// Async variant of [withSpan]. Propagates the active span across
  /// `await` boundaries via Zone-based context.
  ///
  /// [exceptionOptions] controls how a thrown exception is recorded and
  /// whether the span status is set; see [SpanExceptionOptions].
  static Future<T> withSpanAsync<T>(
    APISpan span,
    Future<T> Function() fn, {
    SpanExceptionOptions? exceptionOptions,
  }) =>
      tracer().withSpanAsync(span, fn, exceptionOptions: exceptionOptions);

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
    final mp = _otelFactory!.addMeterProvider(
      name,
      endpoint: endpoint,
      serviceName: serviceName,
      serviceVersion: serviceVersion,
    ) as MeterProvider;
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
      version: defaultTracerVersion,
    ) as Meter;
  }

  /// Gets a LoggerProvider for creating Loggers.
  ///
  /// If name is null, this returns the global default LoggerProvider, which shares
  /// the endpoint, serviceName, serviceVersion and resource set in initialize().
  /// If the name is not null, it returns a LoggerProvider for the name that was added
  /// with addLoggerProvider.
  ///
  /// @param name Optional name of a specific LoggerProvider
  /// @return The LoggerProvider instance
  static LoggerProvider loggerProvider({String? name}) {
    _getAndCacheOtelFactory();
    final logProvider = OTelAPI.loggerProvider(name) as LoggerProvider;
    logProvider.resource ??= defaultResource;
    return logProvider;
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
    final lp = _otelFactory!.addLogProvider(name,
        endpoint: endpoint,
        serviceName: serviceName,
        serviceVersion: serviceVersion) as LoggerProvider;
    lp.resource = resource ?? defaultResource;
    return lp;
  }

  /// Gets the default OTelLogger from the default LoggerProvider.
  ///
  /// This is a convenience method for getting a OTelLogger with the default configuration.
  /// The endpoint, serviceName, serviceVersion and resource all flow down from
  /// the OTel defaults set during initialization.
  ///
  /// @param name Optional custom name for the logger (defaults to defaultTracerName)
  /// @return The default OTelLogger instance
  static OTelLogger logger([String? name]) {
    return loggerProvider().getLogger(
      name ?? defaultTracerName,
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
  /// Note: Per [OTEP 0265: Event Vision](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/0265-event-vision.md)
  /// and [OTEP 4430: Span Event API deprecation plan](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/4430-span-event-api-deprecation-plan.md),
  /// span events are planned for deprecation in favor of log-based events
  /// emitted via the Logs API; SDKs will provide options to render log-based
  /// events as span events for compatibility.
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
  /// Note: Per [OTEP 0265: Event Vision](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/0265-event-vision.md)
  /// and [OTEP 4430: Span Event API deprecation plan](https://github.com/open-telemetry/opentelemetry-specification/blob/main/oteps/4430-span-event-api-deprecation-plan.md),
  /// span events are planned for deprecation in favor of log-based events
  /// emitted via the Logs API; SDKs will provide options to render log-based
  /// events as span events for compatibility.
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
  /// Often called before initialize; pre-init this routes through the API,
  /// which lazily installs the no-op factory per spec (API ≥ beta.9 — there
  /// is no factory-bypassing cheat path anymore).
  ///
  /// @param entries Optional list of Attribute objects
  /// @return A new Attributes collection
  static Attributes attributes([List<Attribute>? entries]) {
    return _otelFactory == null
        ? OTelAPI.attributes(entries)
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
  /// (e.g. `Http.httpRequestMethod`). Each enum's `.key` is used as the
  /// attribute name. Lets you write
  ///
  /// ```dart
  /// OTel.attributesFromSemanticMap({
  ///   Http.httpRequestMethod: 'GET',
  ///   Http.httpResponseStatusCode: 200,
  /// })
  /// ```
  ///
  /// instead of `attributesFromMap({Http.httpRequestMethod.key: 'GET', …})`.
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

  /// Like [attributesFromSemanticMap], but parameterized on a single
  /// concrete semconv enum [E]. The expected key type is concrete at
  /// the call site, so Dart 3.10 static dot-shorthand can drop the
  /// enum prefix on every entry:
  ///
  /// ```dart
  /// // Today and forever:
  /// OTel.attributesOf<Http>({
  ///   Http.httpRequestMethod: 'GET',
  ///   Http.httpResponseStatusCode: 200,
  /// });
  ///
  /// // With Dart 3.10+ static dot-shorthand enabled:
  /// OTel.attributesOf<Http>({
  ///   .requestMethod: 'GET',
  ///   .responseStatusCode: 200,
  /// });
  /// ```
  ///
  /// **Mix and match**: each typed-enum map can be spread into a wider
  /// `Map<OTelSemantic, Object>` literal, which is exactly what
  /// [attributesFromSemanticMap] takes — so combining HTTP + Database
  /// keys with full dot-shorthand looks like:
  ///
  /// ```dart
  /// OTel.attributesFromSemanticMap({
  ///   ...<Http, Object>{
  ///     Http.httpRequestMethod: 'GET',
  ///     Http.httpResponseStatusCode: 200,
  ///   },
  ///   ...<Database, Object>{
  ///     Db.dbSystemName: DbSystem.postgresql.value,
  ///   },
  /// });
  /// ```
  ///
  /// Passthrough to [OTelAPI.attributesOf].
  static Attributes attributesOf<E extends OTelSemantic>(
    Map<E, Object> typedMap,
  ) =>
      OTelAPI.attributesOf<E>(typedMap);

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
    final installed = OTelFactory.otelFactory;
    // An installed factory that is not SDK-capable is the API's auto-installed
    // no-op (API-only code ran first) — the SDK still isn't initialized, and
    // saying so beats the `as` TypeError the cast would produce (#50).
    if (installed == null || installed is! OTelSDKFactory) {
      throw StateError('OTel.initialize() must be called first.');
    }
    return _otelFactory = installed;
  }

  /// Initializes logging based on environment variables.
  ///
  /// This can be called separately from initialize(), but initialize() will
  /// call it automatically if not already done.

  /// Installs the global [TextMapPropagator] per `OTEL_PROPAGATORS`
  /// (default `tracecontext,baggage`). Unsupported names emit an
  /// [OTelLog.warn] and are ignored; `none` — or a list with no supported
  /// names — leaves the API's spec-mandated no-op propagator in place.
  /// Supported: `tracecontext`, `baggage`, `none`.
  static void _installGlobalPropagator() {
    final names = OTelEnv.getPropagators();
    if (names.contains('none')) {
      if (names.length > 1 && OTelLog.isWarn()) {
        OTelLog.warn('OTEL_PROPAGATORS contains "none" alongside other '
            'values; using no propagator per spec.');
      }
      return; // The API default is the no-op propagator.
    }
    final propagators = <TextMapPropagator<Map<String, String>, String>>[];
    final seen = <String>{};
    for (final name in names) {
      if (!seen.add(name)) continue;
      switch (name) {
        case 'tracecontext':
          propagators.add(W3CTraceContextPropagator());
        case 'baggage':
          propagators.add(W3CBaggagePropagator());
        default:
          if (OTelLog.isWarn()) {
            OTelLog.warn('OTEL_PROPAGATORS: unsupported propagator '
                '"$name" ignored. Supported: tracecontext, baggage, none.');
          }
      }
    }
    if (propagators.isEmpty) {
      return; // Nothing supported was requested; keep the no-op default.
    }
    OTelAPI.textMapPropagator = propagators.length == 1
        ? propagators.single
        : OTelAPI.compositePropagator<Map<String, String>, String>(propagators);
  }

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
    _defaultSpanExceptionOptions = null;
    _defaultTimeProvider = null;
    defaultResource = null;

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
