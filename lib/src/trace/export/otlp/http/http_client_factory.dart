// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Conditional facade for the platform-specific HTTP client factory used
// by the OTLP/HTTP exporters. Native targets get an `IOClient`; web
// targets get a `BrowserClient`.

export 'http_client_factory_io.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart';
