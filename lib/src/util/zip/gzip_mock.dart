// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:typed_data';

/// The [GZip] encodes raw bytes to GZip compressed bytes and decodes GZip
/// compressed bytes to raw bytes.
///
/// This is a mock implementation that throws UnimplementedError.
class GZip {
  /// Compress the [data] using gzip compression.
  Future<List<int>> compress(Uint8List data) async =>
      throw UnimplementedError('GZip.compress is not implemented on this platform');

  /// Decode the gzip-compressed [data].
  Future<List<int>> decompress(Uint8List data) async =>
      throw UnimplementedError('GZip.decompress is not implemented on this platform');
}
