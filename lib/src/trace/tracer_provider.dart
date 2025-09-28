// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../dartastic_opentelemetry.dart';

part 'tracer_provider_create.dart';

/// SDK implementation of the APITracerProvider interface.
///
/// The TracerProvider is the entry point to the tracing API. It is responsible
/// for creating and managing Tracers, as well as configuring the tracing
/// pipeline via SpanProcessors and Exporters.
///
/// This implementation delegates some functionality to the API TracerProvider
/// implementation while adding SDK-specific behaviors like span processor management
/// and resource association.
///
/// Note: Per [OTEP 0265](https://opentelemetry.io/docs/specs/semconv/general/events/),
/// span events are being deprecated and will be replaced by the Logging API in future versions.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/trace/sdk/
class TracerProvider implements APITracerProvider {
  /// Registry of tracers managed by this provider.
  final Map<String, Tracer> _tracers = {};

  /// Span processors registered with this provider.
  final List<SpanProcessor> _spanProcessors = [];

  /// The underlying API TracerProvider implementation.
  final APITracerProvider _delegate;

  /// The resource associated with this provider.
  Resource? resource;

  /// The default sampler to use for new tracers.
  Sampler? sampler;

  @override
  bool get isShutdown => _delegate.isShutdown;

  @override
  set isShutdown(bool value) {
    _delegate.isShutdown = value;
  }

  /// Private constructor for creating TracerProvider instances.
  ///
  /// @param delegate The API TracerProvider implementation to delegate to
  /// @param resource Optional Resource describing the entity producing telemetry
  /// @param sampler Optional default sampler for tracers created by this provider
  TracerProvider._({
    required APITracerProvider delegate,
    this.resource,
    Sampler? sampler,
  }) : _delegate = delegate {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'TracerProvider: Created with resource: $resource, sampler: $sampler');
      if (resource != null) {
        OTelLog.debug('Resource attributes:');
        resource!.attributes.toList().forEach((attr) {
          OTelLog.debug('  ${attr.key}: ${attr.value}');
        });
      }
    }
  }

  @override
  Future<bool> shutdown() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'TracerProvider: Shutting down with ${_spanProcessors.length} processors');
    }
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'TracerProvider: Shutting down with ${_spanProcessors.length} processors');
    }

    if (!isShutdown) {
      // Shutdown all span processors
      for (final processor in _spanProcessors) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'TracerProvider: Shutting down processor ${processor.runtimeType}');
        }
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'SDKTracerProvider: Shutting down processor ${processor.runtimeType}');
        }
        try {
          await processor.shutdown();
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'TracerProvider: Successfully shut down processor ${processor.runtimeType}');
          }
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'TracerProvider: Error shutting down processor ${processor.runtimeType}: $e');
          }
        }
      }

      // Clear cached tracers
      _tracers.clear();
      if (OTelLog.isDebug()) {
        OTelLog.debug('TracerProvider: Cleared cached tracers');
      }

      try {
        await _delegate.shutdown();
        if (OTelLog.isDebug()) {
          OTelLog.debug('TracerProvider: Delegate shutdown complete');
        }
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('TracerProvider: Error during delegate shutdown: $e');
        }
      }

      isShutdown = true;
      if (OTelLog.isDebug()) OTelLog.debug('TracerProvider: Shutdown complete');
    } else {
      if (OTelLog.isDebug()) OTelLog.debug('TracerProvider: Already shut down');
    }
    return isShutdown;
  }

  @override
  Tracer getTracer(
    String name, {
    String? version,
    String? schemaUrl,
    Attributes? attributes,
    Sampler? sampler,
  }) {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'TracerProvider: Getting tracer with name: $name, version: $version, schemaUrl: $schemaUrl');
    }
    if (isShutdown) {
      throw StateError('TracerProvider has been shut down');
    }

    // Ensure resource is set before creating tracer
    ensureResourceIsSet();

    final key = '$name:${version ?? ''}';
    return _tracers.putIfAbsent(
      key,
      () => SDKTracerCreate.create(
        delegate: _delegate.getTracer(
          name,
          version: version,
          schemaUrl: schemaUrl,
          attributes: attributes,
        ),
        provider: this,
        sampler: sampler,
      ) as Tracer,
    );
  }

  /// Adds a span processor to this provider.
  ///
  /// Span processors are notified of span lifecycle events and are responsible
  /// for additional processing of spans, such as exporting them.
  ///
  /// @param processor The span processor to add
  void addSpanProcessor(SpanProcessor processor) {
    if (isShutdown) {
      throw StateError('TracerProvider has been shut down');
    }
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'SDKTracerProvider: Adding span processor of type ${processor.runtimeType}');
    }
    _spanProcessors.add(processor);
  }

  /// Gets all registered span processors.
  ///
  /// @return An unmodifiable list of all span processors
  List<SpanProcessor> get spanProcessors => List.unmodifiable(_spanProcessors);

  /// Ensures the resource for this provider is properly set.
  ///
  /// If no resource has been set, the default resource will be used.
  void ensureResourceIsSet() {
    if (resource == null) {
      resource = OTel.defaultResource;
      if (OTelLog.isDebug()) {
        OTelLog.debug('TracerProvider: Setting resource from default');
        if (resource != null) {
          OTelLog.debug('Resource attributes:');
          resource!.attributes.toList().forEach((attr) {
            if (attr.key == 'tenant_id' || attr.key == 'service.name') {
              OTelLog.debug('  ${attr.key}: ${attr.value}');
            }
          });
        }
      }
    }
  }

  @override
  String get endpoint => _delegate.endpoint;

  @override
  set endpoint(String value) {
    _delegate.endpoint = value;
  }

  @override
  String get serviceName => _delegate.serviceName;

  @override
  set serviceName(String value) {
    _delegate.serviceName = value;
  }

  @override
  String? get serviceVersion => _delegate.serviceVersion;

  @override
  set serviceVersion(String? value) {
    _delegate.serviceVersion = value;
  }

  @override
  bool get enabled => _delegate.enabled;

  @override
  set enabled(bool value) {
    _delegate.enabled = value;
  }

  /// Forces all span processors to flush any queued spans.
  ///
  /// This method is useful for ensuring that all spans are exported
  /// before the application terminates or when immediate visibility
  /// of spans is required.
  ///
  /// @return A Future that completes when all processors have been flushed
  Future<void> forceFlush() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'TracerProvider: Force flushing ${_spanProcessors.length} processors');
    }

    if (isShutdown) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'TracerProvider: Cannot force flush - provider is shut down');
      }
      return;
    }

    for (var processor in _spanProcessors) {
      try {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'TracerProvider: Flushing processor ${processor.runtimeType}');
        }
        await processor.forceFlush();
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'TracerProvider: Successfully flushed processor ${processor.runtimeType}');
        }
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'TracerProvider: Error flushing processor ${processor.runtimeType}: $e');
        }
      }
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('TracerProvider: Force flush complete');
    }
  }
}
