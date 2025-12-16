// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:fixnum/fixnum.dart';

import '../../dartastic_opentelemetry.dart';

part 'logger_create.dart';

/// SDK implementation of the APILogger interface.
///
/// The Logger is responsible for emitting log records. It holds a reference
/// to the LoggerProvider to access resource, processors, and other configuration.
///
/// This implementation delegates some functionality to the API Logger
/// implementation while adding SDK-specific behaviors like processor notification.
///
/// More information:
/// https://opentelemetry.io/docs/specs/otel/logs/sdk/#logger
class Logger implements APILogger {
  /// The underlying API Logger implementation.
  final APILogger _delegate;

  /// The LoggerProvider that created this logger.
  final LoggerProvider _provider;

  /// Private constructor for creating Logger instances.
  ///
  /// @param delegate The API Logger implementation to delegate to
  /// @param provider The LoggerProvider that created this logger
  Logger._({
    required APILogger delegate,
    required LoggerProvider provider,
  })  : _delegate = delegate,
        _provider = provider {
    if (OTelLog.isDebug()) {
      OTelLog.debug('Logger: Created with name: ${delegate.name}');
    }
  }

  /// Gets the LoggerProvider that created this logger.
  LoggerProvider get provider => _provider;

  /// Gets the resource associated with this logger.
  Resource? get resource => _provider.resource;

  @override
  String get name => _delegate.name;

  @override
  String? get version => _delegate.version;

  @override
  String? get schemaUrl => _delegate.schemaUrl;

  @override
  Attributes? get attributes => _delegate.attributes;

  @override
  bool get enabled {
    // Check if provider is enabled
    if (!_provider.enabled || _provider.isShutdown) {
      return false;
    }

    // Check if any processors are registered
    if (_provider.logRecordProcessors.isEmpty) {
      return false;
    }

    // Check if all processors return false for enabled
    final allDisabled = _provider.logRecordProcessors.every(
      (processor) => !processor.enabled(
        instrumentationScope: OTel.instrumentationScope(
          name: name,
          version: version ?? '1.0.0',
          schemaUrl: schemaUrl,
          attributes: attributes,
        ),
      ),
    );

    return !allDisabled;
  }

  @override
  void emit({
    DateTime? timeStamp,
    DateTime? observedTimestamp,
    Context? context,
    Severity? severityNumber,
    String? severityText,
    dynamic body,
    Attributes? attributes,
    String? eventName,
  }) {
    if (!enabled) {
      if (OTelLog.isDebug()) {
        OTelLog.debug('Logger: emit called but logger is disabled');
      }
      return;
    }

    // Convert DateTime to nanoseconds since Unix epoch (Int64)
    final timestampNanos = timeStamp != null
        ? Int64(timeStamp.microsecondsSinceEpoch) * Int64(1000)
        : null;

    // Set observed timestamp to now if not provided
    final observedNanos = observedTimestamp != null
        ? Int64(observedTimestamp.microsecondsSinceEpoch) * Int64(1000)
        : Int64(DateTime.now().microsecondsSinceEpoch) * Int64(1000);

    // Use current context if not provided
    final effectiveContext = context ?? Context.current;

    // Create the instrumentation scope
    final instrumentationScope = OTel.instrumentationScope(
      name: name,
      version: version ?? '1.0.0',
      schemaUrl: schemaUrl,
      attributes: this.attributes,
    );

    // Create the log record
    final logRecord = SDKLogRecord(
      instrumentationScope: instrumentationScope,
      resource: _provider.resource,
      timestamp: timestampNanos,
      observedTimestamp: observedNanos,
      context: effectiveContext,
      severityNumber: severityNumber,
      severityText: severityText,
      body: body,
      attributes: attributes,
      eventName: eventName,
    );

    if (OTelLog.isDebug()) {
      OTelLog.debug('Logger: Emitting log record: $logRecord');
    }

    // Notify all processors
    for (final processor in _provider.logRecordProcessors) {
      try {
        processor.onEmit(logRecord, effectiveContext);
      } catch (e) {
        if (OTelLog.isError()) {
          OTelLog.error(
              'Logger: Error in processor ${processor.runtimeType}: $e');
        }
      }
    }
  }

  /// Emits a log record with TRACE severity.
  ///
  /// @param body The log message body
  /// @param attributes Optional attributes
  /// @param eventName Optional event name
  void trace(dynamic body, {Attributes? attributes, String? eventName}) {
    emit(
      severityNumber: Severity.TRACE,
      severityText: 'TRACE',
      body: body,
      attributes: attributes,
      eventName: eventName,
    );
  }

  /// Emits a log record with DEBUG severity.
  ///
  /// @param body The log message body
  /// @param attributes Optional attributes
  /// @param eventName Optional event name
  void debug(dynamic body, {Attributes? attributes, String? eventName}) {
    emit(
      severityNumber: Severity.DEBUG,
      severityText: 'DEBUG',
      body: body,
      attributes: attributes,
      eventName: eventName,
    );
  }

  /// Emits a log record with INFO severity.
  ///
  /// @param body The log message body
  /// @param attributes Optional attributes
  /// @param eventName Optional event name
  void info(dynamic body, {Attributes? attributes, String? eventName}) {
    emit(
      severityNumber: Severity.INFO,
      severityText: 'INFO',
      body: body,
      attributes: attributes,
      eventName: eventName,
    );
  }

  /// Emits a log record with WARN severity.
  ///
  /// @param body The log message body
  /// @param attributes Optional attributes
  /// @param eventName Optional event name
  void warn(dynamic body, {Attributes? attributes, String? eventName}) {
    emit(
      severityNumber: Severity.WARN,
      severityText: 'WARN',
      body: body,
      attributes: attributes,
      eventName: eventName,
    );
  }

  /// Emits a log record with ERROR severity.
  ///
  /// @param body The log message body
  /// @param attributes Optional attributes
  /// @param eventName Optional event name
  void error(dynamic body, {Attributes? attributes, String? eventName}) {
    emit(
      severityNumber: Severity.ERROR,
      severityText: 'ERROR',
      body: body,
      attributes: attributes,
      eventName: eventName,
    );
  }

  /// Emits a log record with FATAL severity.
  ///
  /// @param body The log message body
  /// @param attributes Optional attributes
  /// @param eventName Optional event name
  void fatal(dynamic body, {Attributes? attributes, String? eventName}) {
    emit(
      severityNumber: Severity.FATAL,
      severityText: 'FATAL',
      body: body,
      attributes: attributes,
      eventName: eventName,
    );
  }
}
