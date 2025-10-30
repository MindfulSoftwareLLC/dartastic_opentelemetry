// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// OpenTelemetry environment variable constants.
///
/// This library provides strongly-typed constants for all OpenTelemetry
/// environment variables as defined by the OpenTelemetry specification.
///
/// These constants can be used when configuring OpenTelemetry via --dart-define
/// or when programmatically checking environment variable values.
///
/// References:
/// - https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/
/// - https://opentelemetry.io/docs/specs/otel/protocol/exporter/
/// - https://opentelemetry.io/docs/specs/otel/resource/sdk/
///
/// Example usage with --dart-define:
/// ```bash
/// flutter run --dart-define=OTEL_SERVICE_NAME=my-app \
///             --dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318
/// ```
library;

// =============================================================================
// General SDK Configuration
// =============================================================================

/// Disables the SDK for all signals when set to "true".
///
/// If set to "true", a no-op SDK implementation will be used for all telemetry
/// signals. Any other value or absence of the variable will have no effect and
/// the SDK will remain enabled.
///
/// Type: Boolean (case-insensitive "true" or "false")
/// Default: false
const String otelSdkDisabled = 'OTEL_SDK_DISABLED';

/// Key-value pairs to be used as resource attributes.
///
/// The value is a comma-separated list of key=value pairs.
/// Example: "service.name=my-service,environment=production"
///
/// Type: String
/// Default: See OpenTelemetry resource semantic conventions
const String otelResourceAttributes = 'OTEL_RESOURCE_ATTRIBUTES';

/// Sets the value of the service.name resource attribute.
///
/// If service.name is also provided in OTEL_RESOURCE_ATTRIBUTES, then
/// OTEL_SERVICE_NAME takes precedence.
///
/// Type: String
/// Default: none
const String otelServiceName = 'OTEL_SERVICE_NAME';

/// Log level used by the SDK internal logger.
///
/// Type: Enum (case-insensitive)
/// Default: "info"
const String otelLogLevel = 'OTEL_LOG_LEVEL';

/// Propagators to be used as a comma-separated list.
///
/// Known values: "tracecontext", "baggage", "b3", "b3multi", "jaeger", "xray",
/// "ottrace", "none"
///
/// Type: Enum (case-insensitive, comma-separated)
/// Default: "tracecontext,baggage"
const String otelPropagators = 'OTEL_PROPAGATORS';

/// Sampler to be used for traces.
///
/// Known values: "always_on", "always_off", "traceidratio",
/// "parentbased_always_on", "parentbased_always_off"
///
/// Type: Enum (case-insensitive)
/// Default: "parentbased_always_on"
const String otelTracesSampler = 'OTEL_TRACES_SAMPLER';

/// Value to be used as the sampler argument.
///
/// The specified value will only be used if OTEL_TRACES_SAMPLER is set.
/// Each sampler type defines its own expected input.
///
/// Type: String (sampler-specific format)
/// Default: none
const String otelTracesSamplerArg = 'OTEL_TRACES_SAMPLER_ARG';

// =============================================================================
// Dartastic-specific Logging Configuration
// =============================================================================

/// Enables logging of metrics when set to "true" (Dartastic-specific).
///
/// Type: Boolean
/// Default: false
const String otelLogMetrics = 'OTEL_LOG_METRICS';

/// Enables logging of spans when set to "true" (Dartastic-specific).
///
/// Type: Boolean
/// Default: false
const String otelLogSpans = 'OTEL_LOG_SPANS';

/// Enables logging of export operations when set to "true" (Dartastic-specific).
///
/// Type: Boolean
/// Default: false
const String otelLogExport = 'OTEL_LOG_EXPORT';

// =============================================================================
// General OTLP Exporter Configuration
// =============================================================================

