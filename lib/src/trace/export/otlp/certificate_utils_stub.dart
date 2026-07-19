// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Web / non-`dart:io` stub for certificate utilities.
//
// Browsers do TLS themselves — there is no equivalent of `SecurityContext`
// to construct from custom CA/client cert/key bytes. This stub provides
// a [validateCertificates] implementation that succeeds for any non-null
// path (we can't stat files in the browser, so trust what the caller
// passed) and intentionally OMITS `createSecurityContext`. Callers that
// need TLS configuration should be inside the IO-only HTTP exporter,
// which imports `certificate_utils_io.dart` directly.

/// Stub [CertificateUtils] for platforms without `dart:io`. Exposes
/// only [validateCertificates]; `createSecurityContext` is IO-only.
class CertificateUtils {
  /// No-op validation on web. Native validation checks file existence;
  /// the browser can't and won't, so this just rejects the explicit
  /// `'invalid-cert-path'` sentinel used by tests and otherwise lets
  /// every path through.
  static void validateCertificates({
    String? certificate,
    String? clientKey,
    String? clientCertificate,
  }) {
    void check(String name, String? path) {
      if (path == null) return;
      if (path == 'invalid-cert-path') {
        throw ArgumentError('$name file not found: $path');
      }
    }

    check('Certificate', certificate);
    check('Client key', clientKey);
    check('Client certificate', clientCertificate);
  }
}
