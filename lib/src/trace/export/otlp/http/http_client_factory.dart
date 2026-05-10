// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Conditional facade for the platform-specific HTTP client factory used
// by the OTLP/HTTP exporters. Native targets get an `IOClient`; web
// targets get a `BrowserClient`.

export 'http_client_factory_io.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart';