/// Target endpoint URL for the OTLP exporter.
///
/// For OTLP/HTTP, default is http://localhost:4318
/// For OTLP/gRPC, default is http://localhost:4317
///
/// When using this general endpoint, signal-specific paths are automatically
/// appended for HTTP (e.g., /v1/traces, /v1/metrics, /v1/logs).
///
/// Type: String (URL)
/// Default: "http://localhost:4318" (HTTP) or "http://localhost:4317" (gRPC)
const String otelExporterOtlpEndpoint = 'OTEL_EXPORTER_OTLP_ENDPOINT';

/// Transport protocol for the OTLP exporter.
///
/// Supported values: "grpc", "http/protobuf", "http/json"
///
/// Type: Enum (case-insensitive)
/// Default: "http/protobuf"
const String otelExporterOtlpProtocol = 'OTEL_EXPORTER_OTLP_PROTOCOL';

/// Key-value pairs to be used as headers for OTLP requests.
///
/// Format: comma-separated list of key=value pairs
/// Example: "api-key=secret,tenant=acme"
///
/// Type: String
/// Default: none
const String otelExporterOtlpHeaders = 'OTEL_EXPORTER_OTLP_HEADERS';

/// Whether to use an insecure connection for OTLP/gRPC.
///
/// This option only applies to OTLP/gRPC when an endpoint is provided without
/// the http or https scheme. OTLP/HTTP always uses the scheme from the endpoint.
///
/// Type: Boolean
/// Default: false
const String otelExporterOtlpInsecure = 'OTEL_EXPORTER_OTLP_INSECURE';

/// Maximum time the OTLP exporter will wait for each batch export.
///
/// Type: Timeout (milliseconds)
/// Default: 10000 (10 seconds)
const String otelExporterOtlpTimeout = 'OTEL_EXPORTER_OTLP_TIMEOUT';

/// Compression algorithm for OTLP exports.
///
/// Supported values: "none", "gzip"
///
/// Type: Enum (case-insensitive)
/// Default: none
const String otelExporterOtlpCompression = 'OTEL_EXPORTER_OTLP_COMPRESSION';

/// Path to the certificate file for verifying server TLS credentials.
///
/// Should only be used for secure connections.
///
/// Type: String (file path)
/// Default: none
const String otelExporterOtlpCertificate = 'OTEL_EXPORTER_OTLP_CERTIFICATE';

/// Path to the client private key file for mTLS (PEM format).
///
/// Type: String (file path)
/// Default: none
const String otelExporterOtlpClientKey = 'OTEL_EXPORTER_OTLP_CLIENT_KEY';

/// Path to the client certificate file for mTLS (PEM format).
///
/// Type: String (file path)
/// Default: none
const String otelExporterOtlpClientCertificate =
    'OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE';

// =============================================================================
// Traces-specific OTLP Configuration
// =============================================================================

/// Exporter to use for traces.
///
/// Known values: "otlp", "jaeger", "zipkin", "none"
///
/// Type: Enum (case-insensitive, comma-separated)
/// Default: "otlp"
const String otelTracesExporter = 'OTEL_TRACES_EXPORTER';

/// Target endpoint URL for traces OTLP exporter.
///
/// Overrides OTEL_EXPORTER_OTLP_ENDPOINT for traces.
///
/// Type: String (URL)
/// Default: none (uses OTEL_EXPORTER_OTLP_ENDPOINT)
const String otelExporterOtlpTracesEndpoint =
    'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT';

/// Transport protocol for traces OTLP exporter.
///
/// Overrides OTEL_EXPORTER_OTLP_PROTOCOL for traces.
///
/// Type: Enum (case-insensitive)
/// Default: none (uses OTEL_EXPORTER_OTLP_PROTOCOL)
const String otelExporterOtlpTracesProtocol =
    'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL';

/// Headers for traces OTLP requests.
///
/// Overrides OTEL_EXPORTER_OTLP_HEADERS for traces.
///
/// Type: String
/// Default: none (uses OTEL_EXPORTER_OTLP_HEADERS)
const String otelExporterOtlpTracesHeaders =
    'OTEL_EXPORTER_OTLP_TRACES_HEADERS';

