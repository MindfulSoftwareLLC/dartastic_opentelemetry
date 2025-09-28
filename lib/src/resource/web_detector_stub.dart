// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// This is a stub implementation for non-web platforms
// It doesn't import dart:js_interop
import 'resource.dart';
import 'resource_detector.dart';

/// Stub implementation of the WebResourceDetector for non-web platforms.
///
/// This implementation is a placeholder that throws an error if used,
/// ensuring that the web-specific detector is only used in web environments.
///
/// This is part of Dart's conditional import/export pattern for
/// platform-specific code.
class WebResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw UnsupportedError(
        'WebResourceDetector is only available on web platforms');
  }
}
