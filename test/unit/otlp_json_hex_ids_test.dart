// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// OTLP/JSON id-encoding regression (Dartastic Cloud incident, 2026-07-10).
//
// OTLP/JSON is proto3-JSON PLUS the spec's deviations: traceId/spanId/
// parentSpanId must be HEX-encoded, not proto3-JSON's base64-for-bytes.
// `toProto3Json()` alone produced base64 ids; lenient collectors accepted
// them, but the OTel Collector (contrib ≥ ~0.15x) rejects with HTTP 400
// "ID.UnmarshalJSONIter: length mismatch" — the first strict endpoint
// (Dartastic Cloud) broke every httpJson exporter in the field.

import 'package:dartastic_opentelemetry/proto/collector/logs/v1/logs_service.pb.dart';
import 'package:dartastic_opentelemetry/proto/collector/metrics/v1/metrics_service.pb.dart';
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pb.dart';
import 'package:dartastic_opentelemetry/proto/common/v1/common.pb.dart' as pc;
import 'package:dartastic_opentelemetry/proto/logs/v1/logs.pb.dart' as pl;
import 'package:dartastic_opentelemetry/proto/metrics/v1/metrics.pb.dart' as pm;
import 'package:dartastic_opentelemetry/proto/trace/v1/trace.pb.dart' as pt;
import 'package:dartastic_opentelemetry/src/export/otlp_json.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show IdGenerator;
import 'package:test/test.dart';

