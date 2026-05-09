// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// Conditional facade for [CertificateUtils]. On native targets exports
// the IO implementation (with `createSecurityContext`); on web exports
// a stub with only [validateCertificates].

export 'certificate_utils_stub.dart'
    if (dart.library.io) 'certificate_utils_io.dart';
