// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Web implementation of the HTTP client factory used by the OTLP/HTTP
// exporters. Browsers handle TLS themselves — there is no equivalent
// of `SecurityContext` to construct from custom CA / client cert / key
// bytes. If the caller passes any of those, we log a warning and fall
// back to the default `BrowserClient`. The browser will still verify
// the server cert against its own trust store; mTLS is unsupported
// on this code path.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Builds an [http.Client] for the OTLP/HTTP exporters on web.
///
/// Returns a [BrowserClient]. If the caller specified any custom
/// certificate paths, logs a warning — those settings are not
/// honoured on web because the browser owns the TLS handshake.
http.Client createOtlpHttpClient({
  required String exporterName,
  String? certificate,
  String? clientKey,
  String? clientCertificate,
}) {
  if ((certificate != null || clientKey != null || clientCertificate != null) &&
      OTelLog.isError()) {
    OTelLog.error(
      '$exporterName: certificate / clientKey / clientCertificate '
      'configuration is ignored on web — the browser handles TLS. '
      'Use the IO build for custom CA roots or mTLS.',
    );
  }
  return BrowserClient();
}
