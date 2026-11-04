// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/trace/export/test_file_exporter.dart';
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';

void main() {
  late Attributes attributes;
  const encoded = '{"bytes":"aGk=","special":["NaN","Infinity",'
      r'"-Infinity"],"null":null,"text":"a\"b\nc"}';

  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'non-otlp-test',
      detectPlatformResources: false,
      spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
      enableMetrics: false,
      enableLogs: false,
    );
    attributes = OTel.attributesFromMap({
      'payload': {
        'bytes': Uint8List.fromList([104, 105]),
        'special': [double.nan, double.infinity, double.negativeInfinity],
        'null': null,
        'text': 'a"b\nc',
      },
    });
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  Span makeSpan() {
    final span = OTel.tracer().startSpan('encoded', attributes: attributes);
    span.addEventNow('event', attributes);
    span.addSpanLink(OTel.spanLink(span.spanContext, attributes: attributes));
    span.end();
    return span;
  }

  test('console spans, events and links use non-OTLP JSON', () async {
    final lines = <String>[];
    final span = makeSpan();
    await runZoned(() => ConsoleExporter().export([span]),
        zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => lines.add(line)));
    expect('payload: $encoded'.allMatches(lines.join('\n')), hasLength(3));
  });

  test('console log bodies and attributes use non-OTLP encoding', () async {
    final lines = <String>[];
    final exporter = ConsoleLogRecordExporter(printFunction: lines.add);
    addTearDown(exporter.shutdown);
    final scope = OTel.instrumentationScope(name: 'encoding', version: '1.2');
    expect(
        await exporter.export([
          SDKLogRecord(
              instrumentationScope: scope,
              body: attributes.toMap()['payload']!.value,
              attributes: attributes),
          SDKLogRecord(
              instrumentationScope: scope,
              body: Uint8List.fromList([104, 105])),
          SDKLogRecord(instrumentationScope: scope, body: const AnyValueNull()),
        ]),
        ExportResult.success);
    expect(lines[0], '[encoding:1.2] $encoded {payload=$encoded}');
    expect(lines[1], '[encoding:1.2] aGk=');
    expect(lines[2], '[encoding:1.2] ');
  });

  test('JSON file export supports bytes and non-finite doubles', () async {
    final directory = await Directory.systemTemp.createTemp('otel-json-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/spans.json');
    final exporter = TestFileExporter(file.path);
    addTearDown(exporter.shutdown);
    await exporter.export([makeSpan()]);
    final lines = await file.readAsLines();
    final exported = (jsonDecode(lines.last) as List).single as Map;
    expect(exported['attributes'], {'payload': jsonDecode(encoded)});
  });

  test('Prometheus escapes the encoded JSON and preserves scalar labels',
      () async {
    final exporter = PrometheusExporter();
    addTearDown(exporter.shutdown);
    final now = DateTime.utc(2026);
    final labels = attributes.copyWithAttributes(OTel.attributesFromMap({
      'nan': double.nan,
      'infinity': double.infinity,
      'negative': double.negativeInfinity,
      'empty': null,
    }));
    expect(
        await exporter.export(
            MetricData(resource: OTel.resource(OTel.attributes()), metrics: [
          Metric(name: 'encoded', type: MetricType.gauge, points: [
            MetricPoint<int>(
                attributes: labels, startTime: now, endTime: now, value: 1),
          ])
        ])),
        isTrue);
    expect(
        exporter.prometheusData,
        contains(
            r'payload="{\"bytes\":\"aGk=\",\"special\":[\"NaN\",\"Infinity\",\"-Infinity\"],\"null\":null,\"text\":\"a\\\"b\\nc\"}"'));
    expect(exporter.prometheusData, contains('nan="NaN"'));
    expect(exporter.prometheusData, contains('infinity="Infinity"'));
    expect(exporter.prometheusData, contains('negative="-Infinity"'));
    expect(exporter.prometheusData, contains('empty=""'));
  });
}