/// Whether to use insecure connection for traces OTLP/gRPC.
///
/// Overrides OTEL_EXPORTER_OTLP_INSECURE for traces.
///
/// Type: Boolean
/// Default: none (uses OTEL_EXPORTER_OTLP_INSECURE)
const String otelExporterOtlpTracesInsecure =
    'OTEL_EXPORTER_OTLP_TRACES_INSECURE';

/// Timeout for traces OTLP exports.
///
/// Overrides OTEL_EXPORTER_OTLP_TIMEOUT for traces.
///
/// Type: Timeout (milliseconds)
/// Default: none (uses OTEL_EXPORTER_OTLP_TIMEOUT)
const String otelExporterOtlpTracesTimeout =
    'OTEL_EXPORTER_OTLP_TRACES_TIMEOUT';

/// Compression for traces OTLP exports.
///
/// Overrides OTEL_EXPORTER_OTLP_COMPRESSION for traces.
///
/// Type: Enum (case-insensitive)
/// Default: none (uses OTEL_EXPORTER_OTLP_COMPRESSION)
const String otelExporterOtlpTracesCompression =
    'OTEL_EXPORTER_OTLP_TRACES_COMPRESSION';

/// Certificate file for traces TLS verification.
///
/// Overrides OTEL_EXPORTER_OTLP_CERTIFICATE for traces.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CERTIFICATE)
const String otelExporterOtlpTracesCertificate =
    'OTEL_EXPORTER_OTLP_TRACES_CERTIFICATE';

/// Client key file for traces mTLS.
///
/// Overrides OTEL_EXPORTER_OTLP_CLIENT_KEY for traces.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CLIENT_KEY)
const String otelExporterOtlpTracesClientKey =
    'OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY';

/// Client certificate file for traces mTLS.
///
/// Overrides OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE for traces.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE)
const String otelExporterOtlpTracesClientCertificate =
    'OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE';

// =============================================================================
// Metrics-specific OTLP Configuration
// =============================================================================

/// Exporter to use for metrics.
///
/// Known values: "otlp", "prometheus", "none"
///
/// Type: Enum (case-insensitive, comma-separated)
/// Default: "otlp"
const String otelMetricsExporter = 'OTEL_METRICS_EXPORTER';

/// Target endpoint URL for metrics OTLP exporter.
///
/// Overrides OTEL_EXPORTER_OTLP_ENDPOINT for metrics.
///
/// Type: String (URL)
/// Default: none (uses OTEL_EXPORTER_OTLP_ENDPOINT)
const String otelExporterOtlpMetricsEndpoint =
    'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT';

/// Transport protocol for metrics OTLP exporter.
///
/// Overrides OTEL_EXPORTER_OTLP_PROTOCOL for metrics.
///
/// Type: Enum (case-insensitive)
/// Default: none (uses OTEL_EXPORTER_OTLP_PROTOCOL)
const String otelExporterOtlpMetricsProtocol =
    'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL';

/// Headers for metrics OTLP requests.
///
/// Overrides OTEL_EXPORTER_OTLP_HEADERS for metrics.
///
/// Type: String
/// Default: none (uses OTEL_EXPORTER_OTLP_HEADERS)
const String otelExporterOtlpMetricsHeaders =
    'OTEL_EXPORTER_OTLP_METRICS_HEADERS';

/// Whether to use insecure connection for metrics OTLP/gRPC.
///
/// Overrides OTEL_EXPORTER_OTLP_INSECURE for metrics.
///
/// Type: Boolean
/// Default: none (uses OTEL_EXPORTER_OTLP_INSECURE)
const String otelExporterOtlpMetricsInsecure =
    'OTEL_EXPORTER_OTLP_METRICS_INSECURE';

