// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

/// The [GZip] encodes raw bytes to GZip compressed bytes and decodes GZip
/// compressed bytes to raw bytes.
///
/// This is the web implementation using the browser's Compression API.
class GZip {
  /// Compress the [data] using gzip compression.
  Future<List<int>> compress(Uint8List data) async {
    final compressionStream = CompressionStream('gzip');
    final reader = _blob(data)
        .stream()
        .pipeThrough(ReadableWritablePair(
          readable: compressionStream.readable,
          writable: compressionStream.writable,
        ))
        .getReader() as ReadableStreamDefaultReader;
    return await _readUntilDone(reader);
  }

  /// Decode the gzip-compressed [data].
  Future<List<int>> decompress(Uint8List data) async {
    final decompressionStream = DecompressionStream('gzip');
    final reader = _blob(data)
        .stream()
        .pipeThrough(ReadableWritablePair(
          readable: decompressionStream.readable,
          writable: decompressionStream.writable,
        ))
        .getReader() as ReadableStreamDefaultReader;
    return await _readUntilDone(reader);
  }

  Future<List<int>> _readUntilDone(ReadableStreamDefaultReader reader) async {
    final values = <int>[];
    var isDone = false;
    while (!isDone) {
      final readChunk = await reader.read().toDart;
      if (readChunk.value != null) {
        // Explicitly ignore the type safety warning since we know this works
        // at runtime in the browser environment
        // ignore: invalid_runtime_check_with_js_interop_types
        final bytes = readChunk.value as Uint8List;
        values.addAll(bytes);
      }
      isDone = readChunk.done;
    }
    return values;
  }

  Blob _blob(Uint8List data) => Blob(
        [data.toJS].toJS,
        BlobPropertyBag(type: 'application/octet-stream'),
      );
}
