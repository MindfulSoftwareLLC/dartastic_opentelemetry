// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'resource.dart';

class ResourceCreate<T> {
  static Resource create(Attributes attributes, [String? schemaUrl]) {
    return Resource._(attributes, schemaUrl);
  }
}
