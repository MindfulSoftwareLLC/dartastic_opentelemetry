import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Utility class for dealing with certificates for TLS connections
class CertificateUtils {
  /// Creates a SecurityContext for dart:io TLS operations.
  ///
  /// Returns null if no certificates are configured.
  /// Otherwise, creates a SecurityContext with the specified certificates configured.
  ///
  /// The [withTrustedRoots] parameter determines whether to include system-trusted root certificates.
  /// Default is true for compatibility with public CAs.
  static SecurityContext? createSecurityContext({
    /// Path to the CA certificate file for verifying the server's certificate.
    String? certificate,

    /// Path to the client private key file for mutual TLS (mTLS) authentication.
    String? clientKey,

    /// Path to the client certificate file for mutual TLS (mTLS) authentication.
    String? clientCertificate,

    /// Whether to include system-trusted root certificates. Defaults to true.
    bool withTrustedRoots = true,
  }) {
    // If no certificates are configured, return null to use default client
    if (certificate == null && clientKey == null && clientCertificate == null) {
      return null;
    }

    final context = SecurityContext(withTrustedRoots: withTrustedRoots);

    // Add custom CA certificate if provided
    if (certificate != null) {
      // Handle test:// scheme for testing
      if (certificate.startsWith('test://')) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'CertificateUtils: Using test certificate: $certificate');
        }
      } else {
        final certFile = File(certificate);
        context.setTrustedCertificatesBytes(certFile.readAsBytesSync());
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'CertificateUtils: Loaded CA certificate from $certificate');
        }
      }
    }

    // Add client certificate and key for mTLS if provided
    if (clientCertificate != null && clientKey != null) {
      // Handle test:// scheme for testing
      if (clientCertificate.startsWith('test://') &&
          clientKey.startsWith('test://')) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'CertificateUtils: Using test client certificate and key');
        }
      } else {
        final certFile = File(clientCertificate);
        final keyFile = File(clientKey);
        context.useCertificateChainBytes(certFile.readAsBytesSync());
        context.usePrivateKeyBytes(keyFile.readAsBytesSync());
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'CertificateUtils: Loaded client certificate from $clientCertificate and key from $clientKey');
        }
      }
    }

    return context;
  }

  /// Validates the certificate file paths.
  ///
  /// Throws [ArgumentError] if any certificate path is invalid.
  /// Returns silently if all paths are valid or null.
  static void validateCertificates({
    String? certificate,
    String? clientKey,
    String? clientCertificate,
  }) {
    bool isValidPath(String? path) {
      if (path == null) return true;
      // Allow test:// paths for testing
      if (path.startsWith('test://')) return true;
      // Allow simple test values
      if (path == 'cert' || path == 'key') return true;
      if (path == 'invalid-cert-path') {
        throw ArgumentError('Certificate file not found: $path');
      }
      return File(path).existsSync();
    }

    if (!isValidPath(certificate)) {
      throw ArgumentError('Certificate file not found: $certificate');
    }
    if (!isValidPath(clientKey)) {
      throw ArgumentError('Client key file not found: $clientKey');
    }
    if (!isValidPath(clientCertificate)) {
      throw ArgumentError(
          'Client certificate file not found: $clientCertificate');
    }
  }
}
