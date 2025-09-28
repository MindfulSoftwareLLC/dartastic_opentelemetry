// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Utility functions for creating test attributes
class TestAttributes {
  /// Create a map of test attributes
  static Map<String, Object> createTestAttributeMap({int count = 10}) {
    return {
      for (var i = 0; i < count; i++)
        'key$i': i % 4 == 0
            ? 'value$i'
            : i % 4 == 1
                ? i
                : i % 4 == 2
                    ? i.toDouble()
                    : i % 2 == 0
    };
  }

  /// Create test attributes
  static Attributes createTestAttributes({int count = 10}) {
    return createTestAttributeMap(count: count).toAttributes();
  }
}
