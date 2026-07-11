// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Helper functions below `main()` show alternate initialization paths;
// they aren't all reachable from this file's `main()`.
// ignore_for_file: unreachable_from_main

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Example-only attribute keys for things not in the OTel semantic
/// conventions (https://opentelemetry.io/docs/specs/semconv/). Always
/// check the conventions first — the API's built-in enums (User,
/// Http, Server, Database, Client,
/// Session) cover the spec keys. Rename this in your own
/// code (e.g. `CheckoutAttribute`) so the names reflect your domain.
enum ExampleAttribute implements OTelSemantic {
  authMethod('auth.method'),
  permissions('permissions');

  @override
  final String key;

  @override
  String toString() => key;

  const ExampleAttribute(this.key);
}

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
    'Service: ${OTel.defaultResource?.attributes.toList().firstWhere((a) => a.key == Service.serviceName.key).value}',
  );

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

/// Example: Tracing a user login operation.
Future<void> traceUserLogin(Tracer tracer, String userId) async {
  final span = tracer.startSpan(
    'user.login',
    kind: SpanKind.server,
    attributes: OTel.attributesFromSemanticMap({
      User.userId: userId,
      ExampleAttribute.authMethod: 'oauth2',
      // client.address replaces the deprecated client.ip per OTel semconv.
      Client.clientAddress: '192.168.1.100',
    }),
  );

  try {
    // Simulate authentication check.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Add event for successful authentication.
    span.addEvent(
      OTel.spanEventNow(
        'authentication.success',
        OTel.attributesFromSemanticMap({
          Session.sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          ExampleAttribute.permissions: 'read,write',
        }),
      ),
    );
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Example: Tracing an HTTP request
Future<void> traceHttpRequest(Tracer tracer) async {
  // `attributesOf<E>` is the single-enum form — every key is checked
  // against `Http` at compile time, and Dart 3.10's static dot-shorthand
  // can shorten each entry to `.requestMethod`, `.urlFull`, etc.
  // `ServerResource` (which keeps its suffix because plain `Server`
  // clashes with `package:grpc`'s `Server`) is mixed in via a map spread
  // — Dart widens the literal's type to `Map<OTelSemantic, Object>`
  // automatically, so `attributesFromSemanticMap` accepts it.
  final span = tracer.startSpan(
    'http.request',
    kind: SpanKind.client,
    attributes: OTel.attributesFromSemanticMap({
      ...<Http, Object>{
        Http.requestMethod: 'GET',
      },
      ...<Url, Object>{
        Url.urlFull: 'https://api.example.com/users/123',
        Url.urlPath: '/users/123',
      },
      ...<ServerResource, Object>{
        ServerResource.serverAddress: 'api.example.com',
        ServerResource.serverPort: 443,
      },
    }),
  );

  try {
    // Simulate HTTP request.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Single-namespace addition — pure `Http` so we use the shorter
    // `attributesOf<Http>` form.
    span.addAttributes(
      OTel.attributesOf<Http>({
        Http.responseStatusCode: 200,
        Http.responseBodySize: 1234,
      }),
    );
  } catch (e, stackTrace) {
    span.addAttributes(OTel.attributesOf<Http>({Http.responseStatusCode: 500}));
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, 'HTTP request failed: $e');
    rethrow;
  } finally {
    span.end();
  }
}

/// Example: Tracing a database operation.
Future<void> traceDatabaseOperation(Tracer tracer) async {
  final span = tracer.startSpan(
    'db.query',
    kind: SpanKind.client,
    attributes: OTel.attributesFromSemanticMap({
      Database.dbSystem: 'postgresql',
      Database.dbName: 'users_db',
      Database.dbOperation: 'SELECT',
      Database.dbStatement: 'SELECT * FROM users WHERE active = true LIMIT 100',
      Database.dbUser: 'app_user',
      // server.address / server.port replace the deprecated net.peer.*
      // per OTel semconv.
      ServerResource.serverAddress: 'postgres.example.com',
      ServerResource.serverPort: 5432,
    }),
  );

  try {
    // Simulate database query.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Add result metadata.
    span.addAttributes(
        Attributes.of({Database.dbResponseReturnedRows.key: 42}));
  } catch (e, stackTrace) {
    // The span has a status of SpanStatus.Ok on creation, set it to
    // Error when an error occurs in the span.
    span.recordException(e, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, 'Database query failed: $e');
    rethrow;
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
          headers: {'authorization': 'Basic $base64Credentials'},
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
