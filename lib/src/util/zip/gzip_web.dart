// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

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
        .pipeThrough(
          ReadableWritablePair(
            readable: compressionStream.readable,
            writable: compressionStream.writable,
          ),
        )
        .getReader() as ReadableStreamDefaultReader;
    return await _readUntilDone(reader);
  }

  /// Decode the gzip-compressed [data].
  Future<List<int>> decompress(Uint8List data) async {
    final decompressionStream = DecompressionStream('gzip');
    final reader = _blob(data)
        .stream()
        .pipeThrough(
          ReadableWritablePair(
            readable: decompressionStream.readable,
            writable: decompressionStream.writable,
          ),
        )
        .getReader() as ReadableStreamDefaultReader;
    return await _readUntilDone(reader);
  }

  Future<List<int>> _readUntilDone(ReadableStreamDefaultReader reader) async {
    final values = <int>[];
    var isDone = false;
    while (!isDone) {
      final readChunk = await reader.read().toDart;
      final value = readChunk.value;
      if (value != null) {
        // ReadableStream yields a JS Uint8Array. On dart2js the cast
        // `as Uint8List` works because JS values and Dart values share
        // a representation, but on dart2wasm we must explicitly convert
        // via the `toDart` extension on `JSUint8Array`. Going through
        // the JS interop type works on both compilers.
        final bytes = (value as JSUint8Array).toDart;
        values.addAll(bytes);
      }
      isDone = readChunk.done;
    }
    return values;
  }

  Blob _blob(Uint8List data) =>
      Blob([data.toJS].toJS, BlobPropertyBag(type: 'application/octet-stream'));
}
