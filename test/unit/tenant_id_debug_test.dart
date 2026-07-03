import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:test/test.dart';

// Regression: tenant_id must land on the resource regardless of log level.
// The old initialize() wrapped the tenant final-check (incl. the fallback
// merge) in `if (OTelLog.isDebug())`, so with debug OFF (production) tenant_id
// could be dropped — a heisenbug that "works" only when debugging.
void main() {
  setUp(() => OTelLog.currentLevel = LogLevel.info); // debug OFF (default)
  tearDown(() async {
    await OTel.reset();
    OTelLog.currentLevel = LogLevel.info;
  });

  Future<String?> tenantAfterInit() async {
    await OTel.initialize(
      endpoint: 'http://localhost:4318',
      serviceName: 'svc',
      serviceVersion: '1.0.0',
      tenantId: 'acme',
    );
    return OTel.defaultResource?.attributes.getString('tenant_id');
  }

  test('tenant_id lands on the resource with debug OFF (prod)', () async {
    OTelLog.currentLevel = LogLevel.info;
    expect(await tenantAfterInit(), 'acme');
  });

  test('tenant_id lands on the resource with debug ON', () async {
    OTelLog.currentLevel = LogLevel.debug;
    expect(await tenantAfterInit(), 'acme');
  });
}
