// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Conditional facade for [CertificateUtils]. On native targets exports
// the IO implementation (with `createSecurityContext`); on web exports
// a stub with only [validateCertificates].

export 'certificate_utils_stub.dart'
    if (dart.library.io) 'certificate_utils_io.dart';
