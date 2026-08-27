// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// In-process OTelEnv coverage via EnvironmentService.testOverrides.
// The pre-existing env tests spawn subprocesses (Platform.environment
// is unmodifiable), which exercises the code but is invisible to
// coverage collection; these tests drive the same parsing branches
// in-process.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

void main() {
  late LogLevel savedLevel;
  late LogFunction? savedLogFn;

  void env(Map<String, String> vars) {
    EnvironmentService.testOverrides = vars;
  }

  setUp(() {
    savedLevel = OTelLog.currentLevel;
    savedLogFn = OTelLog.logFunction;
  });

  tearDown(() {
    EnvironmentService.testOverrides = null;
    OTelLog.currentLevel = savedLevel;
    OTelLog.logFunction = savedLogFn;
    OTelLog.metricLogFunction = null;
    OTelLog.spanLogFunction = null;
    OTelLog.exportLogFunction = null;
  });

  group('initializeLogging', () {
    test('sets each recognized OTEL_LOG_LEVEL', () {
      final expectations = {
        'trace': OTelLog.isTrace,
        'debug': OTelLog.isDebug,
        'info': OTelLog.isInfo,
        'warn': OTelLog.isWarn,
        'error': OTelLog.isError,
        'fatal': OTelLog.isFatal,
      };
      expectations.forEach((level, probe) {
        OTelLog.logFunction = print; // not custom -> env may configure
        env({'OTEL_LOG_LEVEL': level});
        OTelEnv.initializeLogging();
        expect(probe(), isTrue, reason: 'level $level should enable itself');
      });
    });

    test('unrecognized OTEL_LOG_LEVEL leaves logging unchanged', () {
      OTelLog.logFunction = print;
      OTelLog.currentLevel = LogLevel.error;
      env({'OTEL_LOG_LEVEL': 'chatty'});
      OTelEnv.initializeLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.error));
    });

    test('a custom log function is preserved', () {
      final captured = <String>[];
      OTelLog.logFunction = captured.add;
      OTelLog.currentLevel = LogLevel.error;
      env({'OTEL_LOG_LEVEL': 'trace'});
      OTelEnv.initializeLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.error));
      expect(OTelLog.logFunction, equals(captured.add));
    });

    test('OTEL_DART_LOG_* enable per-signal sinks when unset', () {
      env({
        'OTEL_DART_LOG_METRICS': 'true',
        'OTEL_DART_LOG_SPANS': 'true',
        'OTEL_DART_LOG_EXPORT': 'true',
      });
      OTelEnv.initializeLogging();
      expect(OTelLog.metricLogFunction, isNotNull);
      expect(OTelLog.spanLogFunction, isNotNull);
      expect(OTelLog.exportLogFunction, isNotNull);
    });

    test('OTEL_DART_LOG_* preserve custom per-signal sinks', () {
      final captured = <String>[];
      OTelLog.spanLogFunction = captured.add;
      env({'OTEL_DART_LOG_SPANS': 'true'});
      OTelEnv.initializeLogging();
      expect(OTelLog.spanLogFunction, equals(captured.add));
    });
  });

  group('getOtlpConfig', () {
    for (final signal in ['traces', 'metrics', 'logs']) {
      final sig = signal.toUpperCase();
      test('signal-specific values win for $signal', () {
        env({
          'OTEL_EXPORTER_OTLP_${sig}_ENDPOINT': 'http://specific:4318',
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://generic:4318',
          'OTEL_EXPORTER_OTLP_${sig}_PROTOCOL': 'http/protobuf',
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_${sig}_HEADERS': 'a=1,b=2',
          'OTEL_EXPORTER_OTLP_${sig}_INSECURE': 'true',
          'OTEL_EXPORTER_OTLP_${sig}_TIMEOUT': '2500',
          'OTEL_EXPORTER_OTLP_${sig}_COMPRESSION': 'gzip',
          'OTEL_EXPORTER_OTLP_${sig}_CERTIFICATE': '/certs/ca.pem',
          'OTEL_EXPORTER_OTLP_${sig}_CLIENT_KEY': '/certs/client.key',
          'OTEL_EXPORTER_OTLP_${sig}_CLIENT_CERTIFICATE': '/certs/client.pem',
        });
        final config = OTelEnv.getOtlpConfig(signal: signal);
        expect(config.endpoint, equals('http://specific:4318'));
        expect(config.protocol, equals('http/protobuf'));
        expect(config.headers, equals({'a': '1', 'b': '2'}));
        expect(config.insecure, isTrue);
        expect(config.timeout, equals(const Duration(milliseconds: 2500)));
        expect(config.compression, equals('gzip'));
        expect(config.certificate, equals('/certs/ca.pem'));
        expect(config.clientKey, equals('/certs/client.key'));
        expect(config.clientCertificate, equals('/certs/client.pem'));
      });

      test('generic values are the fallback for $signal', () {
        env({
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://generic:4318',
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_HEADERS': 'k=v',
        });
        final config = OTelEnv.getOtlpConfig(signal: signal);
        expect(config.endpoint, equals('http://generic:4318'));
        expect(config.protocol, equals('grpc'));
        expect(config.headers, equals({'k': 'v'}));
      });
    }

    test('invalid timeout is dropped', () {
      env({'OTEL_EXPORTER_OTLP_TIMEOUT': 'soon'});
      expect(OTelEnv.getOtlpConfig().timeout, isNull);
    });

    test('invalid insecure value is treated as false', () {
      env({'OTEL_EXPORTER_OTLP_TRACES_INSECURE': 'sorta'});
      expect(OTelEnv.getOtlpConfig().insecure, isFalse);
    });

    test('insecure treats non-true spellings as false', () {
      for (final falsy in ['0', 'false', 'no', 'off', '1', 'yes', 'on']) {
        env({'OTEL_EXPORTER_OTLP_TRACES_INSECURE': falsy});
        expect(OTelEnv.getOtlpConfig().insecure, isFalse,
            reason: '"$falsy" should read as false');
      }
    });

    test(
        'header values keep embedded equals signs; malformed pairs are'
        ' skipped', () {
      final captured = <String>[];
      OTelLog.logFunction = captured.add;
      OTelLog.currentLevel = LogLevel.debug;
      env({
        'OTEL_EXPORTER_OTLP_HEADERS':
            'authorization=Basic dTpwlg==,plain=v,noequals,=nokey,novalue=',
      });
      final config = OTelEnv.getOtlpConfig();
      expect(
          config.headers,
          equals({
            'authorization': 'Basic dTpwlg==',
            'plain': 'v',
          }));
      expect(captured.join('\n'), contains('[REDACTED'),
          reason: 'authorization value must not be logged');
    });
  });

  group('service and resource', () {
    test(
        'service config from resource attributes with OTEL_SERVICE_NAME'
        ' precedence', () {
      env({
        'OTEL_RESOURCE_ATTRIBUTES':
            'service.name=from-resource,service.version=2.1,other=x',
        'OTEL_SERVICE_NAME': 'from-env',
      });
      final config = OTelEnv.getServiceConfig();
      expect(config.serviceName, equals('from-env'));
      expect(config.serviceVersion, equals('2.1'));
    });

    test('service config skips malformed resource pairs', () {
      final config = OTelEnv.getServiceConfig();
      expect(config.serviceName, isNull);
      expect(config.serviceVersion, isNull);
    });

    test('resource attributes parse all values as string', () {
      env({
        'OTEL_RESOURCE_ATTRIBUTES':
            'count=7,ratio=0.5,on=true,off=FALSE,name=svc,malformed',
      });
      final attrs = OTelEnv.getResourceAttributes();
      expect(attrs['count'], equals('7'));
      expect(attrs['ratio'], equals('0.5'));
      expect(attrs['on'], equals('true'));
      expect(attrs['off'], equals('FALSE'));
      expect(attrs['name'], equals('svc'));
      expect(attrs.containsKey('malformed'), isFalse);
    });

    test('semicolons work as comma stand-ins (--define compatibility)', () {
      env({'OTEL_RESOURCE_ATTRIBUTES': 'a=1;b=2'});
      final attrs = OTelEnv.getResourceAttributes();
      expect(attrs, equals({'a': '1', 'b': '2'}));
    });
  });

  group('sdk flags and exporters', () {
    test('isSdkDisabled only accepts true spelling', () {
      for (final truthy in ['true', 'TRUE', 'True']) {
        env({'OTEL_SDK_DISABLED': truthy});
        expect(OTelEnv.isSdkDisabled(), isTrue, reason: '"$truthy"');
      }
      for (final falsy in ['1', 'YES', 'on', 'false', '0']) {
        env({'OTEL_SDK_DISABLED': falsy});
        expect(OTelEnv.isSdkDisabled(), isFalse, reason: '"$falsy"');
      }
      env({});
      expect(OTelEnv.isSdkDisabled(), isFalse);
    });

    test('getExporter reads each signal and rejects unknown signals', () {
      env({
        'OTEL_TRACES_EXPORTER': 'otlp',
        'OTEL_METRICS_EXPORTER': 'console',
        'OTEL_LOGS_EXPORTER': 'none',
      });
      expect(OTelEnv.getExporter(), equals('otlp'));
      expect(OTelEnv.getExporter(signal: 'metrics'), equals('console'));
      expect(OTelEnv.getExporter(signal: 'logs'), equals('none'));
      expect(OTelEnv.getExporter(signal: 'bogus'), isNull);
    });

    test('getExporters normalizes, dedupes, and nulls out empties', () {
      env({'OTEL_TRACES_EXPORTER': ' OTLP , console ,otlp,, '});
      expect(OTelEnv.getExporters(), equals(['otlp', 'console']));
      env({'OTEL_TRACES_EXPORTER': ' ,, '});
      expect(OTelEnv.getExporters(), isNull);
      env({});
      expect(OTelEnv.getExporters(), isNull);
    });

    test('getPropagators defaults, normalizes, and honors semicolons', () {
      env({});
      expect(OTelEnv.getPropagators(), equals(['tracecontext', 'baggage']));
      env({'OTEL_PROPAGATORS': '  '});
      expect(OTelEnv.getPropagators(), equals(['tracecontext', 'baggage']));
      env({'OTEL_PROPAGATORS': ' B3 , tracecontext ,, '});
      expect(OTelEnv.getPropagators(), equals(['b3', 'tracecontext']));
      env({'OTEL_PROPAGATORS': 'tracecontext;baggage'});
      expect(OTelEnv.getPropagators(), equals(['tracecontext', 'baggage']));
    });
  });

  group('processor and limit configs', () {
    test('getBspConfig parses valid values', () {
      env({
        'OTEL_BSP_SCHEDULE_DELAY': '1000',
        'OTEL_BSP_EXPORT_TIMEOUT': '2000',
        'OTEL_BSP_MAX_QUEUE_SIZE': '512',
        'OTEL_BSP_MAX_EXPORT_BATCH_SIZE': '128',
      });
      final config = OTelEnv.getBspConfig();
      expect(config.scheduleDelay, equals(const Duration(seconds: 1)));
      expect(config.exportTimeout, equals(const Duration(seconds: 2)));
      expect(config.maxQueueSize, equals(512));
      expect(config.maxExportBatchSize, equals(128));
    });

    test('getBspConfig warns and drops invalid values', () {
      final captured = <String>[];
      OTelLog.logFunction = captured.add;
      OTelLog.currentLevel = LogLevel.warn;
      env({
        'OTEL_BSP_SCHEDULE_DELAY': 'soon',
        'OTEL_BSP_EXPORT_TIMEOUT': 'later',
        'OTEL_BSP_MAX_QUEUE_SIZE': 'big',
        'OTEL_BSP_MAX_EXPORT_BATCH_SIZE': 'huge',
      });
      final config = OTelEnv.getBspConfig();
      expect(config.scheduleDelay, isNull);
      expect(config.exportTimeout, isNull);
      expect(config.maxQueueSize, isNull);
      expect(config.maxExportBatchSize, isNull);
      expect(captured.join('\n'), contains('OTEL_BSP_SCHEDULE_DELAY'));
      expect(captured.join('\n'), contains('OTEL_BSP_MAX_EXPORT_BATCH_SIZE'));
    });

    test('getBlrpConfig parses valid values and drops invalid ones', () {
      env({
        'OTEL_BLRP_SCHEDULE_DELAY': '750',
        'OTEL_BLRP_EXPORT_TIMEOUT': '1500',
        'OTEL_BLRP_MAX_QUEUE_SIZE': '256',
        'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': '64',
      });
      final config = OTelEnv.getBlrpConfig();
      expect(config.scheduleDelay, equals(const Duration(milliseconds: 750)));
      expect(config.exportTimeout, equals(const Duration(milliseconds: 1500)));
      expect(config.maxQueueSize, equals(256));
      expect(config.maxExportBatchSize, equals(64));

      env({
        'OTEL_BLRP_SCHEDULE_DELAY': 'x',
        'OTEL_BLRP_EXPORT_TIMEOUT': 'x',
        'OTEL_BLRP_MAX_QUEUE_SIZE': 'x',
        'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': 'x',
      });
      final invalid = OTelEnv.getBlrpConfig();
      expect(invalid.scheduleDelay, isNull);
      expect(invalid.exportTimeout, isNull);
      expect(invalid.maxQueueSize, isNull);
      expect(invalid.maxExportBatchSize, isNull);
    });

    test('getAttributeLimits parses valid values and drops invalid ones', () {
      env({
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '4096',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': '128',
      });
      final config = OTelEnv.getAttributeLimits();
      expect(config.attributeValueLengthLimit, equals(4096));
      expect(config.attributeCountLimit, equals(128));

      env({
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '-10',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': 'invalid',
      });
      final invalid = OTelEnv.getAttributeLimits();
      expect(invalid.attributeValueLengthLimit, isNull);
      expect(invalid.attributeCountLimit, isNull);
    });

    test('getLogRecordLimits parses valid values and drops invalid ones', () {
      env({
        'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': '900',
        'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': '64',
      });
      final config = OTelEnv.getLogRecordLimits();
      expect(config.attributeValueLengthLimit, equals(900));
      expect(config.attributeCountLimit, equals(64));

      env({
        'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': 'long',
        'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': '-5',
      });
      final invalid = OTelEnv.getLogRecordLimits();
      expect(invalid.attributeValueLengthLimit, isNull);
      expect(invalid.attributeCountLimit, isNull);
    });

    test('getLogRecordLimits falls back to general attribute limits', () {
      env({
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '256',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': '32',
      });
      final fallback = OTelEnv.getLogRecordLimits();
      expect(fallback.attributeValueLengthLimit, equals(256));
      expect(fallback.attributeCountLimit, equals(32));
    });
  });

  group('invalid limit values warn', () {
    // The spec requires an invalid environment value to be reported, not
    // silently ignored: "the SDK MUST ... log a warning" and fall back to
    // the default. Dropping the value is only half the contract; these
    // pin the other half, including that the warning names the variable
    // the value actually came from.
    late List<String> logs;

    void captureWarnings() {
      logs = <String>[];
      OTelLog.logFunction = logs.add;
      OTelLog.currentLevel = LogLevel.warn;
    }

    test('getAttributeLimits warns for each invalid value', () {
      captureWarnings();
      env({
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '-10',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': 'invalid',
      });

      final config = OTelEnv.getAttributeLimits();

      expect(config.attributeValueLengthLimit, isNull);
      expect(config.attributeCountLimit, isNull);
      expect(
        logs.where((l) =>
            l.contains('for OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT.') &&
            l.contains('"-10"')),
        hasLength(1),
        reason: 'a negative limit must be reported, naming the variable '
            'and the offending value',
      );
      expect(
        logs.where((l) =>
            l.contains('for OTEL_ATTRIBUTE_COUNT_LIMIT.') &&
            l.contains('"invalid"')),
        hasLength(1),
        reason: 'a non-numeric limit must be reported the same way',
      );
    });

    test('getLogRecordLimits warns for each invalid value', () {
      captureWarnings();
      env({
        'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': 'long',
        'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': '-5',
      });

      final config = OTelEnv.getLogRecordLimits();

      expect(config.attributeValueLengthLimit, isNull);
      expect(config.attributeCountLimit, isNull);
      expect(
        logs.where((l) =>
            l.contains('for OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT.')),
        hasLength(1),
      );
      expect(
        logs.where(
            (l) => l.contains('for OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT.')),
        hasLength(1),
      );
    });

    test('the warning names the general variable when it is the fallback', () {
      captureWarnings();
      // The signal-specific variable is unset, so the invalid value came
      // from the general one - the warning has to say so, or the reader
      // goes looking for a variable they never set.
      env({'OTEL_ATTRIBUTE_COUNT_LIMIT': 'nope'});

      final config = OTelEnv.getLogRecordLimits();

      expect(config.attributeCountLimit, isNull);
      expect(
        logs.where((l) => l.contains('for OTEL_ATTRIBUTE_COUNT_LIMIT.')),
        hasLength(1),
      );
      expect(
        logs.where((l) => l.contains('OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT')),
        isEmpty,
        reason: 'the unset signal-specific variable must not be blamed',
      );
    });

    test('valid limits warn about nothing', () {
      captureWarnings();
      env({
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '4096',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': '128',
      });

      final config = OTelEnv.getAttributeLimits();

      expect(config.attributeValueLengthLimit, equals(4096));
      expect(config.attributeCountLimit, equals(128));
      expect(logs, isEmpty);
    });

    test('zero is a valid limit and is not warned about', () {
      captureWarnings();
      // Zero is meaningful: it drops every attribute. Only negatives and
      // non-numerics are invalid.
      env({'OTEL_ATTRIBUTE_COUNT_LIMIT': '0'});

      final config = OTelEnv.getAttributeLimits();

      expect(config.attributeCountLimit, equals(0));
      expect(logs, isEmpty);
    });
  });

  group('parsing empty values (issue #213)', () {
    test('an empty value reads as unset from getValue', () {
      env({'OTEL_SERVICE_NAME': ''});
      expect(EnvironmentService.instance.getValue('OTEL_SERVICE_NAME'), isNull);
    });

    test('an empty endpoint reads as unset', () {
      env({'OTEL_EXPORTER_OTLP_ENDPOINT': ''});
      expect(OTelEnv.getOtlpConfig().endpoint, isNull);
    });

    test('an empty signal endpoint falls back to the generic endpoint', () {
      env({
        'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://collector:4318',
        'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': '',
      });
      expect(
        OTelEnv.getOtlpConfig(signal: 'traces').endpoint,
        equals('http://collector:4318'),
      );
    });

    test('an empty protocol reads as unset', () {
      env({'OTEL_EXPORTER_OTLP_PROTOCOL': ''});
      expect(OTelEnv.getOtlpConfig().protocol, isNull);
    });

    test('an empty service name does not override resource attributes', () {
      env({
        'OTEL_SERVICE_NAME': '',
        'OTEL_RESOURCE_ATTRIBUTES': 'service.name=my-service',
      });
      expect(OTelEnv.getServiceConfig().serviceName, equals('my-service'));
    });

    test('an empty log level leaves logging unchanged', () {
      OTelLog.enableDebugLogging();
      env({'OTEL_LOG_LEVEL': ''});
      OTelEnv.initializeLogging();
      expect(OTelLog.currentLevel, equals(LogLevel.debug));
    });
  });
}
