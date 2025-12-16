// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../../dartastic_opentelemetry.dart';

part 'logger_provider_create.dart';

/// SDK implementation of the APILoggerProvider interface.
///
/// The LoggerProvider is the entry point to the logging API. It is responsible
/// for creating and managing Loggers, as well as configuring the logging
/// pipeline via LogRecordProcessors and Exporters.
///
/// This implementation delegates some functionality to the API LoggerProvider
/// implementation while adding SDK-specific behaviors like log processor management
/// and resource association.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/
class LoggerProvider implements APILoggerProvider {
  /// Registry of loggers managed by this provider.
  final Map<String, Logger> _loggers = {};

  /// Log record processors registered with this provider.
  final List<LogRecordProcessor> _logRecordProcessors = [];

  /// The underlying API LoggerProvider implementation.
  final APILoggerProvider _delegate;

  /// The resource associated with this provider.
  Resource? resource;

  @override
  bool get isShutdown => _delegate.isShutdown;

  @override
  set isShutdown(bool value) {
    _delegate.isShutdown = value;
  }

  /// Private constructor for creating LoggerProvider instances.
  ///
  /// @param delegate The API LoggerProvider implementation to delegate to
  /// @param resource Optional Resource describing the entity producing telemetry
  LoggerProvider._({
    required APILoggerProvider delegate,
    this.resource,
  }) : _delegate = delegate {
    if (OTelLog.isDebug()) {
      OTelLog.debug('LoggerProvider: Created with resource: $resource');
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
          'LoggerProvider: Shutting down with ${_logRecordProcessors.length} processors');
    }

    if (!isShutdown) {
      // Shutdown all log record processors
      for (final processor in _logRecordProcessors) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LoggerProvider: Shutting down processor ${processor.runtimeType}');
        }
        try {
          await processor.shutdown();
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'LoggerProvider: Successfully shut down processor ${processor.runtimeType}');
          }
        } catch (e) {
          if (OTelLog.isDebug()) {
            OTelLog.debug(
                'LoggerProvider: Error shutting down processor ${processor.runtimeType}: $e');
          }
        }
      }

      // Clear cached loggers
      _loggers.clear();
      if (OTelLog.isDebug()) {
        OTelLog.debug('LoggerProvider: Cleared cached loggers');
      }

      try {
        await _delegate.shutdown();
        if (OTelLog.isDebug()) {
          OTelLog.debug('LoggerProvider: Delegate shutdown complete');
        }
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug('LoggerProvider: Error during delegate shutdown: $e');
        }
      }

      isShutdown = true;
      if (OTelLog.isDebug()) OTelLog.debug('LoggerProvider: Shutdown complete');
    } else {
      if (OTelLog.isDebug()) OTelLog.debug('LoggerProvider: Already shut down');
    }
    return isShutdown;
  }

  @override
  Logger getLogger(
    String name, {
    String? version,
    String? schemaUrl,
    Attributes? attributes,
  }) {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'LoggerProvider: Getting logger with name: $name, version: $version, schemaUrl: $schemaUrl');
    }
    if (isShutdown) {
      throw StateError('LoggerProvider has been shut down');
    }

    // Ensure resource is set before creating logger
    ensureResourceIsSet();

    final key = '$name:${version ?? ''}';
    return _loggers.putIfAbsent(
      key,
      () => SDKLoggerCreate.create(
        delegate: _delegate.getLogger(
          name,
          version: version,
          schemaUrl: schemaUrl,
          attributes: attributes,
        ),
        provider: this,
      ),
    );
  }

  /// Adds a log record processor to this provider.
  ///
  /// Log record processors are notified when log records are emitted and are
  /// responsible for additional processing of logs, such as exporting them.
  ///
  /// @param processor The log record processor to add
  void addLogRecordProcessor(LogRecordProcessor processor) {
    if (isShutdown) {
      throw StateError('LoggerProvider has been shut down');
    }
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'LoggerProvider: Adding log record processor of type ${processor.runtimeType}');
    }
    _logRecordProcessors.add(processor);
  }

  /// Gets all registered log record processors.
  ///
  /// @return An unmodifiable list of all log record processors
  List<LogRecordProcessor> get logRecordProcessors =>
      List.unmodifiable(_logRecordProcessors);

  /// Ensures the resource for this provider is properly set.
  ///
  /// If no resource has been set, the default resource will be used.
  void ensureResourceIsSet() {
    if (resource == null) {
      resource = OTel.defaultResource;
      if (OTelLog.isDebug()) {
        OTelLog.debug('LoggerProvider: Setting resource from default');
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

  /// Forces all log record processors to flush any queued log records.
  ///
  /// This method is useful for ensuring that all log records are exported
  /// before the application terminates or when immediate visibility
  /// of logs is required.
  ///
  /// @return A Future that completes when all processors have been flushed
  Future<void> forceFlush() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'LoggerProvider: Force flushing ${_logRecordProcessors.length} processors');
    }

    if (isShutdown) {
      if (OTelLog.isDebug()) {
        OTelLog.debug(
            'LoggerProvider: Cannot force flush - provider is shut down');
      }
      return;
    }

    for (var processor in _logRecordProcessors) {
      try {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LoggerProvider: Flushing processor ${processor.runtimeType}');
        }
        await processor.forceFlush();
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LoggerProvider: Successfully flushed processor ${processor.runtimeType}');
        }
      } catch (e) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LoggerProvider: Error flushing processor ${processor.runtimeType}: $e');
        }
      }
    }

    if (OTelLog.isDebug()) {
      OTelLog.debug('LoggerProvider: Force flush complete');
    }
  }
}
