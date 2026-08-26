// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:io' as io;

/// Returns the base name of the current process executable.
String get processExecutableName {
  final path = io.Platform.executable;
  // Extract just the file name from the full path.
  final lastSlash = path.lastIndexOf(io.Platform.pathSeparator);
  return lastSlash == -1 ? path : path.substring(lastSlash + 1);
}
