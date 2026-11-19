// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

/// Platform adapter for the Prometheus HTTP listener.
class PrometheusServer {
  /// Whether this platform can listen for HTTP scrapes.
  static const supported = false;

  /// The actual listening port, or null before binding.
  int? get port => null;

  /// Starts the listener on platforms with socket support.
  Future<void> start(String host, int port, Future<String> Function() scrape) =>
      Future.error(UnsupportedError('Prometheus requires dart:io.'));

  /// Closes the listener.
  Future<void> close() async {}
}
