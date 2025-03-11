# dartastic_opentelemetry

Dartastic is an [OpenTelemetry](https://opentelemetry.io/) SDK to add 
standard observability to Dart aund Flutter applications.

## Features

- 🚀 **Friendly API**: An easy to use, discoverable, immutable, typesafe API that feels familiar to Dart developers.
- 📐 **Standards Compliant**: Complies with the [OpenTelemetry specification](https://opentelemetry.io/docs/specs/) 
      so it's portable and future-proof.       
- 🌎 **Ecosystem**: 
  - [Dartastic.io](https://dartastic.io) is an OTel backend for Dart with a generous free tier,
  professional support and enterprise features. Monitor your Flutter users in real time.
  - [Flutterrific OTel](https://pub.dev/packages/flutterrific_opentelemetry) 
  adds Dartastic OTel to Flutter apps with ease.  Observe app routes, errors, web vitals and more with little effort.
- 💪🏻 **Powerful**: 
  - Propagate OpenTelemetry Context across async gaps, Isolates and backend calls. 
  - Pick from a rich set of Samplers including On/Off, probability and rate-limiting. 
  - Automatically capture platform resources on initialization.
  - No skimping - If it's optional in the spec, it's included in Dartastic.
  - A pluggable and extensible API and SDK enables implementation freedom.
  - Complete Metrics SDK - visualize perfromace in the wild
  - Logs SDK (coming soon) - capture logs and make them useful.
- 🧷 **Typesafe Semantics**: Ensure you're speaking the right language with a massive set of enums matching
  the [OpenTelemetry Semantics Conventions](https://opentelemetry.io/docs/specs/semconv/).
- 📊 **Excellent Performance**: Uses gRCP by default for efficient throughput. A performance test suite proves 
  benchmarks for speed and low overhead.
- 🐞 **Well Tested**: Good test coverage. Used in production apps at very large enterprises.
- 📃 **Quality Documentation**: If it's not clearly documented, it's a bug. Extensive examples and best practices are
provided. [Wonderous Dartastic](https://pub.dev/packages/wonderous_dartastic) demonstrates the Wonderous App instrumented
with OpenTelemetry. 

[Dartastic OTel](https://pub.dev/packages/dartastic_opentelemetry) is suitable for Dart backends, CLIs or any
Dart application. 

[opentelemetry_api](https://pub.dev/packages/opentelemetry_api) is the API for the Dartastic OTel SDK.
The `opentelemetry_api` exists as a standalone library to strictly adhere to the
OpenTelemetry specification which separates API and the SDK.  All OpenTelemetry API classes on in
`opentelemetry_api`.

Dartastic and Flutterrific OTel are made with 💙 by Michael Bushe at [Mindful Software](https://mindfulsoftware.com).

## Getting started

Include this in your pubspec.yaml:
```
dependencies:
  dartastic_opentelemetry: ^1.0.0
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
//TODO metrics and logging example
```

Since dartastic_opentelemetry exports all the classes of `opentelemetry_api`, refer to
`opentelemetry_api` for documentation of API classes.

See the `/example` folder for more examples.

# Dart and Flutter OTel Layers
Dartastic follows a multi-layered approach:

1. **API Layer**: Defines interfaces and provides no-op implementations
2. **SDK Layer**: (this library) Provides concrete implementations and SDK implementations that don't exist in the API, 
like `Resource` and `SpanProcessor`.
3. **Flutter Layer**: `flutterrific_opentelemetry` applies the SDK to Flutter apps and adds UI-specific helpers, 
especially UI semantics and Widget metric gatherers. 

# Dartastic OpenTelemetry Tracing SDK

The Tracing API in OpenTelemetry provides a way to follow what happens in your application's execution. Traces are 
generally short-lived execution paths with spans that occur within a trace.  A trace can extend across processes
and provides a way to tie all the executions across different asynchronous gaps, most commonly across microservices or
services in a monolith.  In Flutter apps, it can tie a client request to all the backend calls that service that
request.  Traces give problem solving superpowers to app developers because a developer can tie, for example,
the client parameters, the client's device and location to slow or error-prone backend processes.

## Concepts

- **TracerProvider**: Entry point to the tracing API, responsible for creating Tracers
- **Tracer**: Used to create Span and recording actions within a trace.
- **Span**: Used to record properties of an action and events that occur within and action. Spans are
- always ended with an OK or Error Status.

# Dartastic OpenTelemetry Metrics SDK

The Metrics API in OpenTelemetry provides a way to record measurements about your application. These measurements can 
be exported later as metrics, allowing you to monitor and analyze the performance and behavior of your application.
The Dartastic SDK implements metrics for Dart and Flutter apps ready for any OTel observability backend. 

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


## Additional information

- Flutter developers should use the [Flutterific OpenTelemetry SDK](https://pub.dev/packages/flutterrific_opentelemetry).
- Dart backend developers should use the [Dartastic OpenTelemetry SDK](https://pub.dev/packages/dartastic_opentelemetry).
- [Dartastic.io](https://dartastic.io/) the Flutter OTel backend
- [The OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)
