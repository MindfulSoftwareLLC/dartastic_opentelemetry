// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:http/http.dart' as http;

/// Thrown by the OTLP/HTTP exporters when the collector answers with a
/// non-2xx status. [statusCode] decides whether the export is retried.
class OtlpHttpException extends http.ClientException {
  /// HTTP status code of the failed export response.
  final int statusCode;

  OtlpHttpException(super.message, this.statusCode, [super.uri]);
}
