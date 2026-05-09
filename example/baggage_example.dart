// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Example-only baggage keys for things not in the OTel semantic
/// conventions. For any key that *is* in the conventions, use the API
/// enum instead (e.g. `DeploymentResource.deploymentEnvironmentName`
/// for `deployment.environment.name`). Rename this in your own code
/// (e.g. `CheckoutBaggage`) so the names reflect your domain.
enum ExampleBaggage implements OTelSemantic {
  customerId('customer.id'),
  userRegion('user.region'),
  serverId('server.id'),
  transactionId('transaction.id'),
  requestOrigin('request.origin'),
  deploymentRegion('deployment.region'),
  userTenant('user.tenant');

  @override
  final String key;

  @override
  String toString() => key;

  const ExampleBaggage(this.key);
}

Future<void> main() async {
  await OTel.initialize(
    serviceName: 'my-service',
    serviceVersion: '1.0.0',
  );

  // Optionally initialize tracer provider with a BaggageSpanProcessor
  final tracerProvider = OTel.tracerProvider();
  // Make baggage automatically appear in span attributes
  tracerProvider.addSpanProcessor(const BaggageSpanProcessor());

  final baggage = OTel.baggage({
    ExampleBaggage.customerId.key:
        OTel.baggageEntry('123', 'source=mobile app'),
  });

  // Since baggage is immutable, each operation returns a new instance.
  // Chain operations to build up the baggage you need. Use typed enum
  // keys (ExampleBaggage above, or DeploymentResource for the standard
  // OTel-semconv keys) instead of raw strings.
  final enrichedBaggage = baggage
      .copyWith(DeploymentResource.deploymentEnvironmentName.key, 'staging')
      .copyWith(ExampleBaggage.userRegion.key, 'us-west', 'source=user profile')
      .copyWith(SessionViewSemantics.sessionId.key, 'session-123');

  // Baggage is always associated with a Context.
  // This allows it to automatically propagate through your application.
  final context = OTel.context().withBaggage(enrichedBaggage);

  // Run your code within the context to have access to the baggage.
  await context.run(() async {
    // You can always access the current baggage from the current context.
    // If no baggage exists, you get an empty baggage (never null).
    final currentBaggage = Context.currentWithBaggage().baggage;

    // Baggage entries can be accessed individually.
    print(
      'Current customer ID: ${currentBaggage!.getEntry(ExampleBaggage.customerId.key)?.value}',
    );

    // Or you can get all entries at once
    // Best practice: Check getAllEntries when debugging propagation issues
    print('All baggage entries:');
    currentBaggage.getAllEntries().forEach((key, entry) {
      if (entry.metadata != null) {
        print('  $key: ${entry.value} (${entry.metadata})');
      } else {
        print('  $key: ${entry.value}');
      }
    });

    // Baggage can cross isolate boundaries automatically
    // The context system handles serialization/deserialization
    final topCurrent = Context.current;
    await topCurrent.runIsolate(() async {
      //Now context.current is a new current but baggage propagates
      final isolateContext = Context.currentWithBaggage();
      final isolateBaggage = isolateContext.baggage;
      print('\nIn isolate - baggage entries:');
      isolateBaggage!.getAllEntries().forEach((key, entry) {
        if (entry.metadata != null) {
          print('  $key: ${entry.value} (${entry.metadata})');
        } else {
          print('  $key: ${entry.value}');
        }
      });

      // Each isolate can modify its own copy of the baggage.
      // Changes don't affect the parent isolate.
      // Best practice: Document any baggage modifications for debugging.
      final updatedBaggage = isolateBaggage.copyWith(
          ExampleBaggage.serverId.key, 'worker-1')
        ..copyWithout(DeploymentResource.deploymentEnvironmentName.key);

      return isolateContext.withBaggage(updatedBaggage);
    });
  });
}

