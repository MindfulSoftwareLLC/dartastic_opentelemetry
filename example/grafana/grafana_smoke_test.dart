import 'dart:async';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  // Initialize from env (protocol/endpoint/headers/etc.)
  print(const String.fromEnvironment('OTEL_EXPORTER_OTLP_PROTOCOL'));
  print(const String.fromEnvironment('OTEL_EXPORTER_OTLP_ENDPOINT'));
  print(const String.fromEnvironment('OTEL_EXPORTER_OTLP_HEADERS'));

  await OTel.initialize();

  // Emit a simple span
  final tracer =
      OTel.tracerProvider().getTracer('dartastic-smoketest', version: '1.0.0');
  await tracer.startActiveSpanAsync(
      name: 'gc-smoke-span',
      fn: (span) async {
        span.addAttributes(Attributes.of({'smoke': true}));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        span.end();
      });

  await OTel.shutdown();
  print('Sent smoke test span(s). Check Grafana Cloud Explore/Traces.');
}
