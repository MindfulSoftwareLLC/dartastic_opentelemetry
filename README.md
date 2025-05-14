# OpenTelemetry SDK for Dart

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenTelemetry Specification](https://img.shields.io/badge/OpenTelemetry-Specification-blueviolet)](https://opentelemetry.io/docs/specs/otel/)

Dartastic is an [OpenTelemetry](https://opentelemetry.io/) SDK to add standard observability to Dart applications.

This SDK has been proposed for [Donation to the CNCF](https://github.com/open-telemetry/community/issues/2718).
We need YOU to grow the Dartastic community and make this SDK the standard for Flutter and Dart OTel.
Please use it, submit issues, support us with stars and contribute PRs. We are looking for contributors and maintainers.
Also, please support the development by subscribing at [Dartastic.io][https://dartastic.io] and gain early access to the
Flutter SDK and the Wondrous Demo.

## Features

- 🚀 **Friendly API**: An easy to use, discoverable, immutable, typesafe API that feels familiar to Dart developers.
- 📐 **Standards Compliant**: Complies with the [OpenTelemetry specification](https://opentelemetry.io/docs/specs/)
  so it's portable and future-proof.
- 🌎 **Ecosystem**:
  - [Dartastic.io](https://dartastic.io) is an OTel backend for Dart with a generous free tier,
    professional support and enterprise features.
  - [Flutterrific OTel](https://pub.dev/packages/flutterrific_opentelemetry) (Coming soon - sign up at Dartastic.io for early access)
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
  provided [Wonderous Dartastic](https://pub.dev/packages/wonderous_dartastic) demonstrates the Wonderous App instrumented
  with OpenTelemetry.
- ✅ **Supported Telemetry Signals and Features **:
  - Tracing with span processors and samplers
  - Metrics collection and aggregation
  - Context propagation
  - Baggage management
  - Logging is not available yet

[Dartastic OTel](https://pub.dev/packages/dartastic_opentelemetry) is suitable for Dart backends, CLIs or any
Dart application.

[opentelemetry_api](https://pub.dev/packages/opentelemetry_api) is the API for the Dartastic OTel SDK.
The `opentelemetry_api` exists as a standalone library to strictly adhere to the
OpenTelemetry specification which separates API and the SDK.  All OpenTelemetry API classes on in
`opentelemetry_api`.

[Flutterrific OTel](https://pub.dev/packages/flutterrific_opentelemetry) adds Dartastic OTel to Flutter apps with ease.  Sign Up at Dartastic.io for early access to this soon to be open source.

[Dartastic.io](https://dartastic.io) is an OpenTelemetry backend based on Elastic with a generous free tier.

Dartastic and Flutterrific OTel are made with 💙 by Michael Bushe at [Mindful Software](https://mindfulsoftware.com),
the Flutter experts with support from [SEMplicity, Inc.](https://semplicityinc.com), the Elastic experts.

## Getting started

Include this in your pubspec.yaml:
```
dependencies:
  dartastic_opentelemetry: ^0.8.3
```

The entrypoint to the SDK is the `OTel` class.  `OTel` has static "factory" methods for all
OTel API and SDK objects.  `OTel` needs to be initialized first to point to an OpenTelemetry
backend.  Initialization does a lot of work under the hood including gathering a rich set of
standard resources for any OS that Dart runs in.  It prepares for the creation of the global
default `TracerProvider` with the serviceName and a default `Tracer`, both created on first use.

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  OTel.initialize(
      serviceName: 'powerful-backend-service',
      serviceVersion: '2.0',
      tracerName: 'data-microservice',
      tracerVersion: '1.1.11',
      //OTel standard tenant_id, required for Dartastic.io
      tenantId: 'valued-customer-id',
      //required for the Dartastic.io backend
      dartasticAPIKey: '123456',
      resourceAttributes: {
        // Always consult the OTel Semantic Conventions to find an existing
        // convention name for an attribute:
        // https://opentelemetry.io/docs/specs/semconv/
        //--dart-define environment=dev
        '${DeploymentNames.deploymentEnvironmentName}: String.fromEnvironment('
        environment
        '),//See https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/
        //--dart-define pod-name=powerful-dart-pod
        '${DeploymentNames.k8sPodName}: String.fromEnvironment('
        pod - name
        '),//See https://opentelemetry.io/docs/specs/semconv/resource/#kubernetes
      }
  );

  // Get the default tracer
  var tracer = OTel.tracer();

  // Create a new root span
  final rootSpan = tracer.startSpan(
    'root-operation',
    attributes: OTel.attributesFromMap({
      //SourceCode attributes are atypical, this is showing off the extensive semantics
      SourceCodeNames.codeFunctionName.key: 'main',
      // The spec limits attribute values to String, bool, int, double and lists thereof.
      'readme.magic.number': 42,
      'can.I.use.a.boolean': true,
      'a.list.of.ints': [42, 143],
      'a.list.of.doubles': [42.1, 143.4],
    }),
  );

  try {
    importantFunction();
    rootSpan.addEventNow('importantFunction completed', 
            // attributedFromMap can throw with bad types, OTel has typesafe attribute methods
            OTel.attributes([
              OTel.attributeString('event-foo', 'bar'),
              OTel.attributeBool('event-baz', true)
            ]));
  } catch (e, s) {
    span.recordException(e, stackTrace: s);
    span.setStatus(SpanStatusCode.Error, 'Error running importantFunction $e');
  } finally {
    // Ending a span sets the span status to SpanStatusCode.Ok, unless 
    // the span status has already been set, per the OpenTelemetry Specification
    // See https://opentelemetry.io/docs/specs/otel/trace/api/#set-status
    span.end();
  }
}

```

Since dartastic_opentelemetry exports all the classes of `opentelemetry_api`, refer to
`opentelemetry_api` for documenation of API classes.

See the `/example` folder for more examples.

# OpenTelemetry Metrics API

The Metrics API in OpenTelemetry provides a way to record measurements about your application. These measurements can be exported later as metrics, allowing you to monitor and analyze the performance and behavior of your application.

## Concepts

- **MeterProvider**: Entry point to the metrics API, responsible for creating Meters
- **Meter**: Used to create instruments for recording measurements
- **Instrument**: Used to record measurements
  - Synchronous instruments: record measurements at the moment of calling their APIs
  - Asynchronous instruments: collect measurements on demand via callbacks

## Instrument Types

- **Counter**: Synchronous, monotonic increasing counter (can only go up)
- **UpDownCounter**: Synchronous, non-monotonic counter (can go up or down)
- **Histogram**: Synchronous, aggregable measurements with statistical distributions
- **Gauge**: Synchronous, non-additive value that represents current state
- **ObservableCounter**: Asynchronous version of Counter
- **ObservableUpDownCounter**: Asynchronous version of UpDownCounter
- **ObservableGauge**: Asynchronous version of Gauge

## Usage Pattern

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

## Understanding Metric Types and When to Use Them

| Instrument Type | Use Case | Example |
|----------------|----------|---------|
| Counter | Count things that only increase | Request count, completed tasks |
| UpDownCounter | Count things that can increase or decrease | Active requests, queue size |
| Histogram | Measure distributions | Request durations, payload sizes |
| Gauge | Record current value | CPU usage, memory usage |
| ObservableCounter | Count things that only increase, collected on demand | Total CPU time |
| ObservableUpDownCounter | Count things that can increase or decrease, collected on demand | Memory usage |
| ObservableGauge | Record current value, collected on demand | Current temperature |

## Integration with Dartastic/Flutterrific

This API implementation follows the same pattern as the tracing API, where the creation of objects is managed through
factory methods. This allows for a clear separation between API and SDK, and ensures that the metrics functionality
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


## Additional information

- Flutter developers should use the [Flutterific OTel SDK](https://pub.dev/packages/flutterrific_otel_sdk).
- Dart backend developers should use the [Dartastic OTel SDK](https://pub.dev/packages/dartastic_otel_sdk).
- Also see:
  - [Dartastic.io](https://dartastic.io/) the Flutter OTel backend
  - [The OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)