/// Timeout for metrics OTLP exports.
///
/// Overrides OTEL_EXPORTER_OTLP_TIMEOUT for metrics.
///
/// Type: Timeout (milliseconds)
/// Default: none (uses OTEL_EXPORTER_OTLP_TIMEOUT)
const String otelExporterOtlpMetricsTimeout =
    'OTEL_EXPORTER_OTLP_METRICS_TIMEOUT';

/// Compression for metrics OTLP exports.
///
/// Overrides OTEL_EXPORTER_OTLP_COMPRESSION for metrics.
///
/// Type: Enum (case-insensitive)
/// Default: none (uses OTEL_EXPORTER_OTLP_COMPRESSION)
const String otelExporterOtlpMetricsCompression =
    'OTEL_EXPORTER_OTLP_METRICS_COMPRESSION';

/// Certificate file for metrics TLS verification.
///
/// Overrides OTEL_EXPORTER_OTLP_CERTIFICATE for metrics.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CERTIFICATE)
const String otelExporterOtlpMetricsCertificate =
    'OTEL_EXPORTER_OTLP_METRICS_CERTIFICATE';

/// Client key file for metrics mTLS.
///
/// Overrides OTEL_EXPORTER_OTLP_CLIENT_KEY for metrics.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CLIENT_KEY)
const String otelExporterOtlpMetricsClientKey =
    'OTEL_EXPORTER_OTLP_METRICS_CLIENT_KEY';

/// Client certificate file for metrics mTLS.
///
/// Overrides OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE for metrics.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE)
const String otelExporterOtlpMetricsClientCertificate =
    'OTEL_EXPORTER_OTLP_METRICS_CLIENT_CERTIFICATE';

// =============================================================================
// Logs-specific OTLP Configuration
// =============================================================================

/// Exporter to use for logs.
///
/// Known values: "otlp", "none"
///
/// Type: Enum (case-insensitive, comma-separated)
/// Default: "otlp"
const String otelLogsExporter = 'OTEL_LOGS_EXPORTER';

/// Target endpoint URL for logs OTLP exporter.
///
/// Overrides OTEL_EXPORTER_OTLP_ENDPOINT for logs.
///
/// Type: String (URL)
/// Default: none (uses OTEL_EXPORTER_OTLP_ENDPOINT)
const String otelExporterOtlpLogsEndpoint = 'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT';

/// Transport protocol for logs OTLP exporter.
///
/// Overrides OTEL_EXPORTER_OTLP_PROTOCOL for logs.
///
/// Type: Enum (case-insensitive)
/// Default: none (uses OTEL_EXPORTER_OTLP_PROTOCOL)
const String otelExporterOtlpLogsProtocol = 'OTEL_EXPORTER_OTLP_LOGS_PROTOCOL';

/// Headers for logs OTLP requests.
///
/// Overrides OTEL_EXPORTER_OTLP_HEADERS for logs.
///
/// Type: String
/// Default: none (uses OTEL_EXPORTER_OTLP_HEADERS)
const String otelExporterOtlpLogsHeaders = 'OTEL_EXPORTER_OTLP_LOGS_HEADERS';

/// Whether to use insecure connection for logs OTLP/gRPC.
///
/// Overrides OTEL_EXPORTER_OTLP_INSECURE for logs.
///
/// Type: Boolean
/// Default: none (uses OTEL_EXPORTER_OTLP_INSECURE)
const String otelExporterOtlpLogsInsecure = 'OTEL_EXPORTER_OTLP_LOGS_INSECURE';

/// Timeout for logs OTLP exports.
///
/// Overrides OTEL_EXPORTER_OTLP_TIMEOUT for logs.
///
/// Type: Timeout (milliseconds)
/// Default: none (uses OTEL_EXPORTER_OTLP_TIMEOUT)
const String otelExporterOtlpLogsTimeout = 'OTEL_EXPORTER_OTLP_LOGS_TIMEOUT';

