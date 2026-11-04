// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart'
    as proto;
import 'package:dartastic_opentelemetry/src/export/otlp_any_value.dart';
import 'package:dartastic_opentelemetry/src/metrics/export/otlp/metric_transformer.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:test/test.dart';

import '../../testing_utils/in_memory_span_exporter.dart';
import '../../testing_utils/memory_log_record_exporter.dart';
import '../../testing_utils/memory_metric_exporter.dart';

// Include zero/false/empty values to catch accidental omission of oneof fields.
Map<String, Object?> values() => {
      'string': '',
      'bool': false,
      'int': 0,
      'double': 0.0,
      'large': 9007199254740993,
      'bytes': Uint8List.fromList([0, 128, 255]),
      'null': null,
      'emptyArray': <Object?>[],
      'emptyMap': <String, Object?>{},
      'emptyBytes': Uint8List(0),
      'rating': BrowserWebVitalRating.needsImprovement,
      'state': HwState.needsCleaning,
      'nested': <Object?>[
        1,
        2.5,
        null,
        <Object?>[true, 'text'],
        <String, Object?>{
          'bytes': Uint8List.fromList([42]),
          'null': null
        },
      ],
    };

Map<String, proto.AnyValue> expectedValues() => {
      'string': proto.AnyValue(stringValue: ''),
      'bool': proto.AnyValue(boolValue: false),
      'int': proto.AnyValue(intValue: Int64.ZERO),
      'double': proto.AnyValue(doubleValue: 0.0),
      'large': proto.AnyValue(intValue: Int64.parseInt('9007199254740993')),
      'bytes': proto.AnyValue(bytesValue: [0, 128, 255]),
      'null': proto.AnyValue(),
      'emptyArray': proto.AnyValue(arrayValue: proto.ArrayValue()),
      'emptyMap': proto.AnyValue(kvlistValue: proto.KeyValueList()),
      'emptyBytes': proto.AnyValue(bytesValue: []),
      'rating': proto.AnyValue(stringValue: 'needs-improvement'),
      'state': proto.AnyValue(stringValue: 'needs_cleaning'),
      'nested': proto.AnyValue(
        arrayValue: proto.ArrayValue(values: [
          proto.AnyValue(intValue: Int64(1)),
          proto.AnyValue(doubleValue: 2.5),
          proto.AnyValue(),
          proto.AnyValue(
              arrayValue: proto.ArrayValue(values: [
            proto.AnyValue(boolValue: true),
            proto.AnyValue(stringValue: 'text'),
          ])),
          proto.AnyValue(
              kvlistValue: proto.KeyValueList(values: [
            proto.KeyValue(
                key: 'bytes', value: proto.AnyValue(bytesValue: [42])),
            proto.KeyValue(key: 'null', value: proto.AnyValue()),
          ])),
        ]),
      ),
    };

void expectAttributes(List<proto.KeyValue> attributes) {
  final actual = {for (final attr in attributes) attr.key: attr.value};
  for (final entry in expectedValues().entries) {
    expect(actual[entry.key], entry.value, reason: entry.key);
    expect(actual[entry.key]!.whichValue(), entry.value.whichValue(),
        reason: 'oneof presence for ${entry.key}');
  }
}

