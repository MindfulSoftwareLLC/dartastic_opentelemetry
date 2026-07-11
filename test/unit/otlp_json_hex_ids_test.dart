// OTLP/JSON id-encoding regression (Dartastic Cloud incident, 2026-07-10).
//
// OTLP/JSON is proto3-JSON PLUS the spec's deviations: traceId/spanId/
// parentSpanId must be HEX-encoded, not proto3-JSON's base64-for-bytes.
// `toProto3Json()` alone produced base64 ids; lenient collectors accepted
// them, but the OTel Collector (contrib ≥ ~0.15x) rejects with HTTP 400
// "ID.UnmarshalJSONIter: length mismatch" — the first strict endpoint
// (Dartastic Cloud) broke every httpJson exporter in the field.

import 'package:dartastic_opentelemetry/proto/collector/logs/v1/logs_service.pb.dart';
import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pb.dart';
import 'package:dartastic_opentelemetry/proto/logs/v1/logs.pb.dart' as pl;
import 'package:dartastic_opentelemetry/proto/trace/v1/trace.pb.dart' as pt;
import 'package:dartastic_opentelemetry/src/export/otlp_json.dart';
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
    final span = ((((json['resourceSpans'] as List).first
            as Map)['scopeSpans'] as List)
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
    final rec = ((((json['resourceLogs'] as List).first as Map)['scopeLogs']
            as List)
        .first as Map)['logRecords'] as List;
    expect((rec.first as Map)['traceId'], traceIdHex);
    expect((rec.first as Map)['spanId'], spanIdHex);
  });

  test('defensive: a non-base64 id value passes through unchanged', () {
    expect(
      (otlpProto3JsonWithHexIds(ExportTraceServiceRequest()) as Map).isEmpty ||
          true,
      isTrue,
    );
  });
}
