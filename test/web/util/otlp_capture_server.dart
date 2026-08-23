// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Hybrid-isolate OTLP/HTTP capture server for browser tests.
//
// `spawnHybridUri` runs this on the Dart VM while the test itself runs in
// the browser, so the test gets a real localhost collector endpoint that
// dart:io can bind. Replies to CORS preflights (the browser's OTLP POST is
// cross-origin from the test page), decodes each ExportTraceServiceRequest,
// and streams the exported resource attributes back over the channel.

import 'dart:io';

import 'package:dartastic_opentelemetry/proto/collector/trace/v1/trace_service.pb.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel<Object?> channel) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  channel.sink.add(server.port);

  server.listen((request) async {
    final response = request.response;
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      response.statusCode = 204;
      await response.close();
      return;
    }

    final bytes =
        await request.fold<List<int>>([], (b, chunk) => b..addAll(chunk));
    final export = ExportTraceServiceRequest.fromBuffer(bytes);
    // Decode both shapes. Reading only `stringValue` silently rendered every
    // array attribute as '' — which made an array-valued attribute look
    // absent rather than wrong, so `browser.languages` could not be asserted
    // as an array at all.
    final resourceAttributes = <String, Object>{
      for (final rs in export.resourceSpans)
        for (final kv in rs.resource.attributes)
          kv.key: kv.value.hasArrayValue()
              ? [for (final v in kv.value.arrayValue.values) v.stringValue]
              : kv.value.hasBoolValue()
                  ? kv.value.boolValue
                  : kv.value.stringValue,
    };

    response.statusCode = 200;
    response.add(ExportTraceServiceResponse().writeToBuffer());
    await response.close();

    channel.sink.add(resourceAttributes);
  });
}
