// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'resource.dart';

/// Factory class for creating Resource instances.
///
/// This class follows the factory pattern and provides a static method
/// for creating new Resource instances.
class ResourceCreate<T> {
  /// Creates a new Resource with the specified attributes and schema URL.
  ///
  /// This factory method is the recommended way to create Resource instances.
  ///
  /// @param attributes The attributes describing the resource
  /// @param schemaUrl Optional schema URL for the resource attributes
  /// @return A new Resource instance
  static Resource create(Attributes attributes, [String? schemaUrl]) {
    return Resource._(attributes, schemaUrl);
  }
}
