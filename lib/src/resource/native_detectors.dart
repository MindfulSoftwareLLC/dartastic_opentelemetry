// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Conditional facade for the native (`dart:io`-using) resource detectors.
// On native platforms this exports the real implementations; on web it
// exports stubs so the rest of the SDK can be compiled without pulling
// in `dart:io`.

export 'native_detectors_stub.dart'
    if (dart.library.io) 'native_detectors_io.dart';
