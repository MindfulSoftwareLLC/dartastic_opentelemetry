// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// This is a stub implementation for non-web platforms
// It doesn't import dart:js_interop
import 'resource.dart';
import 'resource_detector.dart';

// Stub implementation that will never actually be used on non-web platforms
class WebResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw UnsupportedError('WebResourceDetector is only available on web platforms');
  }
}
