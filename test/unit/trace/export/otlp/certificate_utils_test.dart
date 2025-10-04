// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/src/trace/export/otlp/certificate_utils.dart';
import 'package:test/test.dart';

/// Unit tests for CertificateUtils
void main() {
  group('CertificateUtils.createSecurityContext', () {
    test('returns null when no certificates are provided', () {
      final context = CertificateUtils.createSecurityContext();

      expect(context, isNull);
    });

    test('returns null when all certificate parameters are null', () {
      final context = CertificateUtils.createSecurityContext(
        certificate: null,
        clientKey: null,
        clientCertificate: null,
      );

      expect(context, isNull);
    });

    test('creates SecurityContext with test:// CA certificate', () {
      final context = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
      );

      expect(context, isNotNull);
      expect(context, isA<SecurityContext>());
    });

    test('creates SecurityContext with test:// client certificates', () {
      final context = CertificateUtils.createSecurityContext(
        clientKey: 'test://client.key',
        clientCertificate: 'test://client.pem',
      );

      expect(context, isNotNull);
      expect(context, isA<SecurityContext>());
    });

    test('creates SecurityContext with all test:// certificates', () {
      final context = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
        clientKey: 'test://client.key',
        clientCertificate: 'test://client.pem',
      );

      expect(context, isNotNull);
      expect(context, isA<SecurityContext>());
    });

    test('respects withTrustedRoots parameter', () {
      final contextWithRoots = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
        withTrustedRoots: true,
      );

      final contextWithoutRoots = CertificateUtils.createSecurityContext(
        certificate: 'test://ca.pem',
        withTrustedRoots: false,
      );

      expect(contextWithRoots, isNotNull);
      expect(contextWithoutRoots, isNotNull);
      // Note: We can't directly test the internal state, but we verify both succeed
    });

    test('throws when CA certificate file does not exist', () {
      expect(
        () => CertificateUtils.createSecurityContext(
          certificate: '/nonexistent/ca.pem',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws when client key file does not exist', () {
      expect(
        () => CertificateUtils.createSecurityContext(
          clientKey: '/nonexistent/client.key',
          clientCertificate: 'test://client.pem',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws when client certificate file does not exist', () {
      expect(
        () => CertificateUtils.createSecurityContext(
          clientKey: 'test://client.key',
          clientCertificate: '/nonexistent/client.pem',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('CertificateUtils.validateCertificates', () {
    test('succeeds when all parameters are null', () {
      expect(
        CertificateUtils.validateCertificates,
        returnsNormally,
      );
    });

    test('succeeds with test:// paths', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: 'test://ca.pem',
          clientKey: 'test://client.key',
          clientCertificate: 'test://client.pem',
        ),
        returnsNormally,
      );
    });

    test('succeeds with special test values', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: 'cert',
          clientKey: 'key',
        ),
        returnsNormally,
      );
    });

    test('succeeds with existing files', () {
      final tempDir = Directory.systemTemp.createTempSync('cert_test_');
      final certFile = File('${tempDir.path}/ca.pem');
      certFile.writeAsStringSync('test cert');

      try {
        expect(
          () => CertificateUtils.validateCertificates(
            certificate: certFile.path,
          ),
          returnsNormally,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('throws ArgumentError for invalid-cert-path', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: 'invalid-cert-path',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Certificate file not found'),
          ),
        ),
      );
    });

    test('throws ArgumentError when certificate file does not exist', () {
      expect(
        () => CertificateUtils.validateCertificates(
          certificate: '/nonexistent/path/ca.pem',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Certificate file not found'),
          ),
        ),
      );
    });

    test('throws ArgumentError when client key file does not exist', () {
      expect(
        () => CertificateUtils.validateCertificates(
          clientKey: '/nonexistent/path/client.key',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Client key file not found'),
          ),
        ),
      );
    });

    test('throws ArgumentError when client certificate file does not exist',
        () {
      expect(
        () => CertificateUtils.validateCertificates(
          clientCertificate: '/nonexistent/path/client.pem',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Client certificate file not found'),
          ),
        ),
      );
    });
  });
}
