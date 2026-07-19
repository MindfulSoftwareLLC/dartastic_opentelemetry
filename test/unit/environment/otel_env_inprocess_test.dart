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
        'OTEL_DART_LOG_SPANS': '1',
        'OTEL_DART_LOG_EXPORT': 'yes',
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
        expect(config['endpoint'], equals('http://specific:4318'));
        expect(config['protocol'], equals('http/protobuf'));
        expect(config['headers'], equals({'a': '1', 'b': '2'}));
        expect(config['insecure'], isTrue);
        expect(config['timeout'], equals(const Duration(milliseconds: 2500)));
        expect(config['compression'], equals('gzip'));
        expect(config['certificate'], equals('/certs/ca.pem'));
        expect(config['clientKey'], equals('/certs/client.key'));
        expect(config['clientCertificate'], equals('/certs/client.pem'));
      });

      test('generic values are the fallback for $signal', () {
        env({
          'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://generic:4318',
          'OTEL_EXPORTER_OTLP_PROTOCOL': 'grpc',
          'OTEL_EXPORTER_OTLP_HEADERS': 'k=v',
        });
        final config = OTelEnv.getOtlpConfig(signal: signal);
        expect(config['endpoint'], equals('http://generic:4318'));
        expect(config['protocol'], equals('grpc'));
        expect(config['headers'], equals({'k': 'v'}));
      });
    }

    test('invalid timeout is dropped', () {
      env({'OTEL_EXPORTER_OTLP_TIMEOUT': 'soon'});
      expect(OTelEnv.getOtlpConfig().containsKey('timeout'), isFalse);
    });

    test('invalid insecure value is dropped', () {
      env({'OTEL_EXPORTER_OTLP_TRACES_INSECURE': 'sorta'});
      expect(OTelEnv.getOtlpConfig().containsKey('insecure'), isFalse);
    });

    test('insecure accepts the documented false spellings', () {
      for (final falsy in ['0', 'false', 'no', 'off']) {
        env({'OTEL_EXPORTER_OTLP_TRACES_INSECURE': falsy});
        expect(OTelEnv.getOtlpConfig()['insecure'], isFalse,
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
          config['headers'],
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
      expect(config['serviceName'], equals('from-env'));
      expect(config['serviceVersion'], equals('2.1'));
    });

    test('service config skips malformed resource pairs', () {
      env({'OTEL_RESOURCE_ATTRIBUTES': 'noequals,=nokey,novalue=,'});
      expect(OTelEnv.getServiceConfig(), isEmpty);
    });

    test('resource attributes parse int, double, bool, and string', () {
      env({
        'OTEL_RESOURCE_ATTRIBUTES':
            'count=7,ratio=0.5,on=true,off=FALSE,name=svc,malformed',
      });
      final attrs = OTelEnv.getResourceAttributes();
      expect(attrs['count'], equals(7));
      expect(attrs['ratio'], equals(0.5));
      expect(attrs['on'], isTrue);
      expect(attrs['off'], isFalse);
      expect(attrs['name'], equals('svc'));
      expect(attrs.containsKey('malformed'), isFalse);
    });

    test('semicolons work as comma stand-ins (--define compatibility)', () {
      env({'OTEL_RESOURCE_ATTRIBUTES': 'a=1;b=2'});
      final attrs = OTelEnv.getResourceAttributes();
      expect(attrs, equals({'a': 1, 'b': 2}));
    });
  });

  group('sdk flags and exporters', () {
    test('isSdkDisabled truthy spellings', () {
      for (final truthy in ['1', 'true', 'YES', 'on']) {
        env({'OTEL_SDK_DISABLED': truthy});
        expect(OTelEnv.isSdkDisabled(), isTrue, reason: '"$truthy"');
      }
      env({'OTEL_SDK_DISABLED': 'false'});
      expect(OTelEnv.isSdkDisabled(), isFalse);
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
      expect(config['scheduleDelay'], equals(const Duration(seconds: 1)));
      expect(config['exportTimeout'], equals(const Duration(seconds: 2)));
      expect(config['maxQueueSize'], equals(512));
      expect(config['maxExportBatchSize'], equals(128));
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
      expect(OTelEnv.getBspConfig(), isEmpty);
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
      expect(
          config['scheduleDelay'], equals(const Duration(milliseconds: 750)));
      expect(
          config['exportTimeout'], equals(const Duration(milliseconds: 1500)));
      expect(config['maxQueueSize'], equals(256));
      expect(config['maxExportBatchSize'], equals(64));

      env({
        'OTEL_BLRP_SCHEDULE_DELAY': 'x',
        'OTEL_BLRP_EXPORT_TIMEOUT': 'x',
        'OTEL_BLRP_MAX_QUEUE_SIZE': 'x',
        'OTEL_BLRP_MAX_EXPORT_BATCH_SIZE': 'x',
      });
      expect(OTelEnv.getBlrpConfig(), isEmpty);
    });

    test('getLogRecordLimits parses valid values and drops invalid ones', () {
      env({
        'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': '900',
        'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': '64',
      });
      final config = OTelEnv.getLogRecordLimits();
      expect(config['attributeValueLengthLimit'], equals(900));
      expect(config['attributeCountLimit'], equals(64));

      env({
        'OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT': 'long',
        'OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT': 'many',
      });
      expect(OTelEnv.getLogRecordLimits(), isEmpty);
    });
  });
}
