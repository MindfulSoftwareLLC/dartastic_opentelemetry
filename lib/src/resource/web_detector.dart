// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// This is a conditional export file that uses dart:io check
// to determine which implementation to use

// Using the newer conditional export pattern with .dart extension
export 'web_detector_impl.dart' if (dart.library.io) 'web_detector_stub.dart';
