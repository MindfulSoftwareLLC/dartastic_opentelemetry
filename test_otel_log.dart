import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

void main() {
  print('=== Initial State ===');
  print('logFunction is print: ${OTelLog.logFunction == print}');
  print('logFunction == null: ${OTelLog.logFunction == null}');
  print('currentLevel: ${OTelLog.currentLevel}');
  print('isDebug(): ${OTelLog.isDebug()}');

  print('\n=== After setup ===');
  final messages = <String>[];
  OTelLog.logFunction = messages.add;
  OTelLog.enableTraceLogging();

  print('logFunction is messages.add: ${OTelLog.logFunction == messages.add}');
  print('currentLevel: ${OTelLog.currentLevel}');
  print('isDebug(): ${OTelLog.isDebug()}');

  print('\n=== Calling debug ===');
  OTelLog.debug('Test debug message');

  print('Captured ${messages.length} messages');
  if (messages.isNotEmpty) {
    print('First message: "${messages[0]}"');
  }
}
