import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

void main() {
  test('Basic initialization works', () async {
    // Simple test to see if basic initialization works
    await OTel.initialize(
      serviceName: 'test-service',
      serviceVersion: '1.0.0',
    );
    
    expect(OTel.defaultResource, isNotNull);
    
    final attrs = OTel.defaultResource!.attributes.toList();
    final serviceName = attrs.firstWhere((a) => a.key == 'service.name');
    expect(serviceName.value, equals('test-service'));
    
    await OTel.reset();
  });
}
