// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

// ignore_for_file: public_member_api_docs

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
}

// Pure JS function to safely get languages as string
@JS('function() { '
    'var langs = window.navigator.languages;'
    'return (langs && Array.isArray(langs)) ? langs.join(",") : "";'
    '}')
external String _getLanguagesString();

// Pure JS function to check if mobile
@JS('function() { '
    'return /Mobile|Android|iPhone|iPad|iPod|Windows Phone/i.test(window.navigator.userAgent) ? "true" : "false";'
    '}')
external String _isMobile();

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
      throw 'OTel initialize must be called first.';
    }

    // Use JS interop to safely get navigator properties
    final Map<String, Object> attributes = {};

    try {
      final nav = _navigator;
      attributes['browser.language'] = nav.language ?? '';
      attributes['browser.platform'] = nav.platform ?? '';
      attributes['browser.user_agent'] = nav.userAgent ?? '';
      attributes['browser.vendor'] = nav.vendor ?? '';
      attributes['browser.mobile'] = _isMobile();

      // Get languages using dedicated JS function
      attributes['browser.languages'] = _getLanguagesString();
    } catch (e) {
      if (OTelLog.isError()) OTelLog.error('Error detecting web resources: $e');
      // Provide fallback values to avoid empty attributes
      attributes['browser.language'] = '';
      attributes['browser.platform'] = '';
      attributes['browser.user_agent'] = '';
      attributes['browser.vendor'] = '';
      attributes['browser.mobile'] = 'false';
      attributes['browser.languages'] = '';
    }

    return ResourceCreate.create(OTelFactory.otelFactory!.attributesFromMap(attributes));
  }
}
