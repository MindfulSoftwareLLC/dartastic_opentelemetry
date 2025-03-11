// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

part of 'span.dart';

/// Internal constructor access for Span
class SDKSpanCreate {
  /// Creates a Span, only accessible within library
  static Span create({
    required APISpan delegateSpan,
    required Tracer sdkTracer
  }) {
    return Span._(delegateSpan, sdkTracer);
  }
}