void main() {
  final traceId = List<int>.generate(16, (i) => i + 1); // 0102…10
  final spanId = List<int>.generate(8, (i) => 0xa0 + i); // a0a1…a7
  const traceIdHex = '0102030405060708090a0b0c0d0e0f10';
  const spanIdHex = 'a0a1a2a3a4a5a6a7';

  test('span + link ids are hex, never base64', () {
    final req = ExportTraceServiceRequest(resourceSpans: [
      pt.ResourceSpans(scopeSpans: [
        pt.ScopeSpans(spans: [
          pt.Span(
            traceId: traceId,
            spanId: spanId,
            parentSpanId: spanId,
            name: 'GET /forecast',
            links: [pt.Span_Link(traceId: traceId, spanId: spanId)],
          ),
        ]),
      ]),
    ]);

    final json = otlpProto3JsonWithHexIds(req) as Map<String, Object?>;
    final span =
        ((((json['resourceSpans'] as List).first as Map)['scopeSpans'] as List)
            .first as Map)['spans'] as List;
    final s = span.first as Map;
    expect(s['traceId'], traceIdHex);
    expect(s['spanId'], spanIdHex);
    expect(s['parentSpanId'], spanIdHex);
    final link = (s['links'] as List).first as Map;
    expect(link['traceId'], traceIdHex);
    expect(link['spanId'], spanIdHex);
    // Non-id fields untouched.
    expect(s['name'], 'GET /forecast');
  });

  test('log record ids are hex', () {
    final req = ExportLogsServiceRequest(resourceLogs: [
      pl.ResourceLogs(scopeLogs: [
        pl.ScopeLogs(logRecords: [
          pl.LogRecord(traceId: traceId, spanId: spanId),
        ]),
      ]),
    ]);
    final json = otlpProto3JsonWithHexIds(req) as Map<String, Object?>;
    final rec =
        ((((json['resourceLogs'] as List).first as Map)['scopeLogs'] as List)
            .first as Map)['logRecords'] as List;
    expect((rec.first as Map)['traceId'], traceIdHex);
    expect((rec.first as Map)['spanId'], spanIdHex);
  });

  test('metric exemplar ids are hex', () {
    final req = ExportMetricsServiceRequest(resourceMetrics: [
      pm.ResourceMetrics(scopeMetrics: [
        pm.ScopeMetrics(metrics: [
          pm.Metric(
            name: 'http.request.duration',
            gauge: pm.Gauge(dataPoints: [
              pm.NumberDataPoint(exemplars: [
                pm.Exemplar(traceId: traceId, spanId: spanId),
              ]),
            ]),
          ),
        ]),
      ]),
    ]);
    final json = otlpProto3JsonWithHexIds(req) as Map<String, Object?>;
    final metric = ((((json['resourceMetrics'] as List).first
            as Map)['scopeMetrics'] as List)
        .first as Map)['metrics'] as List;
    final exemplar =
        ((((metric.first as Map)['gauge'] as Map)['dataPoints'] as List).first
            as Map)['exemplars'] as List;
    expect((exemplar.first as Map)['traceId'], traceIdHex);
    expect((exemplar.first as Map)['spanId'], spanIdHex);
  });

  test('empty request stays empty; hex matches the shared id codec', () {
    expect(otlpProto3JsonWithHexIds(ExportTraceServiceRequest()), isEmpty);

    // The wire encoding must agree with TraceId.hexString/SpanId.hexString,
    // which delegate to IdGenerator.bytesToHex — one codec for the whole SDK.
    final genTrace = IdGenerator.generateTraceId();
    final genSpan = IdGenerator.generateSpanId();
    final req = ExportTraceServiceRequest(resourceSpans: [
      pt.ResourceSpans(scopeSpans: [
        pt.ScopeSpans(spans: [
          pt.Span(traceId: genTrace, spanId: genSpan, name: 'x'),
        ]),
      ]),
    ]);
    final json = otlpProto3JsonWithHexIds(req) as Map<String, Object?>;
    final s =
        (((((json['resourceSpans'] as List).first as Map)['scopeSpans'] as List)
                .first as Map)['spans'] as List)
            .first as Map;
    expect(s['traceId'], IdGenerator.bytesToHex(genTrace));
    expect(s['spanId'], IdGenerator.bytesToHex(genSpan));
  });

  test('enum fields are integers, never proto3-JSON names', () {
    final req = ExportTraceServiceRequest(resourceSpans: [
      pt.ResourceSpans(scopeSpans: [
        pt.ScopeSpans(spans: [
          pt.Span(
            traceId: traceId,
            spanId: spanId,
            name: 'GET /forecast',
            kind: pt.Span_SpanKind.SPAN_KIND_SERVER,
            status: pt.Status(
              code: pt.Status_StatusCode.STATUS_CODE_ERROR,
              message: 'boom',
            ),
          ),
        ]),
      ]),
    ]);

    final json = otlpProto3JsonWithHexIds(req) as Map<String, Object?>;
    final s =
        (((((json['resourceSpans'] as List).first as Map)['scopeSpans'] as List)
                .first as Map)['spans'] as List)
            .first as Map;
    expect(s['kind'], 2, reason: 'OTLP/JSON requires integer enum values');
    expect((s['status'] as Map)['code'], 2);
  });

  test('log severityNumber and metric aggregationTemporality are integers', () {
    final logs = ExportLogsServiceRequest(resourceLogs: [
      pl.ResourceLogs(scopeLogs: [
        pl.ScopeLogs(logRecords: [
          pl.LogRecord(
            severityNumber: pl.SeverityNumber.SEVERITY_NUMBER_ERROR,
            traceId: traceId,
            spanId: spanId,
          ),
        ]),
      ]),
    ]);
    final lj = otlpProto3JsonWithHexIds(logs) as Map<String, Object?>;
    final lr =
        (((((lj['resourceLogs'] as List).first as Map)['scopeLogs'] as List)
                .first as Map)['logRecords'] as List)
            .first as Map;
    expect(lr['severityNumber'], 17);

    final metrics = ExportMetricsServiceRequest(resourceMetrics: [
      pm.ResourceMetrics(scopeMetrics: [
        pm.ScopeMetrics(metrics: [
          pm.Metric(
            name: 'm',
            sum: pm.Sum(
              dataPoints: [pm.NumberDataPoint(asDouble: 1.0)],
              aggregationTemporality:
                  pm.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA,
              isMonotonic: true,
            ),
          ),
        ]),
      ]),
    ]);
    final mj = otlpProto3JsonWithHexIds(metrics) as Map<String, Object?>;
    final metric = (((((mj['resourceMetrics'] as List).first
                as Map)['scopeMetrics'] as List)
            .first as Map)['metrics'] as List)
        .first as Map;
    expect((metric['sum'] as Map)['aggregationTemporality'], 1);
  });

  test('attribute string values resembling enum names are never touched', () {
    final req = ExportTraceServiceRequest(resourceSpans: [
      pt.ResourceSpans(scopeSpans: [
        pt.ScopeSpans(spans: [
          pt.Span(
            traceId: traceId,
            spanId: spanId,
            name: 'attr-collision',
          )..attributes.add(
              pc.KeyValue(
                key: 'suspicious',
                value: pc.AnyValue(stringValue: 'SPAN_KIND_SERVER'),
              ),
            ),
        ]),
      ]),
    ]);
    final json = otlpProto3JsonWithHexIds(req) as Map<String, Object?>;
    final s =
        (((((json['resourceSpans'] as List).first as Map)['scopeSpans'] as List)
                .first as Map)['spans'] as List)
            .first as Map;
    final attr = (s['attributes'] as List).first as Map;
    expect((attr['value'] as Map)['stringValue'], 'SPAN_KIND_SERVER',
        reason: 'field-keyed conversion must never rewrite attribute values');
  });
}
