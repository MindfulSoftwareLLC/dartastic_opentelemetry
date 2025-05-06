// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry/src/otel.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Custom exception for baggage-related errors
class BaggageException implements Exception {
  final String message;
  final Map<String, dynamic> context;

  BaggageException(this.message, {this.context = const {}});

  @override
  String toString() => 'BaggageException: $message\nContext: $context';
}

/// Example service using baggage
class UserPreferenceService {
  /// Get user preferences safely with error handling
  Map<String, String> getUserPreferences() {
    try {
      final baggage = Context.current.baggage;
      if (baggage == null) {
        throw StateError('Baggage expected but non-existent.');
      }
      // Validate required baggage entries exist
      final userId = _getRequiredBaggageValue(baggage, 'user.id');
      final region = _getRequiredBaggageValue(baggage, 'user.region');

      // Optional preferences with defaults
      final language = _getOptionalBaggageValue(
        baggage,
        'user.language',
        defaultValue: 'en-US',
      );
      final theme = _getOptionalBaggageValue(
        baggage,
        'user.theme',
        defaultValue: 'light',
      );
      return {
        'userId': userId,
        'region': region,
        'language': language,
        'theme': theme,
      };
    } on BaggageException catch (e) {
      // Log the error with full context
      print('Failed to get user preferences: $e');

      // Provide sensible defaults
      return {
        'language': 'en-US',
        'theme': 'light',
      };
    }
  }

  /// Safely get a required baggage value
  String _getRequiredBaggageValue(Baggage baggage, String key) {
    final entry = baggage.getEntry(key);
    if (entry == null) {
      throw BaggageException(
        'Missing required baggage entry: $key',
        context: {'availableKeys': baggage.getAllEntries().keys.toList()},
      );
    }
    return entry.value;
  }

  /// Safely get an optional baggage value with a default
  String _getOptionalBaggageValue(
    Baggage baggage,
    String key, {
    required String defaultValue,
  }) {
    return baggage.getEntry(key)?.value ?? defaultValue;
  }
}

/// Example showing validation of baggage values
class ConfigurationService {
  static const _validEnvironments = {'dev', 'staging', 'prod'};
  static const _validLogLevels = {'debug', 'info', 'warn', 'error'};

  /// Validate and process configuration from baggage
  void applyConfiguration() {
    try {
      final baggage = Context.currentWithBaggage().baggage;

      // Validate environment
      final env = baggage!.getEntry('service.environment')?.value;
      if (env != null && !_validEnvironments.contains(env)) {
        throw BaggageException(
          'Invalid environment value',
          context: {
            'value': env,
            'validValues': _validEnvironments,
          },
        );
      }

      // Validate log level
      final logLevel = baggage.getEntry('service.log_level')?.value;
      if (logLevel != null && !_validLogLevels.contains(logLevel)) {
        throw BaggageException(
          'Invalid log level',
          context: {
            'value': logLevel,
            'validValues': _validLogLevels,
          },
        );
      }

      // Apply configuration...
    } on BaggageException catch (e) {
      print('Configuration error: $e');
      // Apply default configuration
    }
  }
}

/// Example of safe baggage manipulation
Future<void> safeBaggageExample() async {
  // Start with empty baggage
  final context = OTel.context().withBaggage(OTel.baggage());

  await context.run(() async {
    try {
      // Get current baggage safely
      var baggage = Context.currentWithBaggage().baggage;

      // Add entries with validation
      baggage = _safelyAddBaggageEntry(
        baggage!,
        'request.id',
        'req_123',
        validator: (value) => value.startsWith('req_'),
        errorMessage: 'Invalid request ID format',
      );

      // Update context with validated baggage
      final updatedContext = Context.current.withBaggage(baggage);

      await updatedContext.run(() async {
        final service = UserPreferenceService();
        final prefs = service.getUserPreferences();
        print('User preferences: $prefs');
      });
    } on BaggageException catch (e) {
      print('Safe baggage operation failed: $e');
    }
  });
}

/// Helper for safely adding validated baggage entries
Baggage _safelyAddBaggageEntry(
  Baggage baggage,
  String key,
  String value, {
  required bool Function(String) validator,
  required String errorMessage,
}) {
  // Validate key format
  if (!_isValidBaggageKey(key)) {
    throw BaggageException(
      'Invalid baggage key format',
      context: {'key': key},
    );
  }

  // Validate value
  if (!validator(value)) {
    throw BaggageException(
      errorMessage,
      context: {'key': key, 'value': value},
    );
  }

  // Add metadata about validation
  return baggage.copyWith(
    key,
    value,
    'validated=${DateTime.now().toIso8601String()}',
  );
}

/// Validate baggage key format
bool _isValidBaggageKey(String key) {
  // Keys should be lowercase, use dots for namespacing,
  // and contain only alphanumeric characters plus dots and underscores
  return RegExp(r'^[a-z][a-z0-9_\.]*[a-z0-9]$').hasMatch(key);
}

Future<void> main() async {
  // Example with missing required value
  final invalidContext = OTel.context()
      .withBaggage(OTel.baggage().copyWith('user.language', 'fr-FR')
          // Note: missing required user.id
          );

  await invalidContext.run(() async {
    final service = UserPreferenceService();
    final prefs = service.getUserPreferences();
    print('Preferences with missing required value: $prefs');
  });

  // Example with invalid value
  final invalidValueContext = OTel.context().withBaggage(
      OTel.baggage().copyWith('service.environment', 'invalid_env'));

  await invalidValueContext.run(() async {
    final service = ConfigurationService();
    service.applyConfiguration();
  });

  // Example with proper error handling
  await safeBaggageExample();
}

/// Error handling best practices:
///
/// 1. Validation
///    - Validate keys follow naming convention
///    - Validate required values exist
///    - Validate value formats
///    - Use enums or sets for valid values
///
/// 2. Error Context
///    - Include available information in errors
///    - Add metadata about validation
///    - Include timestamps for debugging
///
/// 3. Recovery
///    - Provide sensible defaults
///    - Log errors with context
///    - Consider error impact scope
///
/// 4. Helper Methods
///    - Create reusable validation methods
///    - Centralize error handling logic
///    - Make validation rules configurable
///
/// 5. Testing
///    - Test missing values
///    - Test invalid values
///    - Test recovery behavior
