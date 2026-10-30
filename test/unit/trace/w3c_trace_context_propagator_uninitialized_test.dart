// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

/// Runs in its own file so no other test has initialized the SDK.
void main() {
  test('extract before OTel.initialize() drops the header without throwing',
      () {
    final context = OTelAPI.context();
    final carrier = {
      'traceparent': '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
    };

    final extracted = W3CTraceContextPropagator().extract(
      context,
      carrier,
      _MapGetter(carrier),
    );

    expect(extracted, same(context));
  });
}

class _MapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;

  _MapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}
