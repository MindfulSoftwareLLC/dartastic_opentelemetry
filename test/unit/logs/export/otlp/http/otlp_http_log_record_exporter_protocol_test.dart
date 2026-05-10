// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Tests the `protocol` config on `OtlpHttpLogRecordExporter` — the
// http/protobuf default keeps existing behaviour; opting into
// `OtlpHttpProtocol.httpJson` switches the Content-Type to
// `application/json` and the body to proto3-JSON.

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('OtlpHttpLogRecordExporter protocol', () {
    late HttpServer server;
    late int port;
    late List<HttpRequest> receivedRequests;
    var capturedBody = <int>[];

    setUp(() async {
      await OTel.reset();
      receivedRequests = [];
      capturedBody = [];
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
      server.listen((request) async {
        receivedRequests.add(request);
        capturedBody = await request
            .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
        request.response.statusCode = 200;
        await request.response.close();
      });
      await OTel.initialize(
        serviceName: 'test',
        detectPlatformResources: false,
      );
    });

    tearDown(() async {
      await server.close(force: true);
      await OTel.shutdown();
      await OTel.reset();
    });

    ReadableLogRecord createTestLogRecord() {
      final scope =
          OTel.instrumentationScope(name: 'protocol-test', version: '1.0.0');
      return SDKLogRecord(
        instrumentationScope: scope,
        severityNumber: Severity.INFO,
        body: 'hello-otlp-json',
      );
    }

    test('default (http/protobuf) sends application/x-protobuf', () async {
      final exporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(endpoint: 'http://localhost:$port'),
      );

      await exporter.export([createTestLogRecord()]);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.contentType.toString(),
        contains('application/x-protobuf'),
      );
      await exporter.shutdown();
    });

    test('httpJson protocol sends application/json + proto3-JSON body',
        () async {
      final exporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(
          endpoint: 'http://localhost:$port',
          protocol: OtlpHttpProtocol.httpJson,
        ),
      );

      await exporter.export([createTestLogRecord()]);

      expect(receivedRequests, hasLength(1));
      expect(
        receivedRequests.first.headers.contentType.toString(),
        contains('application/json'),
      );

      // Body must decode to a Map with the proto3-JSON top-level
      // `resourceLogs` key.
      final decoded = jsonDecode(utf8.decode(capturedBody));
      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map).containsKey('resourceLogs'), isTrue);
      expect(decoded['resourceLogs'], isA<List>());

      await exporter.shutdown();
    });
  });
}
