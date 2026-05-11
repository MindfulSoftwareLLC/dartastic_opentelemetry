// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

/// Late-binding proxy implementations of [LoggerProvider] and [OTelLogger].
///
/// See `lib/src/trace/late_binding_tracer.dart` for the full design
/// rationale; this file applies the same pattern to the logs signal
/// so a captured `OTel.logger()` or `OTel.loggerProvider()` reference
/// survives a later `OTel.initialize`.
library;

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import '../otel.dart';
import '../resource/resource.dart';
import 'log_record_processor.dart';
import 'logger.dart';
import 'logger_provider.dart';

/// A [LoggerProvider] proxy that re-resolves its underlying SDK
/// LoggerProvider on every call. Identity is stable across
/// `OTel.initialize`.
class LateBindingLoggerProvider implements LoggerProvider {
  /// Internal: do not construct directly. Use `OTel.loggerProvider()`.
  LateBindingLoggerProvider();

  LoggerProvider _real() => OTel.internalResolveRealLoggerProvider();

  @override
  OTelLogger getLogger(
    String name, {
    String? version,
    String? schemaUrl,
    Attributes? attributes,
  }) {
    // Forward to the real provider for its side effects: shutdown
    // guard (throws StateError on a shut-down provider), debug
    // logging, and priming of its internal Logger cache.
    _real().getLogger(
      name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: attributes,
    );
    return OTel.internalGetCachedLateBindingLogger(
      name: name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: attributes,
    );
  }

  @override
  Resource? get resource => _real().resource;
  @override
  set resource(Resource? value) => _real().resource = value;

  @override
  String get endpoint => _real().endpoint;
  @override
  set endpoint(String value) => _real().endpoint = value;

  @override
  String get serviceName => _real().serviceName;
  @override
  set serviceName(String value) => _real().serviceName = value;

  @override
  String? get serviceVersion => _real().serviceVersion;
  @override
  set serviceVersion(String? value) => _real().serviceVersion = value;

  @override
  bool get enabled => _real().enabled;
  @override
  set enabled(bool value) => _real().enabled = value;

  @override
  bool get isShutdown => _real().isShutdown;
  @override
  set isShutdown(bool value) => _real().isShutdown = value;

  @override
  Future<bool> shutdown() => _real().shutdown();

  @override
  Future<void> forceFlush() => _real().forceFlush();

  @override
  void addLogRecordProcessor(LogRecordProcessor processor) =>
      _real().addLogRecordProcessor(processor);

  @override
  List<LogRecordProcessor> get logRecordProcessors =>
      _real().logRecordProcessors;

  @override
  void ensureResourceIsSet() => _real().ensureResourceIsSet();
}

/// An [OTelLogger] proxy that re-resolves its underlying SDK logger on
/// every call. See [LateBindingLoggerProvider] for design rationale.
class LateBindingLogger implements OTelLogger {
  @override
  final String name;
  @override
  final String? version;
  @override
  final String? schemaUrl;
  @override
  final Attributes? attributes;

  /// Internal: do not construct directly. Use `OTel.logger()`.
  LateBindingLogger({
    required this.name,
    this.version,
    this.schemaUrl,
    this.attributes,
  });

  OTelLogger _real() {
    final provider = OTel.internalResolveRealLoggerProvider();
    return provider.getLogger(
      name,
      version: version,
      schemaUrl: schemaUrl,
      attributes: attributes,
    );
  }

  @override
  LoggerProvider get provider => OTel.loggerProvider();

  @override
  Resource? get resource => _real().resource;

  @override
  bool get enabled => _real().enabled;

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
  }) =>
      _real().emit(
        timeStamp: timeStamp,
        observedTimestamp: observedTimestamp,
        context: context,
        severityNumber: severityNumber,
        severityText: severityText,
        body: body,
        attributes: attributes,
        eventName: eventName,
      );

  @override
  void trace(dynamic body, {Attributes? attributes, String? eventName}) =>
      _real().trace(body, attributes: attributes, eventName: eventName);

  @override
  void debug(dynamic body, {Attributes? attributes, String? eventName}) =>
      _real().debug(body, attributes: attributes, eventName: eventName);

  @override
  void info(dynamic body, {Attributes? attributes, String? eventName}) =>
      _real().info(body, attributes: attributes, eventName: eventName);

  @override
  void warn(dynamic body, {Attributes? attributes, String? eventName}) =>
      _real().warn(body, attributes: attributes, eventName: eventName);

  @override
  void error(dynamic body, {Attributes? attributes, String? eventName}) =>
      _real().error(body, attributes: attributes, eventName: eventName);

  @override
  void fatal(dynamic body, {Attributes? attributes, String? eventName}) =>
      _real().fatal(body, attributes: attributes, eventName: eventName);
}