/// Compression for logs OTLP exports.
///
/// Overrides OTEL_EXPORTER_OTLP_COMPRESSION for logs.
///
/// Type: Enum (case-insensitive)
/// Default: none (uses OTEL_EXPORTER_OTLP_COMPRESSION)
const String otelExporterOtlpLogsCompression =
    'OTEL_EXPORTER_OTLP_LOGS_COMPRESSION';

/// Certificate file for logs TLS verification.
///
/// Overrides OTEL_EXPORTER_OTLP_CERTIFICATE for logs.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CERTIFICATE)
const String otelExporterOtlpLogsCertificate =
    'OTEL_EXPORTER_OTLP_LOGS_CERTIFICATE';

/// Client key file for logs mTLS.
///
/// Overrides OTEL_EXPORTER_OTLP_CLIENT_KEY for logs.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CLIENT_KEY)
const String otelExporterOtlpLogsClientKey =
    'OTEL_EXPORTER_OTLP_LOGS_CLIENT_KEY';

/// Client certificate file for logs mTLS.
///
/// Overrides OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE for logs.
///
/// Type: String (file path)
/// Default: none (uses OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE)
const String otelExporterOtlpLogsClientCertificate =
    'OTEL_EXPORTER_OTLP_LOGS_CLIENT_CERTIFICATE';

// =============================================================================
// Batch Span Processor Configuration
// =============================================================================

/// Delay interval between two consecutive exports.
///
/// Type: Duration (milliseconds)
/// Default: 5000 (5 seconds)
const String otelBspScheduleDelay = 'OTEL_BSP_SCHEDULE_DELAY';

/// Maximum allowed time to export data.
///
/// Type: Timeout (milliseconds)
/// Default: 30000 (30 seconds)
const String otelBspExportTimeout = 'OTEL_BSP_EXPORT_TIMEOUT';

/// Maximum queue size for the batch span processor.
///
/// Type: Integer
/// Default: 2048
const String otelBspMaxQueueSize = 'OTEL_BSP_MAX_QUEUE_SIZE';

/// Maximum batch size for each export.
///
/// Type: Integer
/// Default: 512
const String otelBspMaxExportBatchSize = 'OTEL_BSP_MAX_EXPORT_BATCH_SIZE';

// =============================================================================
// Batch LogRecord Processor Configuration
// =============================================================================

/// Delay interval between two consecutive exports.
///
/// Type: Duration (milliseconds)
/// Default: 1000 (1 second)
const String otelBlrpScheduleDelay = 'OTEL_BLRP_SCHEDULE_DELAY';

/// Maximum allowed time to export data.
///
/// Type: Timeout (milliseconds)
/// Default: 30000 (30 seconds)
const String otelBlrpExportTimeout = 'OTEL_BLRP_EXPORT_TIMEOUT';

/// Maximum queue size for the batch log record processor.
///
/// Type: Integer
/// Default: 2048
const String otelBlrpMaxQueueSize = 'OTEL_BLRP_MAX_QUEUE_SIZE';

/// Maximum batch size for each export.
///
/// Type: Integer
/// Default: 512
const String otelBlrpMaxExportBatchSize = 'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE';

// =============================================================================
// Attribute Limits
// =============================================================================

/// Maximum allowed attribute value length.
///
/// Type: Integer
/// Default: unlimited
const String otelAttributeValueLengthLimit =
    'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT';

/// Maximum number of attributes per telemetry item.
///
/// Type: Integer
/// Default: 128
const String otelAttributeCountLimit = 'OTEL_ATTRIBUTE_COUNT_LIMIT';

// =============================================================================
// Span Limits
// =============================================================================

/// Maximum allowed span attribute value length.
///
/// Type: Integer
/// Default: unlimited
const String otelSpanAttributeValueLengthLimit =
    'OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT';

/// Maximum number of attributes per span.
///
/// Type: Integer
/// Default: 128
const String otelSpanAttributeCountLimit = 'OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT';