/// Example showing baggage in distributed tracing scenario
Future<void> distributedTracingExample() async {
  // Baggage is particularly useful in distributed systems
  // It carries context across service boundaries
  final incomingBaggage = OTel.baggage()
      .copyWith(ExampleBaggage.transactionId.key, 'abc123')
      .copyWith(ExampleBaggage.requestOrigin.key, 'mobile-app');

  // Best practice: Always preserve incoming baggage
  // Add to it rather than replacing it
  final context = OTel.context().withBaggage(incomingBaggage);

  await context.run(() async {
    // Each service can add its own entries
    // This helps with debugging and monitoring
    final serviceBaggage = Context.currentWithBaggage()
        .baggage!
        .copyWith(ServiceResource.serviceInstanceId.key, 'backend-01')
        .copyWith(ServiceResource.serviceVersion.key, '2.1.0');

    // Best practice: Update context when baggage changes
    // This ensures proper propagation
    final enhancedContext = Context.current.withBaggage(serviceBaggage);

    await enhancedContext.run(() async {
      // When making outgoing requests, baggage is automatically included
      final currentBaggage = Context.currentWithBaggage().baggage!;

      print('\nOutgoing request baggage:');
      currentBaggage.getAllEntries().forEach((key, entry) {
        print('  $key: ${entry.value}');
      });
    });
  });
}

/// Example showing baggage cardinality best practices
Future<void> monitoringExample() async {
  // Best practice: Start with low-cardinality data
  // These are values that have a small set of possible values
  // Examples: service names, regions, environments
  final baseContext = OTel.context().withBaggage(
    OTel.baggage()
        .copyWith(ServiceResource.serviceName.key, 'payment-processor')
        .copyWith(ExampleBaggage.deploymentRegion.key, 'us-west-2'),
  );

  await baseContext.run(() async {
    // High-cardinality data has many possible values
    // Examples: user IDs, transaction IDs, timestamps
    // Warning: Too much high-cardinality data can impact performance
    final processingBaggage = Context.currentWithBaggage()
        .baggage!
        .copyWith(
          ExampleBaggage.transactionId.key,
          'tx_789012',
        ) // High cardinality: many possible values.
        .copyWith(
          ExampleBaggage.userTenant.key,
          'tenant_456',
        ); // High cardinality: many possible values.

    // Best practice: Scope high-cardinality baggage
    // Only use it where the detailed information is needed
    await Context.current.withBaggage(processingBaggage).run(() async {
      // This code has access to all baggage entries
      // Useful for detailed debugging or error handling
      final debugBaggage = Context.currentWithBaggage().baggage;
      print('\nProcessing transaction with baggage:');
      debugBaggage!.getAllEntries().forEach((key, entry) {
        print('  $key: ${entry.value}');
      });
    });

    // The outer context still has only low-cardinality data
    // This helps keep most operations efficient
    print('\nGeneral operations baggage:');
    Context.currentWithBaggage().baggage!.getAllEntries().forEach((key, entry) {
      print('  $key: ${entry.value}');
    });
  });
}

/// Common baggage usage patterns:
///
/// 1. Request Flow Tracking
///    - Add correlation IDs
///    - Track request origin
///    - Monitor request path through services
///
/// 2. User Context
///    - Add user IDs (carefully - high cardinality)
///    - Include user preferences that affect behavior
///    - Track user session information
///
/// 3. Deployment Information
///    - Service versions
///    - Environment details
///    - Region or zone information
///
/// 4. Feature Flags
///    - A/B test groups
///    - Feature enablement flags
///    - Configuration variations
///
/// 5. Debug Information
///    - Sample rates
///    - Debug flags
///    - Trace level settings
///
/// Best Practices:
///
/// 1. Key Naming
///    - Use dot notation for namespacing (e.g., 'service.name')
///    - Be consistent across services
///    - Document key names and expected values
///
/// 2. Value Management
///    - Keep values reasonably sized
///    - Use string representations
///    - Consider value cardinality
///
/// 3. Cardinality Control
///    - Limit high-cardinality data
///    - Scope detailed baggage to where it's needed
///    - Use sampling for very high cardinality needs
///
/// 4. Metadata Usage
///    - Add metadata to track value sources
///    - Use metadata for value validation
///    - Include timestamp or version information
///
/// 5. Error Handling
///    - Always check entry existence before use
///    - Provide defaults for missing values
///    - Log baggage state in error scenarios
///
/// 6. Performance Considerations
///    - Baggage is propagated with every request
///    - Large baggage impacts network performance
///    - High cardinality affects monitoring systems
