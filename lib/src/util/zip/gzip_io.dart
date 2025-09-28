// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';
import 'dart:typed_data';

/// The [GZip] encodes raw bytes to GZip compressed bytes and decodes GZip
/// compressed bytes to raw bytes.
///
/// It is implemented using `dart:io` on native platforms and platform-specific
/// implementations in browsers.
class GZip {
  /// Compress the [data] using gzip compression.
  Future<List<int>> compress(Uint8List data) async =>
      gzip.encoder.convert(data);

  /// Decode the gzip-compressed [data].
  Future<List<int>> decompress(Uint8List data) async =>
      gzip.decoder.convert(data);
}
