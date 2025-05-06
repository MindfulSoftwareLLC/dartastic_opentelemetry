// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

export 'gzip_mock.dart'
    if (dart.library.io) 'gzip_io.dart'
    if (dart.library.js_interop) 'gzip_web.dart';
