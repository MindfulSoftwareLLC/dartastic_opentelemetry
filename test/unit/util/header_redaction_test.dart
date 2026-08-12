// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  group('header redaction', () {
    tearDown(() {
      configureHeaderLogAllowlist(null);
    });

    test('redacts every value by default', () {
      expect(redactHeaderValue('x-trace-id', 'abc123'), '[REDACTED]');
      expect(redactHeaderValue('authorization', 'Bearer token'), '[REDACTED]');
    });

    test('placeholder does not carry the value length', () {
      expect(redactHeaderValue('x-api-key', 'short'),
          redactHeaderValue('x-api-key', 'a-much-longer-secret-value'));
    });

    test('allowlisted names log their value', () {
      configureHeaderLogAllowlist(['x-trace-id']);

      expect(redactHeaderValue('x-trace-id', 'abc123'), 'abc123');
      expect(redactHeaderValue('x-api-key', 'secret'), '[REDACTED]');
    });

    test('matching is case insensitive on both sides', () {
      configureHeaderLogAllowlist(['X-Trace-Id']);

      expect(redactHeaderValue('x-trace-id', 'abc123'), 'abc123');
      expect(redactHeaderValue('X-TRACE-ID', 'abc123'), 'abc123');
    });

    test('matching is exact, not by prefix', () {
      configureHeaderLogAllowlist(['x-trace']);

      // the reason prefixes are not supported: 'x-' would opt in 'x-api-key'
      expect(redactHeaderValue('x-trace-id', 'abc123'), '[REDACTED]');
      expect(redactHeaderValue('x-trace', 'abc123'), 'abc123');
    });

    test('authorization headers cannot be allowlisted', () {
      configureHeaderLogAllowlist(
          ['authorization', 'Proxy-Authorization', 'x-trace-id']);

      expect(redactHeaderValue('authorization', 'Bearer token'), '[REDACTED]');
      expect(
          redactHeaderValue('proxy-authorization', 'Basic abc'), '[REDACTED]');
      expect(redactHeaderValue('x-trace-id', 'abc123'), 'abc123');
      expect(allowedHeaderLogNames, {'x-trace-id'});
    });

    test('a later allowlist replaces the previous one', () {
      configureHeaderLogAllowlist(['x-trace-id']);
      configureHeaderLogAllowlist(['x-tenant']);

      expect(redactHeaderValue('x-trace-id', 'abc123'), '[REDACTED]');
      expect(redactHeaderValue('x-tenant', 'acme'), 'acme');
    });

    test('formatHeaderForLog keeps the name and redacts the value', () {
      expect(
          formatHeaderForLog('X-Api-Key', 'secret'), 'X-Api-Key: [REDACTED]');
    });
  });

  group('parseHeaderLogAllowlist', () {
    test('splits on commas, trims, drops empties and lowercases', () {
      expect(parseHeaderLogAllowlist(' x-trace-id , ,X-Tenant, '),
          {'x-trace-id', 'x-tenant'});
    });

    test('deduplicates', () {
      expect(parseHeaderLogAllowlist('x-trace-id,X-TRACE-ID,x-trace-id'),
          {'x-trace-id'});
    });

    test('null and empty give an empty allowlist', () {
      expect(parseHeaderLogAllowlist(null), isEmpty);
      expect(parseHeaderLogAllowlist(''), isEmpty);
      expect(parseHeaderLogAllowlist(' , , '), isEmpty);
    });

    test('drops the always redacted names', () {
      expect(parseHeaderLogAllowlist('authorization,proxy-authorization,x-ok'),
          {'x-ok'});
    });
  });
}
