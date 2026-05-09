import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// App-specific attribute keys as a typed enum. Prefer enums over raw
/// strings so attribute keys are typo-free and discoverable. Always check
/// the OTel semantic conventions first (https://opentelemetry.io/docs/specs/semconv/)
/// — if one exists for your attribute, use the corresponding enum from
/// the API (e.g. UserSemantics, HttpResource) instead of inventing one.
enum DemoAttribute implements OTelSemantic {
  magicNumber('demo.magic.number'),
  canUseBoolean('demo.can_use_boolean'),
  intList('demo.int_list'),
  doubleList('demo.double_list'),
  eventFoo('demo.event_foo'),
  eventBaz('demo.event_baz');

  @override
  final String key;

  @override
  String toString() => key;

  const DemoAttribute(this.key);
}

Future<void> main(List<String> arguments) async {
  print('=== ConsoleExporter Sanity Test ===\n');

  // Enable debug logging to see what's happening internally
  //OTelLog.enableTraceLogging();
  //OTelLog.logFunction = print;

  print('Initializing with a SimpleSpanProcessor and a ConsoleExporter...');
  final consoleExporter = ConsoleExporter();
  await OTel.initialize(spanProcessor: SimpleSpanProcessor(consoleExporter));

  // Get the default tracer
  final tracer = OTel.tracer();

  print('\nCreating and starting root span...');
  // Create a new root span
  final rootSpan = tracer.startSpan(
    'root-operation',
    kind: SpanKind.producer,
    attributes: OTel.attributesFromMap({
      DemoAttribute.magicNumber.key: 42,
      DemoAttribute.canUseBoolean.key: true,
      DemoAttribute.intList.key: [42, 143],
      DemoAttribute.doubleList.key: [42.1, 143.4],
    }),
  );

  try {
    print('\nExecuting business logic...');
    importantFunction();
    rootSpan.addEventNow(
      'importantFunction completed',
      // attributesFromMap can throw with bad types — OTel has typesafe
      // attribute methods (used here) which avoid that risk.
      OTel.attributes([
        OTel.attributeString(DemoAttribute.eventFoo.key, 'bar'),
        OTel.attributeBool(DemoAttribute.eventBaz.key, true),
      ]),
    );
    // Application code may set Ok explicitly on success
    // (see https://opentelemetry.io/docs/specs/otel/trace/api/#set-status).
    rootSpan.setStatus(SpanStatusCode.Ok);
  } catch (e, stackTrace) {
    print('\nHandling exception...');
    // Per the OTel spec: recordException first, then setStatus(Error).
    rootSpan.recordException(e, stackTrace: stackTrace);
    rootSpan.setStatus(
      SpanStatusCode.Error,
      'Error running importantFunction: $e',
    );
    rethrow;
  } finally {
    print('\nEnding span (this should trigger ConsoleExporter export)...');
    // Ending a span sets the span status to SpanStatusCode.Ok, unless
    // the span status has already been set, per the OpenTelemetry Specification
    // See https://opentelemetry.io/docs/specs/otel/trace/api/#set-status
    rootSpan.end();
  }

  print('\nShutting down OpenTelemetry...');
  await OTel.shutdown();

  print('\n=== ConsoleExport Complete ===');
}

void importantFunction() {
  print('Hello from important function!');
  // Simulate some work
  for (int i = 0; i < 1000000; i++) {
    // Busy work to create some measurable duration
  }
}
