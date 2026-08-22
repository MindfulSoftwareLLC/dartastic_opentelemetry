// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Implementation file for web platforms
// This file won't be directly imported on non-web platforms
import 'dart:js_interop';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'resource.dart';
import 'resource_detector.dart';

// JS interop extension for accessing window.navigator
@JS('window.navigator')
external NavigatorJS get _navigator;

@JS()
@staticInterop
class NavigatorJS {}

extension NavigatorJSExtension on NavigatorJS {
  @JS('language')
  external String? get language;

  @JS('platform')
  external String? get platform;

  @JS('userAgent')
  external String? get userAgent;

  @JS('vendor')
  external String? get vendor;

  @JS('languages')
  external JSArray<JSString>? get languages;
}

/// Matches the user agents of mobile browsers. Computed in Dart — a `@JS`
/// annotation names a global binding path, never a function body (#190).
final _mobileUserAgent = RegExp(
  r'Mobile|Android|iPhone|iPad|iPod|Windows Phone',
  caseSensitive: false,
);

/// Detects browser and web-specific resource information.
///
/// This detector populates resource attributes with information about the
/// browser environment, such as language, platform, user agent, and whether
/// the browser is running on a mobile device.
///
/// This implementation is only used in web environments. In non-web environments,
/// a stub implementation is used instead.
///
/// Semantic conventions:
/// https://opentelemetry.io/docs/specs/semconv/resource/browser/
class WebResourceDetector implements ResourceDetector {
  @override
  Future<Resource> detect() async {
    if (OTelFactory.otelFactory == null) {
      throw StateError('OTel initialize must be called first.');
    }

    // Use JS interop to safely get navigator properties
    final attributes = <String, Object>{};

    try {
      final nav = _navigator;
      final userAgent = nav.userAgent ?? '';
      attributes['browser.language'] = nav.language ?? '';
      attributes['browser.platform'] = nav.platform ?? '';
      // `user_agent.original` is the current OTel semconv key; the
      // older `browser.user_agent` was removed from the browser
      // namespace in favor of this top-level key.
      attributes[UserAgent.userAgentOriginal.key] = userAgent;
      attributes['browser.vendor'] = nav.vendor ?? '';
      attributes['browser.mobile'] =
          _mobileUserAgent.hasMatch(userAgent) ? 'true' : 'false';
      attributes['browser.languages'] =
          nav.languages?.toDart.map((l) => l.toDart).join(',') ?? '';
    } catch (e) {
      // Omit what could not be read rather than emitting blank values —
      // a populated-but-empty resource hides the failure (#190).
      if (OTelLog.isError()) OTelLog.error('Error detecting web resources: $e');
    }

    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap(attributes),
    );
  }
}
