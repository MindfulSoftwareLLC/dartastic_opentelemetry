// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/src/util/zip/gzip.dart';
import 'package:test/test.dart';

void main() {
  group('GZip', () {
    late GZip gzip;

    setUp(() {
      gzip = GZip();
    });

    test('should compress and decompress simple string data', () async {
      // Arrange
      final originalData = 'Hello, OpenTelemetry!';
      final originalBytes = Uint8List.fromList(utf8.encode(originalData));

      // Act
      final compressed = await gzip.compress(originalBytes);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));
      final decompressedString = utf8.decode(decompressed);

      // Assert
      expect(decompressedString, equals(originalData));
      // Compressed data should have the gzip signature (starts with 0x1F, 0x8B)
      expect(compressed.length >= 2, isTrue);
      expect(compressed[0], equals(0x1F));
      expect(compressed[1], equals(0x8B));
    });

    test('should handle empty data', () async {
      // Arrange
      final emptyData = Uint8List(0);

      // Act
      final compressed = await gzip.compress(emptyData);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));

      // Assert
      expect(decompressed, isEmpty);
    });

    test('should handle small data', () async {
      // Arrange
      final smallData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Act
      final compressed = await gzip.compress(smallData);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));

      // Assert
      expect(Uint8List.fromList(decompressed), equals(smallData));
    });

    test('should handle large data', () async {
      // Arrange
      final largeData = Uint8List.fromList(List.generate(100000, (i) => i % 256));

      // Act
      final compressed = await gzip.compress(largeData);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));

      // Assert
      expect(Uint8List.fromList(decompressed), equals(largeData));
      // Large data should be compressed smaller
      expect(compressed.length, lessThan(largeData.length));
    });

    test('should handle data with repetition efficiently', () async {
      // Arrange
      final repeatedData = Uint8List.fromList(List.filled(10000, 65)); // 'A' repeated

      // Act
      final compressed = await gzip.compress(repeatedData);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));

      // Assert
      expect(Uint8List.fromList(decompressed), equals(repeatedData));
      // Highly repetitive data should compress very well
      expect(compressed.length, lessThan(repeatedData.length ~/ 50));
    });

    test('should handle binary data with all byte values', () async {
      // Arrange
      final binaryData = Uint8List.fromList(List.generate(256, (i) => i));

      // Act
      final compressed = await gzip.compress(binaryData);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));

      // Assert
      expect(Uint8List.fromList(decompressed), equals(binaryData));
    });

    test('should handle JSON data typical for telemetry', () async {
      // Arrange
      final jsonData = {
        'resource': {
          'service.name': 'test-service',
          'service.version': '1.0.0',
          'deployment.environment': 'test'
        },
        'spans': List.generate(100, (i) => {
          'name': 'span-$i',
          'trace_id': '0123456789abcdef0123456789abcdef',
          'span_id': '0123456789abcdef',
          'parent_span_id': '',
          'start_time': '2025-01-01T00:00:00Z',
          'end_time': '2025-01-01T00:00:01Z',
          'attributes': {
            'http.method': 'GET',
            'http.url': 'https://example.com/api/items/$i',
            'http.status_code': 200
          },
          'events': [
            {
              'name': 'exception',
              'time': '2025-01-01T00:00:00.500Z',
              'attributes': {
                'exception.type': 'NotFoundException',
                'exception.message': 'Resource not found'
              }
            }
          ]
        })
      };
      
      final jsonString = jsonEncode(jsonData);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

      // Act
      final compressed = await gzip.compress(jsonBytes);
      final decompressed = await gzip.decompress(Uint8List.fromList(compressed));
      final decompressedJson = utf8.decode(decompressed);

      // Assert
      expect(decompressedJson, equals(jsonString));
      
      // JSON with repetitive structure should compress well
      expect(compressed.length, lessThan(jsonBytes.length ~/ 5));
    });
  });
}
