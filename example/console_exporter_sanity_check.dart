import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// App-specific attribute keys as a typed enum. Prefer enums over raw
/// strings so attribute keys are typo-free and discoverable. Always check
/// the OTel semantic conventions first (https://opentelemetry.io/docs/specs/semconv/)
/// — if one exists for your attribute, use the corresponding enum from
/// the API (e.g. User, Http) instead of inventing one.
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
    attributes: OTel.attributesFromSemanticMap({
      DemoAttribute.magicNumber: 42,
      DemoAttribute.canUseBoolean: true,
      DemoAttribute.intList: [42, 143],
      DemoAttribute.doubleList: [42.1, 143.4],
    }),
  );

  try {
    print('\nExecuting business logic...');
    importantFunction();
    rootSpan.addEventNow(
      'importantFunction completed',
      // attributesFromSemanticMap / attributesFromMap can throw with
      // bad types — OTel has typesafe attribute factories (used here)
      // which avoid that risk.
      OTel.attributes([
        OTel.attributeString(DemoAttribute.eventFoo.key, 'bar'),
        OTel.attributeBool(DemoAttribute.eventBaz.key, true),
      ]),
    );
  } catch (e, stackTrace) {
    print('\nHandling exception...');
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    // Per the OTel spec: recordException first, then setStatus(Error).
    rootSpan.recordException(e, stackTrace: stackTrace);
    rootSpan.setStatus(
      SpanStatusCode.Error,
      'Error running importantFunction: $e',
    );
    rethrow;
  } finally {
    print('\nEnding span (this should trigger ConsoleExporter export)...');
    rootSpan.end();
  }

  print('\nShutting down OpenTelemetry...');
  await OTel.shutdown();

  print('\n=== ConsoleExport Complete ===');
}

void importantFunction() {
  print('Hello from important function!');
  // Simulate some work
  for (var i = 0; i < 1000000; i++) {
    // Busy work to create some measurable duration
  }
}