/// Maximum number of events per span.
///
/// Type: Integer
/// Default: 128
const String otelSpanEventCountLimit = 'OTEL_SPAN_EVENT_COUNT_LIMIT';

/// Maximum number of links per span.
///
/// Type: Integer
/// Default: 128
const String otelSpanLinkCountLimit = 'OTEL_SPAN_LINK_COUNT_LIMIT';

/// Maximum number of attributes per span event.
///
/// Type: Integer
/// Default: 128
const String otelEventAttributeCountLimit = 'OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT';

/// Maximum number of attributes per span link.
///
/// Type: Integer
/// Default: 128
const String otelLinkAttributeCountLimit = 'OTEL_LINK_ATTRIBUTE_COUNT_LIMIT';

// =============================================================================
// LogRecord Limits
// =============================================================================

/// Maximum allowed log record attribute value length.
///
/// Type: Integer
/// Default: unlimited
const String otelLogrecordAttributeValueLengthLimit =
    'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT';

/// Maximum number of attributes per log record.
///
/// Type: Integer
/// Default: 128
const String otelLogrecordAttributeCountLimit =
    'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT';

// =============================================================================
// Metrics SDK Configuration
// =============================================================================

/// Exemplar filter to use for metrics.
///
/// Known values: "trace_based", "always_on", "always_off"
///
/// Type: Enum (case-insensitive)
/// Default: "trace_based"
const String otelMetricsExemplarFilter = 'OTEL_METRICS_EXEMPLAR_FILTER';

/// Interval for periodic metric exports.
///
/// Type: Duration (milliseconds)
/// Default: 60000 (60 seconds)
const String otelMetricExportInterval = 'OTEL_METRIC_EXPORT_INTERVAL';

/// Maximum allowed time to export metrics.
///
/// Type: Timeout (milliseconds)
/// Default: 30000 (30 seconds)
const String otelMetricExportTimeout = 'OTEL_METRIC_EXPORT_TIMEOUT';

// =============================================================================
// Zipkin Exporter Configuration
// =============================================================================

/// Zipkin collector endpoint URL.
///
/// Type: String (URL)
/// Default: "http://localhost:9411/api/v2/spans"
const String otelExporterZipkinEndpoint = 'OTEL_EXPORTER_ZIPKIN_ENDPOINT';

/// Maximum time the Zipkin exporter will wait for each batch export.
///
/// Type: Timeout (milliseconds)
/// Default: 10000 (10 seconds)
const String otelExporterZipkinTimeout = 'OTEL_EXPORTER_ZIPKIN_TIMEOUT';

// =============================================================================
// Prometheus Exporter Configuration
// =============================================================================

/// Host for the Prometheus exporter server.
///
/// Type: String
/// Default: "localhost"
const String otelExporterPrometheusHost = 'OTEL_EXPORTER_PROMETHEUS_HOST';

/// Port for the Prometheus exporter server.
///
/// Type: Integer
/// Default: 9464
const String otelExporterPrometheusPort = 'OTEL_EXPORTER_PROMETHEUS_PORT';

// =============================================================================
// Deprecated Environment Variables
// =============================================================================

/// @deprecated Use OTEL_EXPORTER_OTLP_TRACES_INSECURE instead.
///
/// This variable is obsolete and maintained for backward compatibility only.
///
/// Type: Boolean
/// Default: none
const String otelExporterOtlpSpanInsecure = 'OTEL_EXPORTER_OTLP_SPAN_INSECURE';

/// @deprecated Use OTEL_EXPORTER_OTLP_METRICS_INSECURE instead.
///
/// This variable is obsolete and maintained for backward compatibility only.
///
/// Type: Boolean
/// Default: none
const String otelExporterOtlpMetricInsecure =
    'OTEL_EXPORTER_OTLP_METRIC_INSECURE';

// =============================================================================
// Supported Environment Variables Set
// =============================================================================

