// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert' show utf8;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../otel.dart';

/// Implementation of the W3C Baggage specification for context propagation.
///
/// This propagator handles the extraction and injection of baggage information
/// following the W3C Baggage specification as defined at:
/// https://www.w3.org/TR/baggage/
///
/// Baggage allows for propagating key-value pairs alongside the trace context
/// across service boundaries. This enables the correlation of related telemetry
/// using application-specific or domain-specific properties.
class W3CBaggagePropagator
    implements TextMapPropagator<Map<String, String>, String> {
  /// The standard header name for W3C baggage as defined in the specification
  static const _baggageHeader = 'baggage';

  /// Extracts baggage information from the carrier and updates the context.
  ///
  /// This method parses the W3C baggage header and creates a new baggage
  /// context to return as part of the updated Context.
  ///
  /// @param context The current context
  /// @param carrier The carrier containing the baggage header
  /// @param getter The getter used to extract values from the carrier
  /// @return A new Context with the extracted baggage
  @override
  Context extract(
    Context context,
    Map<String, String> carrier,
    TextMapGetter<String> getter,
  ) {
    final value = getter.get(_baggageHeader);
    if (OTelLog.isDebug()) {
      OTelLog.debug('Extracting baggage: $value');
    }
    if (value == null || value.isEmpty) {
      // Propagators API spec: extract returns the passed context, updated
      // with extracted values — and unchanged when there is nothing to
      // extract. Returning a fresh context here would discard whatever an
      // earlier propagator in a composite (e.g. tracecontext) extracted.
      return context;
    }

    final entries = <String, BaggageEntry>{};
    final pairs = value.split(',');
    for (final pair in pairs) {
      final trimmedPair = pair.trim();
      if (trimmedPair.isEmpty) continue;

      // Split on the first '=' only — the W3C Baggage spec allows '='
      // inside values (e.g. base64 padding like "token=abc123==").
      final eqIndex = trimmedPair.indexOf('=');
      if (eqIndex <= 0) continue;

      // Keys are tokens per RFC 7230 — they are NOT percent-encoded or
      // decoded on the wire. Apply the same token rule inject applies so a
      // pass-through hop cannot lose entries (extract→inject symmetry).
      final key = trimmedPair.substring(0, eqIndex).trim();
      if (!_isValidToken(key)) continue;

      final valueAndMetadata = trimmedPair.substring(eqIndex + 1).split(';');

      // W3C Baggage: an unparsable list member is ignored, not fatal — one
      // malformed entry must neither break the rest of the header nor, in
      // composite propagation, prevent traceparent from being parsed.
      String value;
      try {
        value = _decodeValue(valueAndMetadata[0].trim());
      }
      // ignore: avoid_catching_errors
      on ArgumentError {
        // Uri.decodeComponent signals truncated/invalid escapes as
        // ArgumentError; W3C says skip the list member.
        continue;
      } on FormatException {
        continue;
      }

      String? metadata;
      if (valueAndMetadata.length > 1) {
        metadata = _safeDecode(valueAndMetadata.sublist(1).join(';').trim());
      }

      entries[key] = OTel.baggageEntry(value, metadata);
    }

    // Propagators API spec: "If a value can not be parsed from the carrier
    // for a cross-cutting concern, the implementation MUST NOT store a new
    // value in the Context, in order to preserve any previously existing
    // valid value."  An empty entry map means nothing was parsed, so we
    // return the original context untouched.
    if (entries.isEmpty) return context;
    final baggage = OTel.baggage(entries);
    return context.withBaggage(baggage);
  }

  /// Injects baggage from the context into the carrier.
  ///
  /// This method serializes the baggage from the context into the
  /// W3C baggage header format and adds it to the carrier.
  ///
  /// @param context The context containing baggage to be injected
  /// @param carrier The carrier to inject the baggage header into
  /// @param setter The setter used to add values to the carrier
  @override
  void inject(
    Context context,
    Map<String, String> carrier,
    TextMapSetter<String> setter,
  ) {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Injecting baggage. Context: $context');
    }
    final contextBaggage = context.baggage;
    if (contextBaggage != null) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
          'Context baggage: $contextBaggage (${contextBaggage.runtimeType})',
        );
      }

      final baggage = contextBaggage;
      final entries = baggage.getAllEntries();
      if (OTelLog.isDebug()) OTelLog.debug('Baggage entries: $entries');

      if (entries.isEmpty) {
        if (OTelLog.isDebug()) OTelLog.debug('Empty baggage entries');
        return;
      }

      final serializedEntries = entries.entries.where((entry) {
        if (!_isValidToken(entry.key)) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
              'Dropping baggage entry with invalid key: ${entry.key}',
            );
          }
          return false;
        }
        return true;
      }).map((entry) {
        final key = entry.key;
        final value = _encodeValue(entry.value.value);
        final metadata = entry.value.metadata;
        if (OTelLog.isDebug()) {
          OTelLog.debug(
            'Processing entry - Key: $key, Value: $value, Metadata: $metadata',
          );
        }
        // Metadata is `property = token "=" *baggage-octet` on the wire and
        // free text in the API, so it must go through the same encoding as
        // values or a raw `,`/`;`/CRLF in it would forge extra list members.
        if (metadata != null && metadata.isNotEmpty) {
          return '$key=$value;${_encodeValue(metadata)}';
        }
        return '$key=$value';
      }).join(',');

      if (OTelLog.isDebug()) {
        OTelLog.debug('Setting baggage header to: $serializedEntries');
      }
      if (serializedEntries.isNotEmpty) {
        setter.set(_baggageHeader, serializedEntries);
      }
    }
  }

  /// Returns the list of propagation fields used by this propagator.
  ///
  /// @return A list containing the baggage header name
  @override
  List<String> fields() => const [_baggageHeader];

  /// Matches an RFC 7230 `token`, the grammar W3C Baggage requires for
  /// keys (and property names): `!`, `#`, `$`, `%`, `&`, `'`, `*`, `+`,
  /// `-`, `.`, `^`, `_`, `` ` ``, `|`, `~`, DIGIT, ALPHA.
  static final RegExp _token = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  /// Checks whether [key] is a valid W3C Baggage key.
  bool _isValidToken(String key) => _token.hasMatch(key);

  /// Whether [octet] is in the W3C Baggage `baggage-octet` set
  /// (`%x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E`) — i.e. printable
  /// ASCII excluding space, `"`, `,`, `;`, `\`, controls, and non-ASCII.
  static bool _isBaggageOctet(int octet) =>
      octet >= 0x21 &&
      octet <= 0x7E &&
      octet != 0x22 && // "
      octet != 0x2C && // ,
      octet != 0x3B && // ;
      octet != 0x5C; //   \

  /// Encodes a baggage value per the W3C Baggage specification.
  ///
  /// Allowlist encoding: every UTF-8 byte outside `baggage-octet`
  /// (non-ASCII included) is percent-encoded with uppercase hex. `%` itself
  /// is always emitted as `%25` even though it is a valid octet — otherwise
  /// the decoder could misread pre-existing escape sequences and the codec
  /// would not be injective (e.g. `a%2Cb` must not decode to `a,b`).
  String _encodeValue(String value) {
    final buffer = StringBuffer();
    for (final octet in utf8.encode(value)) {
      if (octet == 0x25) {
        buffer.write('%25');
      } else if (_isBaggageOctet(octet)) {
        buffer.writeCharCode(octet);
      } else {
        buffer.write(
          '%${octet.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }

  /// Decodes a baggage value (plain percent-decoding, no form-style `+`).
  ///
  /// Throws [ArgumentError] or [FormatException] on malformed input;
  /// callers guard per entry per the W3C "ignore unparsable member" rule.
  String _decodeValue(String value) {
    return Uri.decodeComponent(value);
  }

  /// Best-effort decode used for metadata: returns the input unchanged when
  /// it is not valid percent-encoding, since metadata is auxiliary and must
  /// never be able to fail the surrounding entry.
  static String _safeDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    }
    // ignore: avoid_catching_errors
    on ArgumentError {
      return value;
    } on FormatException {
      return value;
    }
  }
}
