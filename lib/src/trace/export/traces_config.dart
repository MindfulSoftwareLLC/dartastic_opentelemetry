// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show OTelLog;

import '../../environment/otel_env.dart';
import '../../export/otlp_http_protocol.dart';
import '../../otel.dart';
import '../../resource/resource.dart';
import '../sampling/always_on_sampler.dart';
import '../sampling/parent_based_sampler.dart';
import '../sampling/sampler.dart';
import '../span_exception_options.dart';
import '../span_processor.dart';
import '../tracer_provider.dart';
import 'batch_span_processor.dart';
import 'composite_exporter.dart';
import 'console_exporter.dart';
import 'otlp/http/otlp_http_span_exporter.dart';
import 'otlp/http/otlp_http_span_exporter_config.dart';
import 'otlp/otlp_grpc_span_exporter.dart';
import 'otlp/otlp_grpc_span_exporter_config.dart';
import 'span_exporter.dart';

/// Configuration for traces exporters and processors.
class TracesConfiguration {
  /// Configures a TracerProvider with given settings.
  ///
  /// This configures everything needed for the traces pipeline:
  /// - An exporter selected per the OTel spec:
  ///   `OTEL_TRACES_EXPORTER=otlp` (default) → OtlpHttp/Grpc exporter,
  ///   `=console` → ConsoleExporter, `=none` → no processor is added.
  /// - A processor (defaults to BatchSpanProcessor if none provided)
  /// - Sets up resources on the TracerProvider
  static TracerProvider configureTracerProvider({
    String? endpoint,
    bool? secure,
    SpanProcessor? spanProcessor,
    Sampler? sampler,
    SpanExceptionOptions spanExceptionOptions = const SpanExceptionOptions(),
    Resource? resource,
    required OtlpEnvironmentValues otlpConfig,
    required List<String> exporters,
    required BspEnvironmentValues bspConfig,
  }) {
    final tracerProvider = OTel.tracerProvider();

    if (resource != null) {
      tracerProvider.resource = resource;
    }

    if (spanProcessor == null) {
      // Determine protocol - default to http/protobuf if not set
      final protocol = otlpConfig.protocol ?? 'http/protobuf';

      final resolvedEndpoint = otlpConfig.endpoint ??
          endpoint ??
          (protocol == 'grpc'
              ? OTel.defaultGrpcEndpoint
              : OTel.defaultEndpoint);
      final resolvedSecure = OTelEnv.resolveOtlpSecure(
        envInsecure: otlpConfig.insecure,
        endpoint: resolvedEndpoint,
        explicitSecure: secure,
      );

      SpanExporter buildOtlpExporter() {
        // Create appropriate exporter based on protocol
        if (protocol == 'grpc') {
          return OtlpGrpcSpanExporter(
            OtlpGrpcExporterConfig(
              endpoint: resolvedEndpoint,
              insecure: !resolvedSecure,
              headers: otlpConfig.headers ?? {},
              timeout: otlpConfig.timeout ?? const Duration(seconds: 10),
              compression: otlpConfig.compression == 'gzip',
              certificate: otlpConfig.certificate,
              clientKey: otlpConfig.clientKey,
              clientCertificate: otlpConfig.clientCertificate,
            ),
          );
        } else {
          final httpProtocol = otlpHttpProtocolFromString(protocol) ??
              OtlpHttpProtocol.httpProtobuf;
          return OtlpHttpSpanExporter(
            OtlpHttpExporterConfig(
              endpoint: resolvedEndpoint,
              headers: otlpConfig.headers ?? {},
              timeout: otlpConfig.timeout ?? const Duration(seconds: 10),
              compression: otlpConfig.compression == 'gzip',
              certificate: otlpConfig.certificate,
              clientKey: otlpConfig.clientKey,
              clientCertificate: otlpConfig.clientCertificate,
              protocol: httpProtocol,
            ),
          );
        }
      }

      if (exporters.contains('none')) {
        if (exporters.length > 1 && OTelLog.isWarn()) {
          OTelLog.warn("OTEL_TRACES_EXPORTER contains 'none' alongside other "
              'values; installing no exporter.');
        }
      } else {
        final createdExporters = <SpanExporter>[];
        for (final name in exporters) {
          switch (name) {
            case 'otlp':
              createdExporters.add(buildOtlpExporter());
            case 'console':
              createdExporters.add(ConsoleExporter());
            case 'logging':
              if (OTelLog.isWarn()) {
                OTelLog.warn("OTEL_TRACES_EXPORTER value 'logging' is "
                    "deprecated in the spec and not supported; use 'console'.");
              }
            default:
              if (OTelLog.isWarn()) {
                OTelLog.warn("OTEL_TRACES_EXPORTER value '$name' is not "
                    'supported; ignoring. Supported: otlp, console, none.');
              }
          }
        }
        if (createdExporters.isEmpty) {
          if (OTelLog.isWarn()) {
            OTelLog.warn('OTEL_TRACES_EXPORTER produced no usable exporter; '
                'falling back to the default otlp exporter.');
          }
          createdExporters.add(buildOtlpExporter());
        }

        final bspConfigObj =
            BatchSpanProcessorConfig.fromBspEnvironmentValues(bspConfig);
        spanProcessor = BatchSpanProcessor(
          createdExporters.length == 1
              ? createdExporters.single
              : CompositeExporter(createdExporters),
          bspConfigObj,
        );
      }
    }

    if (spanProcessor != null) {
      tracerProvider.addSpanProcessor(spanProcessor);
    }
    tracerProvider.sampler ??=
        sampler ?? ParentBasedSampler(const AlwaysOnSampler());
    tracerProvider.spanExceptionOptions = spanExceptionOptions;

    return tracerProvider;
  }
}