void main() {
  late Attributes attributes;
  late Resource resource;
  late InstrumentationScope scope;

  setUp(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'any-value-test',
      detectPlatformResources: false,
      spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
      enableMetrics: false,
      enableLogs: false,
    );
    attributes = OTel.attributesFromMap(values());
    resource = OTel.resource(attributes);
    scope =
        OTel.instrumentationScope(name: 'any-value', attributes: attributes);
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  Span makeSpan() {
    final tracer =
        OTel.tracerProvider().getTracer('any-value', attributes: attributes);
    final span = tracer.startSpan('structured', attributes: attributes);
    span.addEvent(OTel.spanEventNow('event', attributes));
    span.addSpanLink(OTel.spanLink(span.spanContext, attributes: attributes));
    span.end();
    return span;
  }

  SDKLogRecord makeLog({Object? body}) => SDKLogRecord(
        instrumentationScope: scope,
        resource: resource,
        body: body,
        attributes: attributes,
      );

  MetricData makeMetrics() {
    final now = DateTime.utc(2026);
    final exemplar = Exemplar(
        attributes: OTel.attributes(),
        filteredAttributes: attributes,
        timestamp: now,
        value: 1);
    return MetricData(resource: resource, metrics: [
      for (final type in MetricType.values)
        Metric(name: type.name, type: type, points: [
          MetricPoint<Object>(
              attributes: attributes,
              startTime: now,
              endTime: now,
              value: type == MetricType.histogram
                  ? HistogramValue(
                      sum: 1, count: 1, boundaries: [2], bucketCounts: [1, 0])
                  : 1,
              exemplars: [exemplar]),
        ]),
    ]);
  }

  test('span attributes, events, links, resource and scope retain types', () {
    OTel.tracerProvider().resource = resource;
    final request = OtlpSpanTransformer.transformSpans([makeSpan()]);
    final decoded =
        proto.ExportTraceServiceRequest.fromBuffer(request.writeToBuffer());
    final group = decoded.resourceSpans.single;
    expectAttributes(group.resource.attributes);
    expectAttributes(group.scopeSpans.single.scope.attributes);
    final span = group.scopeSpans.single.spans.single;
    expectAttributes(span.attributes);
    expectAttributes(span.events.single.attributes);
    expectAttributes(span.links.single.attributes);
  });

  test('logs retain all body types, attributes, resource and scope', () {
    final request = OtlpLogRecordTransformer.transformLogRecords([
      for (final value in values().values)
        makeLog(body: value ?? const AnyValueNull()),
      makeLog(),
    ]);
    final decoded =
        proto.ExportLogsServiceRequest.fromBuffer(request.writeToBuffer());
    final group = decoded.resourceLogs.single;
    expectAttributes(group.resource.attributes);
    expectAttributes(group.scopeLogs.single.scope.attributes);
    final logs = group.scopeLogs.single.logRecords;
    final expected = expectedValues().values.toList();
    for (var i = 0; i < expected.length; i++) {
      expect(logs[i].hasBody(), isTrue);
      expect(logs[i].body, expected[i]);
      expectAttributes(logs[i].attributes);
    }
    expect(logs.last.hasBody(), isFalse);
  });

  test(
      'metric resources, sum/gauge/histogram points and exemplars retain types',
      () {
    final request = MetricTransformer.transformMetrics(makeMetrics(),
        exemplarFilter: MetricsExemplarFilter.alwaysOn);
    final decoded =
        proto.ExportMetricsServiceRequest.fromBuffer(request.writeToBuffer());
    final group = decoded.resourceMetrics.single;
    expectAttributes(group.resource.attributes);
    for (final metric in group.scopeMetrics.single.metrics) {
      if (metric.hasHistogram()) {
        final point = metric.histogram.dataPoints.single;
        expectAttributes(point.attributes);
        expectAttributes(point.exemplars.single.filteredAttributes);
      } else {
        final point = metric.hasGauge()
            ? metric.gauge.dataPoints.single
            : metric.sum.dataPoints.single;
        expectAttributes(point.attributes);
        expectAttributes(point.exemplars.single.filteredAttributes);
      }
    }
  });

  test(
      'SDK logger converts bodies before processors and forwards wrapped values',
      () async {
    final exporter = MemoryLogRecordExporter();
    OTel.loggerProvider()
        .addLogRecordProcessor(SimpleLogRecordProcessor(exporter));
    final logger = OTel.logger('any-value');
    final input = values();
    logger.emit(body: input);
    await OTel.loggerProvider().forceFlush();
    final record = exporter.exportedLogRecords.single;
    expect(record.body, isA<AnyValueMap>());
    input.clear();
    expect((record.body! as AnyValueMap).value, hasLength(values().length));
    logger.emit(body: record.body);
    await OTel.loggerProvider().forceFlush();
    expect(exporter.exportedLogRecords.last.body, same(record.body));
    final clone = (record as ReadWriteLogRecord).clone();
    expect(clone.body, same(record.body));
    clone.body = Uint8List.fromList([255]);
    expect(clone.body, isA<AnyValueBytes>());
    clone.body = const AnyValueNull();
    expect(clone.body, isA<AnyValueNull>());
    clone.body = null;
    expect(clone.body, isNull);
  });

  test('nullable map entry points work before and after SDK initialization',
      () async {
    await OTel.reset();
    final before = OTel.attributesFromMap(values());
    expectAttributes(otlpAttributes(before));
    await OTel.initialize(
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
        enableLogs: false,
        enableMetrics: false);
    expectAttributes(otlpAttributes(OTel.attributesFromMap(values())));
    final result = ObservableResult<int>()..observeWithMap(1, values());
    expectAttributes(otlpAttributes(result.measurements.single.attributes!));
    final merged = OTel.resource(before).merge(OTel.resource(
        OTel.attributesFromMap({'null': null, 'bytes': values()['bytes']})));
    expectAttributes(otlpAttributes(merged.attributes));
  });

  test('SDK semantic map helpers preserve null before and after initialization',
      () async {
    await OTel.reset();
    void checkHelpers() {
      final expected = OTel.attributesFromMap({'http.request.method': null});
      final attributes = [
        OTel.attributesFromSemanticMap(
            <OTelSemantic, Object?>{Http.httpRequestMethod: null}),
        OTel.attributesOf<Http>(<Http, Object?>{Http.httpRequestMethod: null}),
      ];
      for (final attrs in attributes) {
        expect(attrs, expected);
        expect(
            attrs.toMap()['http.request.method']!.value, isA<AnyValueNull>());
        final encoded = otlpAttributes(attrs).single;
        expect(encoded.key, 'http.request.method');
        expect(encoded.hasValue(), isTrue);
        expect(encoded.value.whichValue(), proto.AnyValue_Value.notSet);
      }
    }

    checkHelpers();
    await OTel.initialize(
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
        enableLogs: false,
        enableMetrics: false);
    checkHelpers();
  });

  test('typed double and integer lists retain distinct OTLP element types', () {
    final attrs = OTel.attributesFromMap({
      'doubles': <double>[1.0, 2.5],
      'integers': <int>[1, 2],
    });
    final encoded = {
      for (final entry in otlpAttributes(attrs)) entry.key: entry.value
    };
    final doubles = encoded['doubles']!.arrayValue.values;
    expect(doubles.map((item) => item.whichValue()),
        everyElement(proto.AnyValue_Value.doubleValue));
    expect(doubles.map((item) => item.doubleValue), [1.0, 2.5]);
    final integers = encoded['integers']!.arrayValue.values;
    expect(integers.map((item) => item.whichValue()),
        everyElement(proto.AnyValue_Value.intValue));
    expect(integers.map((item) => item.intValue.toInt()), [1, 2]);
  });

  test('non-finite doubles keep their protobuf and JSON representation', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      final encoded = otlpAnyValue(AnyValueDouble(value));
      final decoded = proto.AnyValue.fromBuffer(encoded.writeToBuffer());
      expect(decoded.hasDoubleValue(), isTrue);
      expect(decoded.doubleValue, value.isNaN ? isNaN : value);
      expect(encoded.toProto3Json(), {
        'doubleValue':
            value.isNaN ? 'NaN' : (value > 0 ? 'Infinity' : '-Infinity'),
      });
    }
  });

  test('metric map methods collect nullable and structured attributes',
      () async {
    await OTel.reset();
    final reader = MemoryMetricReader();
    await OTel.initialize(
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(InMemorySpanExporter()),
        enableLogs: false,
        metricReader: reader);
    // Exercise the public API interface as well as the SDK implementation.
    final APIMeter meter = OTel.meter('maps');
    meter.createCounter<int>(name: 'counter').addWithMap(1, values());
    meter.createUpDownCounter<int>(name: 'updown').addWithMap(-1, values());
    meter.createGauge<double>(name: 'gauge').recordWithMap(1.5, values());
    meter
        .createHistogram<double>(name: 'histogram')
        .recordWithMap(2.5, values());
    final data = await reader.collect();
    expect(data.metrics, hasLength(4));
    for (final metric in data.metrics) {
      expectAttributes(otlpAttributes(metric.points.single.attributes));
    }
  });

  test('directly wrapped excessive nesting is bounded and reported once', () {
    final errors = <Object>[];
    OTelErrorHandling.handler = (error, _) => errors.add(error);
    addTearDown(OTelErrorHandling.resetToDefault);
    AnyValue value = const AnyValueString('too deep');
    for (var i = 0; i < 40; i++) {
      value = AnyValueArray([value]);
    }
    var encoded = otlpAnyValue(value);
    for (var i = 0; i < 32; i++) {
      expect(encoded.hasArrayValue(), isTrue);
      encoded = encoded.arrayValue.values.single;
    }
    expect(encoded.whichValue(), proto.AnyValue_Value.notSet);
    expect(errors, hasLength(1));
  });

  for (final kind in ['array', 'map']) {
    for (final wrappers in [30, 31, 32]) {
      test('$kind export depth $wrappers reports once per encoding', () {
        final errors = <Object>[];
        OTelErrorHandling.handler = (error, _) => errors.add(error);
        addTearDown(OTelErrorHandling.resetToDefault);
        var value = kind == 'array'
            ? AnyValueArray(List.filled(64, const AnyValueInt(1)))
            : AnyValueMap(
                {for (var i = 0; i < 64; i++) '$i': const AnyValueInt(1)});
        for (var i = 0; i < wrappers; i++) {
          value = AnyValueArray([value]);
        }

        for (var call = 1; call <= 2; call++) {
          var encoded = otlpAnyValue(value);
          expect(errors, hasLength(wrappers == 30 ? 0 : call));
          for (var i = 0; i < wrappers; i++) {
            encoded = encoded.arrayValue.values.single;
          }
          if (wrappers == 32) {
            expect(encoded.whichValue(), proto.AnyValue_Value.notSet);
          } else {
            final leaves = kind == 'array'
                ? encoded.arrayValue.values
                : encoded.kvlistValue.values.map((entry) => entry.value);
            expect(leaves, hasLength(64));
            expect(
                leaves.map((leaf) => leaf.whichValue()),
                everyElement(wrappers == 30
                    ? proto.AnyValue_Value.intValue
                    : proto.AnyValue_Value.notSet));
          }
        }
      });
    }
  }

  test('export depth failure propagates a strict handler exception once', () {
    final errors = <Object>[];
    final sentinel = StateError('strict handler');
    OTelErrorHandling.handler = (error, _) {
      errors.add(error);
      throw sentinel;
    };
    addTearDown(OTelErrorHandling.resetToDefault);
    AnyValue value = AnyValueArray(List.filled(64, const AnyValueInt(1)));
    for (var i = 0; i < 31; i++) {
      value = AnyValueArray([value]);
    }
    expect(() => otlpAnyValue(value), throwsA(same(sentinel)));
    expect(errors, hasLength(1));
  });

  test('Prometheus labels encode structured values instead of debug strings',
      () async {
    final exporter = PrometheusExporter();
    addTearDown(exporter.shutdown);
    expect(await exporter.export(makeMetrics()), isTrue);
    final text = exporter.prometheusData;
    expect(text, contains('bytes="AID/"'));
    expect(text, contains('null=""'));
    expect(text, contains('emptyMap="{}"'));
    expect(text, contains('emptyArray="[]"'));
    expect(text, contains('emptyBytes=""'));
    expect(text, contains('rating="needs-improvement"'));
    expect(text, contains('state="needs_cleaning"'));
    expect(
        text,
        contains(
            r'nested="[1,2.5,null,[true,\"text\"],{\"bytes\":\"Kg==\",\"null\":null}]"'));
    expect(text, isNot(contains('AttributeValue(')));
    expect(text, isNot(contains('<3 bytes>')));
  });

  for (final kind in ['array', 'map']) {
    test('Prometheus $kind depth truncation reports once per label conversion',
        () async {
      final errors = <Object>[];
      OTelErrorHandling.handler = (error, _) => errors.add(error);
      addTearDown(OTelErrorHandling.resetToDefault);
      final exporter = PrometheusExporter();
      addTearDown(exporter.shutdown);
      var value = kind == 'array'
          ? AnyValueArray(List.filled(1000, const AnyValueInt(1)))
          : AnyValueMap(
              {for (var i = 0; i < 1000; i++) '$i': const AnyValueInt(1)});
      for (var i = 0; i < 31; i++) {
        value = AnyValueArray([value]);
      }
      final now = DateTime.utc(2026);
      final data = MetricData(resource: resource, metrics: [
        Metric(name: 'depth', type: MetricType.gauge, points: [
          MetricPoint<int>(
              attributes: OTel.attributesFromMap({'deep': value}),
              startTime: now,
              endTime: now,
              value: 1),
        ]),
      ]);

      for (var call = 1; call <= 2; call++) {
        expect(await exporter.export(data), isTrue);
        expect(errors, hasLength(call));
        expect(errors.last.toString(), contains('maximum depth of 32'));
        // Decode the quoted label and its JSON collection to verify every
        // truncated leaf remains a null placeholder in the exported value.
        final label = RegExp(r'deep=("(?:\\.|[^"\\])*")')
            .firstMatch(exporter.prometheusData)!
            .group(1)!;
        Object? decoded = jsonDecode(jsonDecode(label) as String);
        for (var i = 0; i < 31; i++) {
          decoded = (decoded as List).single;
        }
        final leaves =
            kind == 'array' ? decoded as List : (decoded as Map).values;
        expect(leaves, hasLength(1000));
        expect(leaves, everyElement(isNull));
      }
    });
  }

  test('all gRPC exporters preserve the AnyValue hierarchy', () async {
    final traceService = _TraceService();
    final logService = _LogService();
    final metricService = _MetricService();
    final server =
        grpc.Server.create(services: [traceService, logService, metricService]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    addTearDown(server.shutdown);
    final endpoint = 'http://127.0.0.1:${server.port}';
    final spans = OtlpGrpcSpanExporter(
        OtlpGrpcExporterConfig(endpoint: endpoint, insecure: true));
    final logs = OtlpGrpcLogRecordExporter(
        OtlpGrpcLogRecordExporterConfig(endpoint: endpoint, insecure: true));
    final metrics = OtlpGrpcMetricExporter(
        OtlpGrpcMetricExporterConfig(endpoint: endpoint, insecure: true));
    addTearDown(spans.shutdown);
    addTearDown(logs.shutdown);
    addTearDown(metrics.shutdown);
    await spans.export([makeSpan()]);
    await logs.export([makeLog(body: values())]);
    expect(await metrics.export(makeMetrics()), isTrue);
    expectAttributes(traceService.request.resourceSpans.single.scopeSpans.single
        .spans.single.attributes);
    final log = logService
        .request.resourceLogs.single.scopeLogs.single.logRecords.single;
    expectAttributes(log.attributes);
    expectAttributes(log.body.kvlistValue.values);
    expectAttributes(
        metricService.request.resourceMetrics.single.resource.attributes);
    for (final metric in metricService
        .request.resourceMetrics.single.scopeMetrics.single.metrics) {
      expectAttributes(metric.hasHistogram()
          ? metric.histogram.dataPoints.single.attributes
          : metric.hasGauge()
              ? metric.gauge.dataPoints.single.attributes
              : metric.sum.dataPoints.single.attributes);
    }
  });

  for (final protocol in OtlpHttpProtocol.values) {
    test('all HTTP exporters preserve AnyValue over ${protocol.name}',
        () async {
      final captured = <String, List<int>>{};
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        captured[request.uri.path] = await request
            .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      });
      final endpoint = 'http://127.0.0.1:${server.port}';
      final spans = OtlpHttpSpanExporter(OtlpHttpExporterConfig(
          endpoint: endpoint, protocol: protocol, compression: false));
      final logs = OtlpHttpLogRecordExporter(OtlpHttpLogRecordExporterConfig(
          endpoint: endpoint, protocol: protocol, compression: false));
      final metrics = OtlpHttpMetricExporter(OtlpHttpMetricExporterConfig(
          endpoint: endpoint, protocol: protocol, compression: false));
      addTearDown(spans.shutdown);
      addTearDown(logs.shutdown);
      addTearDown(metrics.shutdown);
      await spans.export([makeSpan()]);
      await logs.export([makeLog(body: values())]);
      expect(await metrics.export(makeMetrics()), isTrue);
      expect(captured.keys,
          containsAll(['/v1/traces', '/v1/logs', '/v1/metrics']));
      if (protocol == OtlpHttpProtocol.httpProtobuf) {
        final trace =
            proto.ExportTraceServiceRequest.fromBuffer(captured['/v1/traces']!);
        expectAttributes(trace
            .resourceSpans.single.scopeSpans.single.spans.single.attributes);
        final log =
            proto.ExportLogsServiceRequest.fromBuffer(captured['/v1/logs']!)
                .resourceLogs
                .single
                .scopeLogs
                .single
                .logRecords
                .single;
        expectAttributes(log.attributes);
        expectAttributes(log.body.kvlistValue.values);
        final metric = proto.ExportMetricsServiceRequest.fromBuffer(
            captured['/v1/metrics']!);
        expectAttributes(metric.resourceMetrics.single.resource.attributes);
      } else {
        // Assert actual JSON wire values, including base64 bytes, decimal int64
        // strings and empty objects for null, rather than the API's debug JSON.
        for (final entry in captured.entries) {
          final json = jsonDecode(utf8.decode(entry.value)) as Map;
          final groups = json.values.single as List;
          final group = groups.single as Map;
          final scopeKey = switch (entry.key) {
            '/v1/traces' => 'scopeSpans',
            '/v1/logs' => 'scopeLogs',
            _ => 'scopeMetrics',
          };
          final scopeGroup = (group[scopeKey] as List).single as Map;
          final recordKey = switch (entry.key) {
            '/v1/traces' => 'spans',
            '/v1/logs' => 'logRecords',
            _ => 'metrics',
          };
          final record = (scopeGroup[recordKey] as List).first as Map;
          final List attrs;
          if (entry.key == '/v1/metrics') {
            attrs = (group['resource'] as Map)['attributes'] as List;
          } else {
            attrs = record['attributes'] as List;
          }
          final actual = {
            for (final a in attrs.cast<Map>()) a['key']: a['value']
          };
          expect(actual['bytes'], {'bytesValue': 'AID/'});
          expect(actual['rating'], {'stringValue': 'needs-improvement'});
          expect(actual['state'], {'stringValue': 'needs_cleaning'});
          expect(actual['large'], {'intValue': '9007199254740993'});
          expect(actual['null'], isEmpty);
          expect(actual['emptyBytes'], {'bytesValue': ''});
          expect(actual['string'], {'stringValue': ''});
          expect(actual['bool'], {'boolValue': false});
          expect(actual['int'], {'intValue': '0'});
          expect(actual['double'], {'doubleValue': 0});
          final nested = (actual['nested'] as Map)['arrayValue'] as Map;
          expect((nested['values'] as List)[2], isEmpty);
        }
      }
    });
  }
}

class _TraceService extends proto.TraceServiceBase {
  late proto.ExportTraceServiceRequest request;

  @override
  Future<proto.ExportTraceServiceResponse> export(
      grpc.ServiceCall call, proto.ExportTraceServiceRequest request) async {
    this.request = request;
    return proto.ExportTraceServiceResponse();
  }
}

class _LogService extends proto.LogsServiceBase {
  late proto.ExportLogsServiceRequest request;

  @override
  Future<proto.ExportLogsServiceResponse> export(
      grpc.ServiceCall call, proto.ExportLogsServiceRequest request) async {
    this.request = request;
    return proto.ExportLogsServiceResponse();
  }
}

class _MetricService extends proto.MetricsServiceBase {
  late proto.ExportMetricsServiceRequest request;

  @override
  Future<proto.ExportMetricsServiceResponse> export(
      grpc.ServiceCall call, proto.ExportMetricsServiceRequest request) async {
    this.request = request;
    return proto.ExportMetricsServiceResponse();
  }
}
