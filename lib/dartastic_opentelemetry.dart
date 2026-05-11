// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Re-export key OpenTelemetry API components for convenience
library;

export 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show
        AppInfoSemantics,
        AppLifecycleSemantics,
        Attributes,
        AttributesExtension,
        Baggage,
        BaggageEntry,
        Client,
        Cloud,
        ComputeInstance,
        ComputeUnit,
        Context,
        ContextKey,
        Database,
        Deployment,
        Device,
        DeviceSemantics,
        Environment,
        ErrorResource,
        ErrorSemantics,
        ExceptionResource,
        FeatureFlag,
        FileResource,
        GenAI,
        General,
        GraphQL,
        Host,
        Http,
        IdGenerator,
        InstrumentationScope,
        InteractionSemantics,
        Kubernetes,
        LifecycleState,
        LogRecord,
        Measurement,
        Messaging,
        NavigationAction,
        NavigationSemantics,
        Network,
        NetworkSemantics,
        OTelLog,
        OTelSemantic,
        OTelSemanticExtension,
        OperatingSystem,
        PerformanceSemantics,
        ProcessResource,
        RPC,
        ServerResource,
        Service,
        Session,
        Severity,
        SeverityLevel,
        SourceCode,
        SpanContext,
        SpanEvent,
        SpanId,
        SpanKind,
        SpanLink,
        SpanStatusCode,
        SystemTimeProvider,
        TelemetryDistro,
        TelemetrySDK,
        TimeProvider,
        Timestamp,
        TraceFlags,
        TraceId,
        TraceState,
        Url,
        User,
        Version,
        WebTimeProvider,
        defaultTimeProvider;

export 'src/context/propagation/w3c_baggage_propagator.dart';
export 'src/environment/env_constants.dart';
export 'src/environment/environment_service.dart';
export 'src/environment/otel_env.dart';
export 'src/export/export_result.dart';
export 'src/export/otlp_http_protocol.dart';
export 'src/factory/otel_sdk_factory.dart';
export 'src/logs/bridge/dart_log_bridge.dart';
export 'src/logs/export/batch_log_record_processor.dart';
export 'src/logs/export/console_log_record_exporter.dart';
export 'src/logs/export/log_record_exporter.dart';
export 'src/logs/export/logs_config.dart';
export 'src/logs/export/otlp/http/otlp_http_log_record_exporter.dart';
export 'src/logs/export/otlp/http/otlp_http_log_record_exporter_config.dart';
export 'src/logs/export/otlp/log_record_transformer.dart';
export 'src/logs/export/otlp/otlp_grpc_log_record_exporter.dart';
export 'src/logs/export/otlp/otlp_grpc_log_record_exporter_config.dart';
export 'src/logs/export/simple_log_record_processor.dart';
export 'src/logs/log_record_processor.dart';
export 'src/logs/logger.dart';
export 'src/logs/logger_provider.dart';
export 'src/logs/readable_log_record.dart';
export 'src/metrics/data/exemplar.dart';
export 'src/metrics/data/metric.dart';
export 'src/metrics/data/metric_data.dart';
export 'src/metrics/data/metric_point.dart';
export 'src/metrics/export/composite_metric_exporter.dart';
export 'src/metrics/export/metric_config.dart';
export 'src/metrics/export/otlp/http/otlp_http_metric_exporter.dart';
export 'src/metrics/export/otlp/http/otlp_http_metric_exporter_config.dart';
export 'src/metrics/export/otlp/otlp_grpc_metric_exporter.dart';
export 'src/metrics/export/otlp/otlp_grpc_metric_exporter_config.dart';
export 'src/metrics/export/prometheus/prometheus_exporter.dart';
export 'src/metrics/instruments/base_instrument.dart';
export 'src/metrics/instruments/counter.dart';
export 'src/metrics/instruments/gauge.dart';
export 'src/metrics/instruments/histogram.dart';
export 'src/metrics/instruments/observable_counter.dart';
export 'src/metrics/instruments/observable_gauge.dart';
export 'src/metrics/instruments/observable_up_down_counter.dart';
export 'src/metrics/instruments/up_down_counter.dart';
export 'src/metrics/meter.dart';
export 'src/metrics/meter_provider.dart';
export 'src/metrics/metric_exporter.dart';
export 'src/metrics/metric_reader.dart';
export 'src/metrics/observe/observable_result.dart';
export 'src/metrics/storage/gauge_storage.dart';
export 'src/metrics/storage/histogram_storage.dart';
export 'src/metrics/storage/metric_storage.dart';
export 'src/metrics/storage/point_storage.dart';
export 'src/metrics/storage/sum_storage.dart';
export 'src/metrics/view.dart';
export 'src/otel.dart';
export 'src/resource/resource.dart';
export 'src/resource/resource_detector.dart';
export 'src/resource/web_detector.dart';
export 'src/trace/export/baggage_span_processor.dart';
export 'src/trace/export/batch_span_processor.dart';
export 'src/trace/export/composite_exporter.dart';
export 'src/trace/export/console_exporter.dart';
export 'src/trace/export/otlp/http/otlp_http_span_exporter.dart';
export 'src/trace/export/otlp/http/otlp_http_span_exporter_config.dart';
export 'src/trace/export/otlp/otlp_grpc_span_exporter.dart';
export 'src/trace/export/otlp/otlp_grpc_span_exporter_config.dart';
export 'src/trace/export/otlp/span_transformer.dart';
export 'src/trace/export/simple_span_processor.dart';
export 'src/trace/export/span_exporter.dart';
// Only export the implementation files, not the duplicated classes in sampler.dart
export 'src/trace/sampling/always_off_sampler.dart';
export 'src/trace/sampling/always_on_sampler.dart';
export 'src/trace/sampling/composite_sampler.dart';
export 'src/trace/sampling/counting_sampler.dart';
export 'src/trace/sampling/parent_based_sampler.dart';
export 'src/trace/sampling/probability_sampler.dart';
export 'src/trace/sampling/rate_limiting_sampler.dart';
export 'src/trace/sampling/sampler.dart';
export 'src/trace/sampling/trace_id_ratio_sampler.dart';
export 'src/trace/span.dart';
export 'src/trace/span_processor.dart';
export 'src/trace/tracer.dart';
export 'src/trace/tracer_provider.dart';
export 'src/trace/w3c_trace_context_propagator.dart';