/// Set of all supported OpenTelemetry environment variable names.
///
/// This set is used internally to determine which String.fromEnvironment
/// constants are valid to look up. Since --dart-define doesn't support dynamic
/// variable names, we must know the complete set of possible variable names at
/// compile time.
const Set<String> supportedEnvVars = {
  // General SDK Configuration
  otelSdkDisabled,
  otelResourceAttributes,
  otelServiceName,
  otelLogLevel,
  otelPropagators,
  otelTracesSampler,
  otelTracesSamplerArg,

  // Dartastic-specific Logging Configuration
  otelLogMetrics,
  otelLogSpans,
  otelLogExport,

  // General OTLP Exporter Configuration
  otelExporterOtlpEndpoint,
  otelExporterOtlpProtocol,
  otelExporterOtlpHeaders,
  otelExporterOtlpInsecure,
  otelExporterOtlpTimeout,
  otelExporterOtlpCompression,
  otelExporterOtlpCertificate,
  otelExporterOtlpClientKey,
  otelExporterOtlpClientCertificate,

  // Traces-specific OTLP Configuration
  otelTracesExporter,
  otelExporterOtlpTracesEndpoint,
  otelExporterOtlpTracesProtocol,
  otelExporterOtlpTracesHeaders,
  otelExporterOtlpTracesInsecure,
  otelExporterOtlpTracesTimeout,
  otelExporterOtlpTracesCompression,
  otelExporterOtlpTracesCertificate,
  otelExporterOtlpTracesClientKey,
  otelExporterOtlpTracesClientCertificate,

  // Metrics-specific OTLP Configuration
  otelMetricsExporter,
  otelExporterOtlpMetricsEndpoint,
  otelExporterOtlpMetricsProtocol,
  otelExporterOtlpMetricsHeaders,
  otelExporterOtlpMetricsInsecure,
  otelExporterOtlpMetricsTimeout,
  otelExporterOtlpMetricsCompression,
  otelExporterOtlpMetricsCertificate,
  otelExporterOtlpMetricsClientKey,
  otelExporterOtlpMetricsClientCertificate,

  // Logs-specific OTLP Configuration
  otelLogsExporter,
  otelExporterOtlpLogsEndpoint,
  otelExporterOtlpLogsProtocol,
  otelExporterOtlpLogsHeaders,
  otelExporterOtlpLogsInsecure,
  otelExporterOtlpLogsTimeout,
  otelExporterOtlpLogsCompression,
  otelExporterOtlpLogsCertificate,
  otelExporterOtlpLogsClientKey,
  otelExporterOtlpLogsClientCertificate,

  // Batch Span Processor
  otelBspScheduleDelay,
  otelBspExportTimeout,
  otelBspMaxQueueSize,
  otelBspMaxExportBatchSize,

  // Batch LogRecord Processor
  otelBlrpScheduleDelay,
  otelBlrpExportTimeout,
  otelBlrpMaxQueueSize,
  otelBlrpMaxExportBatchSize,

  // Attribute Limits
  otelAttributeValueLengthLimit,
  otelAttributeCountLimit,

  // Span Limits
  otelSpanAttributeValueLengthLimit,
  otelSpanAttributeCountLimit,
  otelSpanEventCountLimit,
  otelSpanLinkCountLimit,
  otelEventAttributeCountLimit,
  otelLinkAttributeCountLimit,

  // LogRecord Limits
  otelLogrecordAttributeValueLengthLimit,
  otelLogrecordAttributeCountLimit,

  // Metrics SDK Configuration
  otelMetricsExemplarFilter,
  otelMetricExportInterval,
  otelMetricExportTimeout,

  // Zipkin Exporter
  otelExporterZipkinEndpoint,
  otelExporterZipkinTimeout,

  // Prometheus Exporter
  otelExporterPrometheusHost,
  otelExporterPrometheusPort,

  // Deprecated but supported for backward compatibility
  otelExporterOtlpSpanInsecure,
  otelExporterOtlpMetricInsecure,
};
