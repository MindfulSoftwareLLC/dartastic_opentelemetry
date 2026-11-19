// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;

/// Native HTTP transport for the Prometheus pull reader.
class PrometheusServer {
  /// Whether this platform supports a scrape listener.
  static const supported = true;
  HttpServer? _server;

  /// Actual port, including the OS-assigned port when configured with zero.
  int? get port => _server?.port;

  /// Binds the listener and serves fresh metrics for each GET /metrics.
  Future<void> start(
      String host, int port, Future<String> Function() scrape) async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    server.listen((request) async {
      try {
        if (request.uri.path != '/metrics') {
          request.response.statusCode = HttpStatus.notFound;
        } else if (request.method != 'GET') {
          request.response.statusCode = HttpStatus.methodNotAllowed;
          request.response.headers.set(HttpHeaders.allowHeader, 'GET');
        } else if (!_acceptsText(request.headers[HttpHeaders.acceptHeader])) {
          request.response.statusCode = HttpStatus.notAcceptable;
        } else {
          final body = await scrape();
          request.response.headers.set(HttpHeaders.contentTypeHeader,
              'text/plain; version=0.0.4; charset=utf-8');
          request.response.write(body);
        }
      } catch (error) {
        if (OTelLog.isError()) {
          OTelLog.error('Prometheus scrape failed: $error');
        }
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        try {
          await request.response.close();
        } catch (_) {
          // A client may disconnect while collection is in progress.
        }
      }
    }, onError: (Object error) {
      if (OTelLog.isError()) {
        OTelLog.error('Prometheus listener error: $error');
      }
    });
  }

  // Only Prometheus text 0.0.4 is implemented. More specific ranges override
  // wildcards, including an explicit q=0 exclusion.
  bool _acceptsText(List<String>? headers) {
    if (headers == null || headers.join().trim().isEmpty) return true;
    var specificity = -1;
    var parameterSpecificity = -1;
    var quality = 0.0;
    for (final range in headers.join(',').split(',')) {
      final parts = range.trim().toLowerCase().split(';');
      final media = parts.first.trim();
      final rank = switch (media) {
        'text/plain' => 2,
        'text/*' => 1,
        '*/*' => 0,
        _ => -1,
      };
      if (rank < 0) continue;
      var q = 1.0;
      var compatible = true;
      var parameters = 0;
      for (final part in parts.skip(1)) {
        final pair = part.trim().split('=');
        if (pair.length != 2) continue;
        final key = pair[0].trim();
        final value = pair[1].trim().replaceAll('"', '');
        if (key == 'q') {
          q = double.tryParse(value) ?? 0;
        } else if (key == 'version') {
          compatible = compatible && value == '0.0.4';
          parameters++;
        } else if (key == 'charset') {
          compatible = compatible && value == 'utf-8';
          parameters++;
        } else if (key == 'escaping') {
          compatible = compatible && value == 'underscores';
          parameters++;
        }
      }
      if (!compatible || !q.isFinite || q < 0 || q > 1) continue;
      if (rank > specificity ||
          (rank == specificity && parameters > parameterSpecificity)) {
        specificity = rank;
        parameterSpecificity = parameters;
        quality = q;
      } else if (rank == specificity &&
          parameters == parameterSpecificity &&
          q > quality) {
        quality = q;
      }
    }
    return quality > 0;
  }

  /// Stops accepting scrapes and releases the listening socket.
  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }
}
