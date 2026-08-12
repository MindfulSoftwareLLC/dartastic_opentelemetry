// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Redaction of header values written to the debug log.
///
/// Which OTLP header holds a credential depends on the backend
/// (`authorization`, `x-api-key`, `x-honeycomb-team`, `dd-api-key`), so a list
/// of names to hide leaks anything not on it. This is the other way round: an
/// allowlist of names whose values are safe to print, everything else redacted.
///
/// Only values are opted in. Header names and the header count are always
/// logged, so the default empty allowlist still shows which headers are
/// configured.
library;

/// Written in place of a header value that is not allowed to be logged.
///
/// Without the value length, which would narrow the search space for the token.
const String redactedHeaderPlaceholder = '[REDACTED]';

/// Header names whose values are never logged, whatever the allowlist says.
const Set<String> alwaysRedactedHeaderNames = <String>{
  'authorization',
  'proxy-authorization',
};

Set<String> _allowedHeaderNames = const <String>{};

/// The header names whose values are currently allowed to be logged.
///
/// Lowercased, and never contains a name in [alwaysRedactedHeaderNames].
Set<String> get allowedHeaderLogNames => _allowedHeaderNames;

/// Sets the header names whose values may be logged, replacing any previous
/// allowlist rather than adding to it.
///
/// Names are lowercased here so [redactHeaderValue] only has to lowercase its
/// argument. Null or empty restores the default of redacting every value.
void configureHeaderLogAllowlist(Iterable<String>? headerNames) {
  if (headerNames == null) {
    _allowedHeaderNames = const <String>{};
    return;
  }
  _allowedHeaderNames = <String>{
    for (final name in headerNames)
      if (name.trim().isNotEmpty) name.trim().toLowerCase(),
  }..removeAll(alwaysRedactedHeaderNames);
}

/// Parses the comma separated form used by the environment variable.
///
/// Entries are trimmed, empty ones are dropped, and the result is a set, so
/// `" x-trace-id , ,X-Trace-Id "` gives `{'x-trace-id'}`.
Set<String> parseHeaderLogAllowlist(String? value) {
  if (value == null) {
    return const <String>{};
  }
  return <String>{
    for (final name in value.split(','))
      if (name.trim().isNotEmpty) name.trim().toLowerCase(),
  }..removeAll(alwaysRedactedHeaderNames);
}

/// Returns [value] when [name] is allowed to be logged, and
/// [redactedHeaderPlaceholder] otherwise.
String redactHeaderValue(String name, String value) {
  return _allowedHeaderNames.contains(name.toLowerCase())
      ? value
      : redactedHeaderPlaceholder;
}

/// Formats one header for the debug log as `name: value-or-placeholder`.
String formatHeaderForLog(String name, String value) {
  return '$name: ${redactHeaderValue(name, value)}';
}
