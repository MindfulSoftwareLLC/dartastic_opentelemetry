// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/src/util/zip/gzip_web.dart';
import 'package:test/test.dart';

void main() {
  group('GZip Web Tests', () {
    late GZip gzip;

    setUp(() {
      gzip = GZip();
    });

    test('compresses and decompresses simple string correctly', () async {
      final originalData = 'Hello, OpenTelemetry!';
      final uint8Data = Uint8List.fromList(utf8.encode(originalData));

      // Compress the data
      final compressed = await gzip.compress(uint8Data);

      // Ensure compression actually reduced the size (or at least changed it)
      expect(compressed.length, isNot(equals(uint8Data.length)));

      // Decompress the data
      final decompressed =
          await gzip.decompress(Uint8List.fromList(compressed));

      // Convert back to string and verify
      final resultString = utf8.decode(decompressed);
      expect(resultString, equals(originalData));
    });

    test('compresses and decompresses empty data', () async {
      final emptyData = Uint8List(0);

      // Compress empty data
      final compressed = await gzip.compress(emptyData);

      // Decompress the data
      final decompressed =
          await gzip.decompress(Uint8List.fromList(compressed));

      expect(decompressed, isEmpty);
    });

    test('compresses and decompresses large binary data', () async {
      // Create a large binary payload with a pattern
      final largeData = Uint8List(10000);
      for (var i = 0; i < largeData.length; i++) {
        largeData[i] = (i % 256);
      }

      // Compress the data
      final compressed = await gzip.compress(largeData);

      // Verify compression actually happened
      expect(compressed.length, lessThan(largeData.length));

      // Decompress the data
      final decompressed =
          await gzip.decompress(Uint8List.fromList(compressed));

      // Verify that decompressed data matches the original
      expect(decompressed.length, equals(largeData.length));
      // Compare the contents
      for (var i = 0; i < largeData.length; i++) {
        expect(decompressed[i], equals(largeData[i]),
            reason: 'Byte at position $i doesn\'t match');
      }
    });

    test('decompresses pre-compressed data correctly', () async {
      // This is a gzip-compressed version of "OpenTelemetry test data"
      final preCompressed = base64Decode(
          'H4sIAAAAAAAAA/NIzcnJVyjPL8pJUUjMS1FIKC1OLcpLzE1VyE3MzlQAAAbXZLQcAAAA');

      // Decompress the data
      final decompressed =
          await gzip.decompress(Uint8List.fromList(preCompressed));

      // Verify the decompressed content
      final resultString = utf8.decode(decompressed);
      expect(resultString, equals('OpenTelemetry test data'));
    });
  });
}
