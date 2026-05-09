// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Conditional facade for the native (`dart:io`-using) resource detectors.
// On native platforms this exports the real implementations; on web it
// exports stubs so the rest of the SDK can be compiled without pulling
// in `dart:io`.

export 'native_detectors_stub.dart'
    if (dart.library.io) 'native_detectors_io.dart';
