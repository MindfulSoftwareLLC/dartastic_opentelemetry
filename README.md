# OpenTelemetry SDK for Dart

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenTelemetry Specification](https://img.shields.io/badge/OpenTelemetry-Specification-blueviolet)](https://opentelemetry.io/docs/specs/otel/)
[![Coverage Report](https://img.shields.io/badge/coverage-report-brightgreen.svg)](https://mindfulsoftwarellc.github.io/dartastic_opentelemetry/)

Dartastic is an [OpenTelemetry](https://opentelemetry.io/) SDK to add standard observability to Dart applications.
Dartastic can be used with any OTel backend, it's standards-compliant.

Flutter developers should use the [Flutterific OpenTelemetry SDK](https://pub.dev/packages/flutterrific_opentelemetry/) which builds on top of Dartastic OTel.

The Dartastic and Flutterrific OTel SDK has been proposed for [Donation to the CNCF](https://github.com/open-telemetry/community/issues/2718).
We need YOU to grow the Dartastic community and make this SDK the standard for Flutter and Dart OTel.
Please use it, submit issues, support us with stars and contribute PRs. We are looking for contributors and maintainers.
Also, please support the development by subscribing at [Dartastic.io](https://dartastic.io) and gain early access to the
Flutter SDK and the Wondrous Demo.

[Dartastic.io](https://dartastic.io) provides an OpenTelemetry support, training, consulting
and an Observability backend customized for Flutter apps, Dart backends, and any other service or process that produces
OpenTelemetry data.


## Features

- 🚀 **Friendly API**: An easy to use, discoverable, immutable, typesafe API that feels familiar to Dart developers.
- 📐 **Standards Compliant**: Complies with the [OpenTelemetry specification](https://opentelemetry.io/docs/specs/)
  so it's portable and future-proof.
- 🌎 **Ecosystem**:
  - [Dartastic.io](https://dartastic.io) is an OTel backend for Dart with a generous free tier,
    professional support and enterprise features.
  - [Flutterrific OTel](https://pub.dev/packages/flutterrific_opentelemetry)
    adds Dartastic OTel to Flutter apps with ease.  Observe app routes, errors, web vitals and more with as few
    as two lines of code.
- 💪🏻 **Powerful**:
  - Propagate OpenTelemetry Context across async gaps and Isolates.
  - Pick from a rich set of Samplers including On/Off, probability and rate-limiting.
  - Automatically capture platform resources on initialization.
  - No skimping - If it's optional in the spec, it's included in Dartastic.
  - A pluggable and extensible API and SDK enables implementation freedom.
- 🧷 **Typesafe Semantics**: Ensure you're speaking the right language with a massive set of enums matching
  the [OpenTelemetry Semantics Conventions](https://opentelemetry.io/docs/specs/semconv/).
- 📊 **Excellent Performance**: 
    - Low overhead
    - Batch processing
    - Performance test suite for proven benchmarks
- 🐞 **Well Tested**: Good test coverage (>85%). 
- 📃 **Quality Documentation**: If it's not clearly documented, it's a bug. Extensive examples and best practices are
  provided. See the examples directory. 
- 🎬 **Demo** The [Wonderous OpenTelemetry Demo](https://github.com/MindfulSoftwareLLC/wondrous_opentelemetry) demonstrates  
  gskinner's Wonderous App with instrumentation for OpenTelemetry.
- ✅ **Supported Telemetry Signals and Features**:
  - Tracing with span processors and samplers
  - Metrics collection and aggregation
  - Logs with log record processors and exporters
  - Context propagation
  - Baggage management

[Dartastic OTel](https://pub.dev/packages/dartastic_opentelemetry) is suitable for Dart backends, CLIs or any
Dart application.

[Dartastic OTel API](https://pub.dev/packages/dartastic_opentelemetry_api) is the API for the Dartastic OTel SDK.
The `dartastic_opentelemetry_api` exists as a standalone library to strictly adhere to the
OpenTelemetry specification which separates API and the SDK.  All OpenTelemetry API classes on in
`dartastic_opentelemetry_api`.

[Flutterrific OTel](https://pub.dev/packages/flutterrific_opentelemetry) adds Dartastic OTel to Flutter apps with ease.  Sign Up at Dartastic.io for early access to this soon to be open source.

[Dartastic.io](https://dartastic.io) is an OpenTelemetry backend based on Elastic with a generous free tier.

Dartastic and Flutterrific OTel are made with 💙 by Michael Bushe at [Mindful Software](https://mindfulsoftware.com).

Mindful Software offers paid support, consulting and developing on Flutter, OpenTelemetry and UI Architecture.

## Getting started

Include this in your pubspec.yaml:
```
dependencies:
  dartastic_opentelemetry: ^0.9.3
```

The entrypoint to the SDK is the `OTel` class.  `OTel` has static "factory" methods for all
OTel API and SDK objects.  `OTel` needs to be initialized first to point to an OpenTelemetry
backend.  Initialization does a lot of work under the hood including gathering a rich set of
standard resources for any OS that Dart runs in.  It prepares for the creation of the global
default `TracerProvider` with the serviceName and a default `Tracer`, both created on first use.
All configuration, include Trace and Metric exporters, can be made in code via `OTel.initialize()`.  
Codeless configuration can be done with standard OpenTelemetry environmental variables either 
through POSIX variable or `-D` or `--define` for Dart or with `--dart-define` for Flutter apps.

## Environment Variables

Dartastic OpenTelemetry ~~supports~~ is working on support for all standard OpenTelemetry environment variables as defined in the [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/).

Environment variables provide a convenient way to configure OpenTelemetry without hardcoding values. 
All environment variable names are available as strongly-typed constants in the SDK for compile-time 
safety and IDE autocomplete. See `lib/src/environment/env_constants.dart` for a complete list.

### How It Works

Dart environment variables can be set in two ways:

1. **System Environment Variables** (Non-web only): Traditional POSIX environment variables
   ```bash
   export OTEL_SERVICE_NAME=my-service
   dart run
   ```

2. **Compile-time Constants** (All platforms including Flutter web): Passed during compilation/execution

   **For Dart commands** (`dart run`, `dart compile`, `dart test`):
   ```bash
   # Using --define (or -D shorthand)
   dart run --define=OTEL_SERVICE_NAME=my-service
   dart compile exe -D=OTEL_SERVICE_NAME=my-service -o myapp
   dart test -DOTEL_SERVICE_NAME=my-service
   ```

   **For Flutter commands**:
   ```bash
   # Flutter uses --dart-define (note the different flag name)
   flutter run --dart-define=OTEL_SERVICE_NAME=my-service
   flutter build apk --dart-define=OTEL_SERVICE_NAME=my-service
   ```

**Priority**: Compile-time constants (`--define` or `--dart-define`) take precedence over system environment variables. 
Explicit parameters to `OTel.initialize()` override both.  Thus, POSIX env vars cannot override `--dart-define`s and
neither POSIX env vars nor `--dart-define`s can override code.  This is sensible and reduces security vectors.

**Web Support**: Flutter web and Dart web only support compile-time constants (`--define` or `--dart-define`), as browser environments don't have access to system environment variables.

### Using Environment Variable Constants

All OpenTelemetry environment variable names are available as typed constants:

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  // Reference constants instead of strings
  final serviceName = EnvironmentService.instance.getValue(otelServiceName);
  final endpoint = EnvironmentService.instance.getValue(otelExporterOtlpEndpoint);
  
  print('Service: $serviceName');
  print('Endpoint: $endpoint');
}
```

Constants are defined for all 74 OpenTelemetry environment variables. See `lib/src/environment/env_constants.dart` for the complete list.

### Supported Environmental Variables

#### Service Configuration

| Constant                   | Environment Variable        | Description                       | Example                                 |
|----------------------------|-----------------------------|-----------------------------------|-----------------------------------------|
| `otelServiceName`          | `OTEL_SERVICE_NAME`         | Sets the service name             | `my-dart-app`                           |
| `otelResourceAttributes`   | `OTEL_RESOURCE_ATTRIBUTES`  | Additional resource attributes    | `environment=prod,region=us-west`       |
| `otelLogLevel`             | `OTEL_LOG_LEVEL`            | SDK internal log level            | `INFO`, `DEBUG`, `WARN`, `ERROR`        |

#### OTLP Exporter Configuration

| Constant                      | Environment Variable           | Description              | Default                | Example                          |
|-------------------------------|--------------------------------|--------------------------|------------------------|----------------------------------|
| `otelExporterOtlpEndpoint`    | `OTEL_EXPORTER_OTLP_ENDPOINT`  | OTLP endpoint URL        | `http://localhost:4318` | `https://otel-collector:4317`    |
| `otelExporterOtlpProtocol`    | `OTEL_EXPORTER_OTLP_PROTOCOL`  | Transport protocol       | `http/protobuf`        | `grpc`, `http/protobuf`, `http/json` |
| `otelExporterOtlpHeaders`     | `OTEL_EXPORTER_OTLP_HEADERS`   | Headers (key=value,...)  | None                   | `api-key=secret,tenant=acme`     |
| `otelExporterOtlpTimeout`     | `OTEL_EXPORTER_OTLP_TIMEOUT`   | Timeout in milliseconds  | `10000`                | `5000`                           |
| `otelExporterOtlpCompression` | `OTEL_EXPORTER_OTLP_COMPRESSION` | Compression algorithm  | None                   | `gzip`                           |

#### Signal-Specific Configuration

##### Traces

| Constant                              | Environment Variable                    | Description               |
|---------------------------------------|-----------------------------------------|---------------------------|
| `otelTracesExporter`                  | `OTEL_TRACES_EXPORTER`                  | Trace exporter type       |
| `otelExporterOtlpTracesEndpoint`      | `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`    | Traces-specific endpoint  |
| `otelExporterOtlpTracesProtocol`      | `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`    | Traces-specific protocol  |
| `otelExporterOtlpTracesHeaders`       | `OTEL_EXPORTER_OTLP_TRACES_HEADERS`     | Traces-specific headers   |

##### Metrics

| Constant                              | Environment Variable                    | Description               |
|---------------------------------------|-----------------------------------------|---------------------------|
| `otelMetricsExporter`                 | `OTEL_METRICS_EXPORTER`                 | Metrics exporter type     |
| `otelExporterOtlpMetricsEndpoint`     | `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`   | Metrics-specific endpoint |
| `otelExporterOtlpMetricsProtocol`     | `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL`   | Metrics-specific protocol |
| `otelExporterOtlpMetricsHeaders`      | `OTEL_EXPORTER_OTLP_METRICS_HEADERS`    | Metrics-specific headers  |

##### Logs

| Constant                              | Environment Variable                    | Description               |
|---------------------------------------|-----------------------------------------|---------------------------|
| `otelLogsExporter`                    | `OTEL_LOGS_EXPORTER`                    | Logs exporter type (`otlp`, `console`, `none`) |
| `otelExporterOtlpLogsEndpoint`        | `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`      | Logs-specific endpoint    |
| `otelExporterOtlpLogsProtocol`        | `OTEL_EXPORTER_OTLP_LOGS_PROTOCOL`      | Logs-specific protocol    |
| `otelExporterOtlpLogsHeaders`         | `OTEL_EXPORTER_OTLP_LOGS_HEADERS`       | Logs-specific headers     |

##### Batch LogRecord Processor (BLRP)

| Constant                         | Environment Variable              | Default  | Description                          |
|----------------------------------|-----------------------------------|----------|--------------------------------------|
| `otelBlrpScheduleDelay`          | `OTEL_BLRP_SCHEDULE_DELAY`        | `1000`   | Delay between exports (milliseconds) |
| `otelBlrpExportTimeout`          | `OTEL_BLRP_EXPORT_TIMEOUT`        | `30000`  | Export timeout (milliseconds)        |
| `otelBlrpMaxQueueSize`           | `OTEL_BLRP_MAX_QUEUE_SIZE`        | `2048`   | Maximum queue size                   |
| `otelBlrpMaxExportBatchSize`     | `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` | `512`    | Maximum batch size per export        |

##### LogRecord Limits

| Constant                                  | Environment Variable                        | Default  | Description                        |
|-------------------------------------------|---------------------------------------------|----------|------------------------------------|
| `otelLogrecordAttributeValueLengthLimit`  | `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` | No limit | Maximum length of attribute values |
| `otelLogrecordAttributeCountLimit`        | `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT`       | `128`    | Maximum number of attributes       |

For the complete list of all supported environment variables with full documentation, see [`lib/src/environment/env_constants.dart`](lib/src/environment/env_constants.dart).

### Usage Examples

#### Dart Application with Environment Variables

Note the ',' in OTEL_RESOURCE_ATTRIBUTES for POSIX env vars but a ';' for --dart-define.  This is due to a Dart quirk.

```bash
# Set environment variables
export OTEL_SERVICE_NAME=my-backend-service
export OTEL_RESOURCE_ATTRIBUTES="service.version=1.2.3,deployment.environment=prod"
export OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-collector:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS=api-key=your-key
export OTEL_LOG_LEVEL=DEBUG

# Run your application
dart run bin/my_app.dart
```

#### Flutter Application with --dart-define

```bash
flutter run \
  --dart-define=OTEL_SERVICE_NAME=my-flutter-app \
  --dart-define=OTEL_RESOURCE_ATTRIBUTES="service.version=1.2.3;deployment.environment=prod"
  --dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-collector:4317 \
  --dart-define=OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
  --dart-define=OTEL_EXPORTER_OTLP_HEADERS=api-key=your-key
```

#### Flutter Web (requires --dart-define)

```bash
# Web MUST use --dart-define (environment variables don't work in browsers)
flutter run -d chrome \
  --dart-define=OTEL_SERVICE_NAME=my-web-app \
  --dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=https://collector:4318
```

#### Combining Both (--dart-define wins)

```bash
# Environment variable
export OTEL_SERVICE_NAME=from-environment

# --dart-define takes precedence
dart run --dart-define=OTEL_SERVICE_NAME=from-dart-define

# Result: Uses "from-dart-define"
```

#### In Code

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() async {
  // OTel.initialize() automatically reads environment variables
  // when parameters are not explicitly provided
  await OTel.initialize();
  
  // Environment variables are read automatically:
  // - OTEL_SERVICE_NAME
  // - OTEL_EXPORTER_OTLP_ENDPOINT
  // - OTEL_EXPORTER_OTLP_PROTOCOL
  // - And 90+ others...
  
  // Explicit parameters override environment variables
  await OTel.initialize(
    serviceName: 'explicit-service',  // Overrides OTEL_SERVICE_NAME
    endpoint: 'https://override:4318', // Overrides OTEL_EXPORTER_OTLP_ENDPOINT
  );
  
  // You can also read environment variables directly
  final endpoint = EnvironmentService.instance.getValue(otelExporterOtlpEndpoint);
  print('Using endpoint: $endpoint');
}
```

### Testing with Environment Variables

Integration tests can use real environment variables:

```bash
# Run tests with environment variables
OTEL_SERVICE_NAME=test-service dart test

# Run tests with --dart-define
dart test --dart-define=OTEL_SERVICE_NAME=test-service

# Run the provided integration test script
./tool/test_env_vars.sh
```

The SDK includes an integration test suite (`test/integration/environment_variables_test.dart`) and a test script (`tool/test_env_vars.sh`) that demonstrates proper environment variable usage.

### Minimal Code Example

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() async {
  // Initialize - automatically reads environment variables
  await OTel.initialize();

  // Get the default tracer
  final tracer = OTel.tracer();

  // Create a span
  final span = tracer.startSpan('my-operation');
  
  try {
    // Your code here
    await doWork();
  } catch (e, stackTrace) {
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.error, 'Operation failed');
  } finally {
    span.end();
  }
}
```

Since dartastic_opentelemetry exports all the classes of `opentelemetry_api`, refer to
`opentelemetry_api` for documentation of API classes.

See the `/example` folder for more examples.

## OpenTelemetry Metrics API

The Metrics API in OpenTelemetry provides a way to record measurements about your application. These measurements can be exported later as metrics, allowing you to monitor and analyze the performance and behavior of your application.

### Concepts

- **MeterProvider**: Entry point to the metrics API, responsible for creating Meters
- **Meter**: Used to create instruments for recording measurements
- **Instrument**: Used to record measurements
  - Synchronous instruments: record measurements at the moment of calling their APIs
  - Asynchronous instruments: collect measurements on demand via callbacks

### Instrument Types

- **Counter**: Synchronous, monotonic increasing counter (can only go up)
- **UpDownCounter**: Synchronous, non-monotonic counter (can go up or down)
- **Histogram**: Synchronous, aggregable measurements with statistical distributions
- **Gauge**: Synchronous, non-additive value that represents current state
- **ObservableCounter**: Asynchronous version of Counter
- **ObservableUpDownCounter**: Asynchronous version of UpDownCounter
- **ObservableGauge**: Asynchronous version of Gauge

### Usage Pattern

Similar to the Tracing API, the metrics API follows a multi-layered factory pattern:

1. **API Layer**: Defines interfaces and provides no-op implementations
2. **SDK Layer**: Provides concrete implementations
3. **Flutter Layer**: Adds UI-specific functionality

The API follows the pattern of using factory methods for creation rather than constructors:

```dart
// Get a meter from the meter provider
final meter = OTel.meterProvider().getMeter('component_name');

// Create a counter instrument
final counter = meter.createCounter('my_counter');

// Record measurements
counter.add(1, {'attribute_key': 'attribute_value'});
```

For asynchronous instruments:

```dart
// Create an observable counter
final observableCounter = meter.createObservableCounter(
  'my_observable_counter',
  () => [Measurement(10, {'attribute_key': 'attribute_value'})],
);
```

### Understanding Metric Types and When to Use Them

| Instrument Type         | Use Case                                                        | Example                          |
|-------------------------|-----------------------------------------------------------------|----------------------------------|
| Counter                 | Count things that only increase                                 | Request count, completed tasks   |
| UpDownCounter           | Count things that can increase or decrease                      | Active requests, queue size      |
| Histogram               | Measure distributions                                           | Request durations, payload sizes |
| Gauge                   | Record current value                                            | CPU usage, memory usage          |
| ObservableCounter       | Count things that only increase, collected on demand            | Total CPU time                   |
| ObservableUpDownCounter | Count things that can increase or decrease, collected on demand | Memory usage                     |
| ObservableGauge         | Record current value, collected on demand                       | Current temperature              |

## OpenTelemetry Logs API

The Logs API in OpenTelemetry provides a way to record log events from your application. These logs can be exported to an OpenTelemetry backend for analysis alongside traces and metrics.

### Concepts

- **LoggerProvider**: Entry point to the logs API, responsible for creating Loggers
- **Logger**: Used to emit log records
- **LogRecord**: Represents a single log event with body, severity, attributes, timestamps, and trace context
- **LogRecordProcessor**: Processes log records before export
- **LogRecordExporter**: Exports log records to backends

### Quick Start

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() async {
  // Initialize with logs enabled (default)
  await OTel.initialize(
    serviceName: 'my-service',
    enableLogs: true,  // Default is true
  );

  // Get a logger
  final logger = OTel.logger('my-component');

  // Emit log records
  logger.emit(
    body: 'Application started',
    severityNumber: Severity.INFO,
  );

  // Log with attributes
  logger.emit(
    body: 'User logged in',
    severityNumber: Severity.INFO,
    attributes: OTel.attributesFromMap({
      'user.id': 'user123',
      'user.role': 'admin',
    }),
  );

  // Log an error with exception
  try {
    throw Exception('Something went wrong');
  } catch (e, stackTrace) {
    logger.emit(
      body: 'Operation failed: $e',
      severityNumber: Severity.ERROR,
      attributes: OTel.attributesFromMap({
        'exception.type': e.runtimeType.toString(),
        'exception.stacktrace': stackTrace.toString(),
      }),
    );
  }
}
```

### Intercepting print() Calls

Dartastic OpenTelemetry can automatically capture `print()` calls and convert them to OpenTelemetry logs:

```dart
await OTel.initialize(
  serviceName: 'my-service',
  logPrint: true,  // Enable print interception
  logPrintLoggerName: 'dart.print',  // Optional custom logger name
);

// Use runWithPrintInterception to capture prints
OTel.runWithPrintInterception(() {
  print('This will be captured as an OTel log');
  print('So will this');
});

// For async code
await OTel.runWithPrintInterceptionAsync(() async {
  print('Async print captured');
  await someAsyncOperation();
});
```

### Log Severity Levels

| Severity | Use Case |
|----------|----------|
| `Severity.TRACE` / `Severity.TRACE2-4` | Fine-grained debugging |
| `Severity.DEBUG` / `Severity.DEBUG2-4` | Debug information |
| `Severity.INFO` / `Severity.INFO2-4` | General information |
| `Severity.WARN` / `Severity.WARN2-4` | Warning conditions |
| `Severity.ERROR` / `Severity.ERROR2-4` | Error conditions |
| `Severity.FATAL` / `Severity.FATAL2-4` | Critical failures |

### Custom Log Exporters

```dart
// Use a custom exporter
final customExporter = OtlpHttpLogRecordExporter(
  OtlpHttpLogRecordExporterConfig(
    endpoint: 'https://my-collector:4318',
    headers: {'Authorization': 'Bearer token'},
  ),
);

await OTel.initialize(
  serviceName: 'my-service',
  logRecordExporter: customExporter,
);
```

### Console Logging (Development)

```dart
// Use console exporter for development
await OTel.initialize(
  serviceName: 'my-service',
  logRecordProcessor: SimpleLogRecordProcessor(ConsoleLogRecordExporter()),
);
```

### Configuration via Environment Variables

Logs can be configured via environment variables:

```bash
# Set logs exporter (otlp, console, or none)
export OTEL_LOGS_EXPORTER=otlp

# Set logs-specific endpoint
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://logs-collector:4318

# Configure batch processor
export OTEL_BLRP_SCHEDULE_DELAY=5000
export OTEL_BLRP_MAX_QUEUE_SIZE=4096

# Set log record limits
export OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT=128
```

## Integration with Dartastic/Flutterrific

This API implementation follows the same pattern as the tracing API, where the creation of objects is managed through
factory methods. This allows for a clear separation between API and SDK, and ensures that the metrics and logs functionality
can be used in a no-op mode when the SDK is not initialized.

## Commercial Support

[Dartastic.io](https://dartastic.io) provides an OpenTelemetry Observability backend specifically built for Dart and Flutter applications. Features include:

- Enhanced tracing with source code integration
- Real-time user monitoring for Flutter apps
- Advanced dashboard and visualization
- Integration with native platforms
- Generous free tier and enterprise support options

## Roadmap

- [ ] Enhanced metrics support
- [ ] Support for Zipkin, Jaeger
- [ ] Integration with common Dart libraries (Dio, etc.)
- [ ] Context propagation through http, Android, iOS, WebViews


## CNCF Contribution and Alignment

This project aims to align with Cloud Native Computing Foundation (CNCF) best practices:

- **Interoperability** - Works with the broader OpenTelemetry ecosystem
- **Specification compliance** - Strictly follows the OpenTelemetry specification
- **Vendor neutrality** - Provides a vendor-neutral implementation


## License

Apache 2.0 - See the [LICENSE](LICENSE) file for details.

## Commercial Support

[Mindful Software](https://mindfulsoftware.com) offers paid Dartastic support, and consulting and developing on Flutter, OpenTelemetry and UI Architecture.

[Dartastic.io](https://dartastic.io) provides an OpenTelemetry support, training, consulting, enhanced private packages
and an Observability backend customized for Flutter apps, Dart backends, and any other service or process that produces
OpenTelemetry data.
Dartastic.io is built on open standards, specifically catering to Flutter and Dart applications with the ability to show
Dart source code lines and function calls from production errors and logs.

Dartastic.io offers:
- Free, paid, and enterprise support
- Packages with advanced features not available in the open source offering
- Native code integration and Real-Time User Monitoring for Flutter apps
- Multiple backends (Elastic, Grafana) customized for Flutter apps.

## AI Usage
Practically all code in Dartastic was generated via Claude. EVERY character 
is reviewed by a human.  Tests may need improved quality.

## Additional information

- Flutter developers should use the [Flutterific OTel SDK](https://pub.dev/packages/flutterrific_opentelemetry).
- Dart backend developers should use the [Dartastic OTel SDK](https://pub.dev/packages/dartastic_opentelemetry).
- Also see:
  - [Dartastic.io](https://dartastic.io/) the Flutter OTel backend
  - [The OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)
