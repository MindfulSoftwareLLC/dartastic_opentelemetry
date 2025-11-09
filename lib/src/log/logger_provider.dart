import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../otel.dart';
import '../resource/resource.dart';
import 'logger.dart';

part 'logger_provider_create.dart';

/// SDK implementation of the APILoggerProvider interface.
///
/// The LoggerProvider is the entry point to the logger API. It is responsible
/// for creating and managing Loggers.
///
/// This implementation delegates some functionality to the API LoggerProvider
/// implementation while adding SDK-specific behaviors.
///
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#loggerprovider
class LoggerProvider implements APILoggerProvider {
  /// Registry of loggers managed by this provider.
  final Map<String, Logger> _loggers = {};

  final APILoggerProvider _delegate;

  // TODO: LogsProcessor type
  final List<dynamic> _logProcessors = [];

  /// The resource associated with this provider.
  Resource? resource;

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
  bool get isShutdown => _delegate.isShutdown;

  @override
  set isShutdown(bool value) {
    _delegate.isShutdown = value;
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

  @override
  APILogger getLogger(String name,
      {String? version, String? schemaUrl, Attributes? attributes}) {
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

  @override
  Future<bool> shutdown() async {
    if (OTelLog.isDebug()) {
      OTelLog.debug(
          'LoggerProvider: Shutting down with ${_logProcessors.length} processors');
    }

    if (!isShutdown) {
      // Shutdown all log processors
      for (final processor in _logProcessors) {
        if (OTelLog.isDebug()) {
          OTelLog.debug(
              'LoggerProvider: Shutting down processor ${processor.runtimeType}');
        }
        try {
          // TODO: processor shutdown here.
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

  /// Ensures the resource for this provider is properly set.
  ///
  /// If no resource has been set, the default resource will be used.
  void ensureResourceIsSet() {
    if (resource != null) return;
    resource = OTel.defaultResource;
    if (!OTelLog.isDebug()) return;
    OTelLog.debug('LoggerProvider: Setting resource from default');

    // By right, this should already set based on [OTel.defaultResource]. In case if default is null,
    // ignore next operations.
    if (resource != null) return;
    OTelLog.debug('Resource attributes:');
    resource!.attributes.toList().forEach((attr) {
      if (attr.key == 'tenant_id' || attr.key == 'service.name') {
        OTelLog.debug('  ${attr.key}: ${attr.value}');
      }
    });
  }
}
