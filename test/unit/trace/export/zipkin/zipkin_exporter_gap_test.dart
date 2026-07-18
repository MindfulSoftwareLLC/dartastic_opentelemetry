// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:test/test.dart';

// Spec-compliance gap for sdk-environment-variables.md, "Exporter
// Selection" and trace/sdk_exporters/zipkin.md:
//
// - "Known values for OTEL_TRACES_EXPORTER are: ... 'zipkin': Zipkin"
// - zipkin.md fully specifies the span mapping (hex ids, kind table,
//   microsecond timestamps, localEndpoint.serviceName, events ->
//   annotations, attributes -> string tags, otel.status_code/error tags,
//   remoteEndpoint precedence).
//
// The OTEL_EXPORTER_ZIPKIN_ENDPOINT / OTEL_EXPORTER_ZIPKIN_TIMEOUT
// constants exist (env_constants.dart) but nothing consumes them, and
// OTEL_TRACES_EXPORTER=zipkin is warned-and-ignored.
void main() {
  test('the SDK provides a Zipkin span exporter',
      skip: 'Not implemented — see #80 (up for grabs, targeted '
          '1.1.0-beta.11)', () {
    fail('No ZipkinSpanExporter or ZipkinSpanTransformer exists; '
        'OTEL_TRACES_EXPORTER=zipkin is ignored with a warning and the '
        'OTEL_EXPORTER_ZIPKIN_* env vars are unconsumed.');
  });
}
