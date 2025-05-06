## Testing

### Running Tests

The project includes a comprehensive test suite:

```bash
# Run all unit tests
make test

# Run tests safely in sequence (for problematic tests)
make test-safe

# Run web-specific tests (requires Chrome)
make test-web

# Run all checks including tests and coverage
make check
```

### Web Testing

Some components use platform-specific implementations, especially for web environments. To ensure these components work correctly in browsers:

```bash
# Run only web-specific tests in Chrome
make test-web
```

Web-specific tests verify JS interop functionality and browser API usage like Compression Streams. For more details on running and writing web tests, see `test/web/README.md`.

# OpenTelemetry SDK for Dart

[![Pub Version](https://img.shields.io/pub/v/opentelemetry_sdk.svg)](https://pub.dev/packages/opentelemetry_sdk)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenTelemetry Specification](https://img.shields.io/badge/OpenTelemetry-Specification-blueviolet)](https://opentelemetry.io/docs/specs/otel/)

A Dart implementation of the [OpenTelemetry](https://opentelemetry.io/) SDK that strictly adheres to the
OpenTelemetry (OTel) specification. This package provides a production-ready implementation of OpenTelemetry telemetry
collection and export for Dart applications.

## Overview

The OpenTelemetry SDK for Dart implements the OpenTelemetry specification, allowing you to collect telemetry data 
(traces, metrics, logs coming) from your Dart applications and export it to your backend of choice.

This SDK implements the [OpenTelemetry API for Dart](https://pub.dev/packages/opentelemetry_api) and provides additional components needed for a full telemetry solution:

- **Span processors** for processing and enriching spans
- **Exporters** for sending data to backends (OTLP, Console, Custom)
- **Resource providers** for adding service information
- **Samplers** for controlling data volume
- **Propagators** for cross-service context propagation

[Dartastic.io](https://dartastic.io) provides an OpenTelemetry Observability backend specifically built for Dart and Flutter applications, offering rich features like source code integration, function call visualization, and more.

## Features

- ✅ **Complete OpenTelemetry SDK implementation** for Dart
- ✅ **Strict adherence** to the OpenTelemetry specification
- ✅ **Support for all telemetry signals**:
  - Tracing with span processors and samplers
  - Metrics collection and aggregation
  - Logging integration
  - Context propagation
  - Baggage management
- ✅ **Multiple export protocols**:
  - OTLP over gRPC
  - OTLP over HTTP/JSON
  - Zipkin
  - Jaeger
  - Console (for debugging)
- ✅ **Configurable resource providers**
- ✅ **Cross-platform compatibility** - works across all Dart environments
- ✅ **Low overhead** with efficient processing and batching
- ✅ **Pluggable architecture** for custom extensions

## Getting Started

### Installation

Add the package to your `pubspec.yaml`:
The API is a separate package but it's not necessary since the SDK re-exports the relevant members.
```yaml
dependencies:
  opentelemetry_sdk: ^0.8.0
```

Then run:

```bash
dart pub get
```

### Basic Configuration

To start using the SDK with default settings:

```dart
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

void main() {
  // Initialize the SDK with defaults (console exporter)
  OTel.initialize(
    endpoint: 'http://localhost:4317',
    serviceName: 'my-service', 
    serviceVersion: '1.0.0'
  );
  
  // Your application code here
  
  // Shutdown the SDK before application exit
  OTel.shutdown();
}
```

### Advanced Configuration

For more control over the SDK configuration:

```dart
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

void main() async {
  // Create a resource describing your service
  final resource = OTel.resource([
    OTel.resourceAttribute('service.name', 'payment-service'),
    OTel.resourceAttribute('service.version', '1.2.3'),
    OTel.resourceAttribute('deployment.environment', 'production'),
  ]);
  
  // Configure span processors
  final batchProcessor = OTel.batchSpanProcessor(
    OTel.otlpHttpExporter(
      endpoint: 'https://api.example.com/v1/traces',
      headers: {'Authorization': 'Bearer token123'},
    ),
    maxQueueSize: 2048,
    scheduledDelayMillis: 5000,
  );
  
  // Configure samplers
  final sampler = OTel.parentBasedSampler(
    OTel.traceIdRatioSampler(0.1), // Sample 10% of traces
  );
  
  // Initialize the SDK with custom configuration
  OTel.initializeAdvanced(
    resource: resource,
    spanProcessors: [batchProcessor],
    sampler: sampler,
    propagators: [
      OTel.w3cTraceContextPropagator(),
      OTel.w3cBaggagePropagator(),
    ],
  );
  
  // Application shutdown
  await OTel.shutdownAsync(); // Flush pending telemetry
}
```

## Usage Examples

### Tracing Example

```dart
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

void main() {
  // Initialize the SDK
  OTel.initialize(
    endpoint: 'http://localhost:4317',
    serviceName: 'example-service',
  );
  
  // Get a tracer
  final tracer = OTel.tracer('example-component');
  
  // Create and use a span
  tracer.startActiveSpan(
    name: 'main-operation', 
    kind: SpanKind.server,
    fn: (span) {
      // Your business logic here
      span.setAttribute('operation.type', 'example');
      
      try {
        // Do work - call a nested operation
        performSubOperation(tracer);
        span.setStatus(SpanStatusCode.Ok);
        return 'Operation completed successfully';
      } catch (e, stackTrace) {
        // Record the error
        span
          ..setStatus(SpanStatusCode.Error, e.toString())
          ..recordException(e, stackTrace: stackTrace);
        rethrow;
      }
    },
  );
  
  // Always shutdown the SDK before the application exits
  OTel.shutdown();
}

void performSubOperation(APITracer tracer) {
  tracer.startActiveSpan(
    name: 'sub-operation', 
    fn: (span) {
      // Sub-operation logic
      span.setAttribute('operation.value', 42);
      span.setStatus(SpanStatusCode.Ok);
      return 'Sub-operation complete';
    },
  );
}
```

### HTTP Client Instrumentation Example

```dart
import 'package:http/http.dart' as http;
import 'package:opentelemetry_sdk/opentelemetry_sdk.dart';

Future<void> main() async {
  // Initialize the SDK
  OTel.initialize(
    endpoint: 'http://localhost:4317',
    serviceName: 'http-client-example',
  );
  
  final tracer = OTel.tracer('http-client');
  
  // Make an HTTP request with tracing
  final result = await tracer.startActiveSpanAsync(
    name: 'GET /api/users',
    kind: SpanKind.client,
    fn: (span) async {
      try {
        // Add HTTP attributes
        span.setAttribute('http.method', 'GET');
        span.setAttribute('http.url', 'https://api.example.com/users');
        
        // Extract the current context's headers for propagation
        final headers = <String, String>{};
        OTel.propagator().inject(
          Context.current,
          headers,
          defaultSetter,
        );
        
        // Make the HTTP request with propagation headers
        final response = await http.get(
          Uri.parse('https://api.example.com/users'),
          headers: headers,
        );
        
        // Record response details
        span.setAttribute('http.status_code', response.statusCode);
        
        if (response.statusCode >= 400) {
          span.setStatus(SpanStatusCode.Error, 'HTTP error ${response.statusCode}');
        } else {
          span.setStatus(SpanStatusCode.Ok);
        }
        
        return response;
      } catch (e, stackTrace) {
        span.recordException(e, stackTrace: stackTrace);
        span.setStatus(SpanStatusCode.Error, e.toString());
        rethrow;
      }
    },
  );
  
  print('Response status: ${result.statusCode}');
  
  // Shut down the SDK
  await OTel.shutdownAsync();
}

void defaultSetter(Map<String, String> carrier, String key, String value) {
  carrier[key] = value;
}
```

More examples can be found in the `/example` directory.

## Configuration Options

### Exporters

The SDK provides multiple exporter options:

```dart
// OTLP over gRPC
final otlpGrpcExporter = OTel.otlpGrpcExporter(
  endpoint: 'http://collector:4317',
  headers: {'x-api-key': 'your-api-key'},
);

// OTLP over HTTP/JSON
final otlpHttpExporter = OTel.otlpHttpExporter(
  endpoint: 'http://collector:4318/v1/traces',
  headers: {'x-api-key': 'your-api-key'},
);

// Zipkin exporter
final zipkinExporter = OTel.zipkinExporter(
  endpoint: 'http://zipkin:9411/api/v2/spans',
);

// Console exporter (for debugging)
final consoleExporter = OTel.consoleExporter();
```

### Span Processors

Configure how spans are processed before export:

```dart
// Simple span processor - exports immediately
final simpleProcessor = OTel.simpleSpanProcessor(exporter);

// Batch span processor - batches spans for efficiency
final batchProcessor = OTel.batchSpanProcessor(
  exporter,
  maxQueueSize: 2048,
  scheduledDelayMillis: 5000,
  maxExportBatchSize: 512,
);
```

### Samplers

Control which spans are sampled:

```dart
// Always sample
final alwaysOnSampler = OTel.alwaysOnSampler();

// Never sample
final alwaysOffSampler = OTel.alwaysOffSampler();

// Sample based on trace ID
final traceIdRatioSampler = OTel.traceIdRatioSampler(0.1); // 10% sampling

// Parent-based sampling
final parentSampler = OTel.parentBasedSampler(
  traceIdRatioSampler, // root sampler
);
```

### Propagators

Configure context propagation:

```dart
// W3C Trace Context propagator
final traceContextPropagator = OTel.w3cTraceContextPropagator();

// W3C Baggage propagator
final baggagePropagator = OTel.w3cBaggagePropagator();

// Composite propagator (combines multiple propagators)
final compositePropagator = OTel.compositePropagator([
  traceContextPropagator,
  baggagePropagator,
]);
```

## Advanced Topics

### Custom Span Processors

You can create custom span processors by implementing the `SpanProcessor` interface:

```dart
class CustomSpanProcessor implements SpanProcessor {
  @override
  void onStart(ReadWriteSpan span, Context parentContext) {
    // Add custom logic when a span starts
  }

  @override
  void onEnd(ReadOnlySpan span) {
    // Add custom logic when a span ends
  }

  @override
  Future<void> shutdown() async {
    // Cleanup resources
  }

  @override
  Future<void> forceFlush() async {
    // Force export of any pending spans
  }
}
```

### Custom Resource Providers

Implement custom resource providers to add additional service information:

```dart
class EnvironmentResourceProvider implements ResourceProvider {
  @override
  Resource get() {
    final envVars = Platform.environment;
    return Resource.create([
      OTel.resourceAttribute('host.name', envVars['HOSTNAME'] ?? 'unknown'),
      OTel.resourceAttribute('deployment.environment', 
                            envVars['ENV'] ?? 'development'),
    ]);
  }
}
```

### Custom Exporters

Implement your own exporters by extending the `SpanExporter` interface:

```dart
class CustomExporter implements SpanExporter {
  @override
  Future<ExportResult> export(List<ReadOnlySpan> spans) async {
    // Custom export logic
    for (final span in spans) {
      // Process and send the span data
    }
    return ExportResult.success;
  }

  @override
  Future<void> shutdown() async {
    // Clean up resources
  }

  @override
  Future<void> force() async {
    // Forcefully flush any pending spans
  }
}
```

## Integration with OpenTelemetry Collector

For production deployments, it's recommended to use the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/):

```dart
// Configure to send to an OpenTelemetry Collector
OTel.initialize(
  endpoint: 'http://otel-collector:4317', // gRPC endpoint
  serviceName: 'my-service',
  // Alternative HTTP endpoint: 'http://otel-collector:4318/v1/traces'
);
```

## Platform Support

- ✅ **Dart VM** - For server applications
- ✅ **Flutter** - For mobile applications (see also [flutterrific_opentelemetry](https://pub.dev/packages/flutterrific_opentelemetry))
- ✅ **Web** - For browser applications (with some limitations)

## Commercial Support

[Dartastic.io](https://dartastic.io) provides an OpenTelemetry Observability backend specifically built for Dart and Flutter applications. Features include:

- Enhanced tracing with source code integration
- Real-time user monitoring for Flutter apps
- Advanced dashboard and visualization
- Integration with native platforms
- Generous free tier and enterprise support options

## Roadmap

- [ ] Enhanced metrics support
- [ ] Additional exporters
- [ ] Automatic instrumentation for common Dart libraries
- [ ] Configuration through environment variables
- [ ] Enhanced context propagation options

## CNCF Contribution and Alignment

This project aims to align with Cloud Native Computing Foundation (CNCF) best practices:

- **Interoperability** - Works with the broader OpenTelemetry ecosystem
- **Specification compliance** - Strictly follows the OpenTelemetry specification
- **Vendor neutrality** - Provides a vendor-neutral implementation


## License

Apache 2.0 - See the [LICENSE](LICENSE) file for details.

## Commercial Support

[Dartastic.io](https://dartastic.io) provides an OpenTelemetry support, training, consulting, enhanced private packages
and an Observability backend customized for Flutter apps, Dart backends, and any other service or process that produces
OpenTelemetry data.
Dartastic.io is built on open standards, specifically catering to Flutter and Dart applications with the ability to show
Dart source code lines and function calls from production errors and logs.

Dartastic.io offers:
- Various levels of free, paid, and enterprise support
- Packages with advanced features not available in the open source offering
- Native code integration and Real-Time User Monitoring for Flutter apps
- Multiple backends (Elastic, Grafana) customized for Flutter apps.

## Additional Information
- Flutter developers should use the [Flutterific OTel SDK](https://pub.dev/packages/flutterrific_opentelemetry).
- Dart backend developers should use the [Dartastic OTel SDK](https://pub.dev/packages/dartastic_opentelemetry).
- [Dartastic.io](https://dartastic.io/) the Flutter OTel backend
- [The OpenTelemetry Specifiction](https://opentelemetry.io/docs/specs/otel/)

## Acknowledgements

This OpenTelemetry SDK for Dart is made with 💙 by Michael Bushe at [Mindful Software](https://mindfulsoftware.com).

