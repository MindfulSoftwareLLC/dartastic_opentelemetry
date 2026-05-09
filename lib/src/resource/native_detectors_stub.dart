// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Stub implementations of the native resource detectors for web /
// any platform without `dart:io`. The classes still implement
// [ResourceDetector] so consumers can hold references, but `detect()`
// throws `UnsupportedError` if anyone actually calls it.
//
// In practice, `PlatformResourceDetector.create()` only adds these to
// the composite on non-web targets, so `detect()` should never be
// reached on web.

import 'resource.dart';
import 'resource_detector.dart';

/// Stub implementation of [ProcessResourceDetector] for non-`dart:io`
/// platforms. Throws if `detect()` is called.
class ProcessResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw UnsupportedError(
      'ProcessResourceDetector requires dart:io and is not available on '
      'this platform (e.g. web). Use PlatformResourceDetector.create() '
      'which selects the appropriate detectors per platform.',
    );
  }
}

/// Stub implementation of [HostResourceDetector] for non-`dart:io`
/// platforms. Throws if `detect()` is called.
class HostResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    throw UnsupportedError(
      'HostResourceDetector requires dart:io and is not available on '
      'this platform (e.g. web). Use PlatformResourceDetector.create() '
      'which selects the appropriate detectors per platform.',
    );
  }
}
