// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Example: Configuring OpenTelemetry for Grafana Cloud using environment variables
///
/// This example demonstrates how to use OTEL_EXPORTER_OTLP_HEADERS to configure
/// authentication for services like telemetrymacros.grafana.net.
///
/// To use this example:
/// 1. Get your Grafana Cloud credentials:
///    - Instance ID (used as username)
///    - API Token (used as password)
///
/// 2. Create the Authorization header:
///    - Combine as: instance-id:api-token
///    - Base64 encode the combination
///    - Result: Basic \<base64-encoded-credentials>
///
/// 3. Set the environment variables before running your application:
///    ```bash
///    export OTEL_SERVICE_NAME="my-dart-app"
///    export OTEL_RESOURCE_ATTRIBUTES="service.version=1.2.3"
///    export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
///    export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <your-base64-encoded-credentials>"
///    export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
///    export OTEL_EXPORTER_OTLP_COMPRESSION="gzip"
///    ```
///
/// 4. Run your Dart application - it will automatically use these settings
Future<void> main() async {
  // Initialize OpenTelemetry
  // The SDK will automatically read all OTEL_* environment variables
  await OTel.initialize();

  print('OpenTelemetry initialized with environment configuration');
  print(
      'Service: ${OTel.defaultResource?.attributes.toList().firstWhere((a) => a.key == 'service.name').value}');

  // Create a tracer
  final tracer = OTel.tracer();

  // Example: Trace a simple operation
  await traceUserLogin(tracer, 'user123');

  // Example: Trace an HTTP request
  await traceHttpRequest(tracer);

  // Example: Trace a database operation
  await traceDatabaseOperation(tracer);

  // Ensure all spans are exported before exiting
  await OTel.tracerProvider().forceFlush();
  await OTel.shutdown();

  print('All spans exported to Grafana Cloud');
}

/// Example: Tracing a user login operation
Future<void> traceUserLogin(Tracer tracer, String userId) async {
  final span = tracer.startSpan(
    'user.login',
    kind: SpanKind.server,
    attributes: OTel.attributesFromMap({
      'user.id': userId,
      'auth.method': 'oauth2',
      'client.ip': '192.168.1.100',
    }),
  );

  try {
    // Simulate authentication check
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Add event for successful authentication
    span.addEvent(OTel.spanEventNow(
      'authentication.success',
      OTel.attributesFromMap({
        'session.id': 'sess_${DateTime.now().millisecondsSinceEpoch}',
        'permissions': 'read,write',
      }),
    ));

    // Record success
    span.setStatus(SpanStatusCode.Ok);
  } catch (error) {
    // Record error
    span.setStatus(SpanStatusCode.Error, error.toString());
    span.recordException(error);
  } finally {
    span.end();
  }
}

/// Example: Tracing an HTTP request
Future<void> traceHttpRequest(Tracer tracer) async {
  final span = tracer.startSpan(
    'http.request',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap({
      'http.method': 'GET',
      'http.url': 'https://api.example.com/users/123',
      'http.target': '/users/123',
      'net.peer.name': 'api.example.com',
      'net.peer.port': 443,
    }),
  );

  try {
    // Simulate HTTP request
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Set response attributes
    span.addAttributes(OTel.attributesFromMap({
      'http.status_code': 200,
      'http.response_content_length': 1234,
    }));

    span.setStatus(SpanStatusCode.Ok);
  } catch (error) {
    span.addAttributes(OTel.attributesFromMap({
      'http.status_code': 500,
    }));
    span.setStatus(SpanStatusCode.Error, 'HTTP request failed');
    span.recordException(error);
  } finally {
    span.end();
  }
}

/// Example: Tracing a database operation
Future<void> traceDatabaseOperation(Tracer tracer) async {
  final span = tracer.startSpan(
    'db.query',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap({
      'db.system': 'postgresql',
      'db.name': 'users_db',
      'db.operation': 'SELECT',
      'db.statement': 'SELECT * FROM users WHERE active = true LIMIT 100',
      'db.user': 'app_user',
      'net.peer.name': 'postgres.example.com',
      'net.peer.port': 5432,
    }),
  );

  try {
    // Simulate database query
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Add result metadata
    span.addAttributes(Attributes.of({'db.rows_affected': 42}));
    span.setStatus(SpanStatusCode.Ok);
  } catch (error) {
    span.setStatus(SpanStatusCode.Error, 'Database query failed');
    span.recordException(error);
  } finally {
    span.end();
  }
}

/// Alternative: Programmatic configuration (if not using environment variables)
///
/// If you prefer to configure in code rather than environment variables:
Future<void> initializeWithCode() async {
  // Get credentials from secure storage or configuration
  final instanceId = 'your-grafana-instance-id';
  final apiToken = 'your-grafana-api-token';

  // Create the authorization header
  final credentials = '$instanceId:$apiToken';
  final base64Credentials = base64Encode(utf8.encode(credentials));

  await OTel.initialize(
    serviceName: 'my-dart-app',
    serviceVersion: '1.0.0',
    endpoint: 'https://otlp-gateway-prod-us-central-0.grafana.net/otlp',
    spanProcessor: BatchSpanProcessor(
      OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'https://otlp-gateway-prod-us-central-0.grafana.net/otlp',
          headers: {
            'authorization': 'Basic $base64Credentials',
          },
          compression: true,
        ),
      ),
    ),
  );
}

/// Example: Using custom certificates for secure connections
///
/// This example shows how to configure custom TLS certificates for:
/// 1. Verifying the server's certificate (CA certificate)
/// 2. Client authentication with mutual TLS (mTLS)
///
/// To use with environment variables:
/// ```bash
/// export OTEL_SERVICE_NAME="my-secure-app"
/// export OTEL_EXPORTER_OTLP_ENDPOINT="https://secure-collector:4318"
/// export OTEL_EXPORTER_OTLP_CERTIFICATE="/path/to/ca.pem"
/// export OTEL_EXPORTER_OTLP_CLIENT_KEY="/path/to/client.key"
/// export OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE="/path/to/client.pem"
/// export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
/// ```
Future<void> initializeWithCertificates() async {
  // For programmatic configuration with certificates:
  await OTel.initialize(
    serviceName: 'my-secure-app',
    serviceVersion: '1.0.0',
    spanProcessor: BatchSpanProcessor(
      OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'https://secure-collector:4318/v1/traces',
          // CA certificate to verify the server
          certificate: '/path/to/ca.pem',
          // Client certificate and key for mutual TLS (mTLS)
          clientKey: '/path/to/client.key',
          clientCertificate: '/path/to/client.pem',
          compression: true,
        ),
      ),
    ),
  );
}

/// Example: Combining headers and certificates
///
/// Some services require both authentication headers AND custom certificates.
/// This example shows how to use both together.
Future<void> initializeWithHeadersAndCertificates() async {
  final apiKey = 'your-api-key';

  await OTel.initialize(
    serviceName: 'my-app',
    serviceVersion: '1.0.0',
    spanProcessor: BatchSpanProcessor(
      OtlpHttpSpanExporter(
        OtlpHttpExporterConfig(
          endpoint: 'https://secure-endpoint:4318/v1/traces',
          headers: {
            'authorization': 'Bearer $apiKey',
            'x-tenant-id': 'my-tenant',
          },
          certificate: '/path/to/ca.pem',
          clientKey: '/path/to/client.key',
          clientCertificate: '/path/to/client.pem',
          compression: true,
        ),
      ),
    ),
  );
}
