import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../resource/resource.dart';
import 'logger_provider.dart';

part 'logger_create.dart';

/// SDK implementation of the APILogger interface.
///
/// A Logger is responsible for creating and managing logs.
///
/// This implementation delegates some functionality to the API Logger
/// implementation while adding SDK-specific.
///
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/
class Logger implements APILogger {
  final LoggerProvider _provider;
  final APILogger _delegate;

  bool _enabled = true;

  /// Private constructor for creating Logger instances.
  Logger._({
    required LoggerProvider provider,
    required APILogger delegate,
  })  : _provider = provider,
        _delegate = delegate;

  @override
  String get name => _delegate.name;

  @override
  String? get schemaUrl => _delegate.schemaUrl;

  @override
  String? get version => _delegate.version;

  @override
  Attributes? get attributes => _delegate.attributes;

  @override
  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
  }

  /// Gets the provider that created this logger.
  LoggerProvider get provider => _provider;

  /// Gets the resource associated with this logger's provider.
  Resource? get resource => _provider.resource;

  @override
  void emit({
    Attributes? attributes,
    Context? context,
    body,
    DateTime? observedTimestamp,
    Severity? severityNumber,
    String? severityText,
    DateTime? timeStamp,
  }) {
    // TODO: implement emit
  }
}
