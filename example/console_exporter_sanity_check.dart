import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main(List<String> arguments) async {
  print('=== ConsoleExporter Sanity Test ===\n');

  // Enable debug logging to see what's happening internally
  //OTelLog.enableTraceLogging();
  //OTelLog.logFunction = print;

  print('Initializing with a SimpleSpanProcessor and a ConsoleExporter...');
  final consoleExporter = ConsoleExporter();
  await OTel.initialize(
      spanProcessor: SimpleSpanProcessor(consoleExporter));

  // Get the default tracer
  final tracer = OTel.tracer();

  print('\nCreating and starting root span...');
  // Create a new root span
  final rootSpan = tracer.startSpan(
    'root-operation',
    kind: SpanKind.producer,
    attributes: OTel.attributesFromMap({
      'readme.magic.number': 42,
      'can.I.use.a.boolean': true,
      'a.list.of.ints': [42, 143],
      'a.list.of.doubles': [42.1, 143.4],
    }),
  );

  try {
    print('\nExecuting business logic...');
    importantFunction();
    rootSpan.addEventNow(
      'importantFunction completed',
      // attributedFromMap can throw with bad types, OTel has typesafe attribute methods
      OTel.attributes([
        OTel.attributeString('event-foo', 'bar'),
        OTel.attributeBool('event-baz', true)
      ]),
    );
  } catch (e, s) {
    print('\nHandling exception...');
    rootSpan.recordException(e, stackTrace: s);
    rootSpan.setStatus(
        SpanStatusCode.Error, 'Error running importantFunction $e');
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
