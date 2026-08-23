// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

// Implementation file for web platforms
// This file won't be directly imported on non-web platforms
import 'dart:js_interop';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';
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

  @JS('maxTouchPoints')
  external int? get maxTouchPoints;
}

/// Non-registry `browser.*` keys this detector emits.
///
/// The OpenTelemetry attribute registry defines `browser.brands`,
/// `browser.language`, `browser.mobile`, `browser.platform` and
/// `browser.document.url.full` — those come from [Browser] and are not
/// repeated here. These two have no registry equivalent, so they are
/// declared rather than written as literals at the call site.
///
/// NOTE for a follow-up, deliberately not changed in a bug fix: both
/// occupy the official `browser.*` namespace without being in the
/// registry. `browser.vendor` in particular overlaps `browser.brands`,
/// which IS the registry's way of naming the engine vendor. Renaming
/// either is a wire change and belongs in its own PR.
enum _BrowserExtra implements OTelSemantic {
  /// All languages the user accepts, comma-joined. `browser.language`
  /// (registry) carries only the preferred one.
  browserLanguages('browser.languages'),

  /// `navigator.vendor`. No registry equivalent; see the note above.
  browserVendor('browser.vendor');

  @override
  final String key;

  const _BrowserExtra(this.key);

  @override
  String toString() => key;
}

/// Matches the user agents of mobile browsers. Computed in Dart — a `@JS`
/// annotation names a global binding path, never a function body (#190).
final _mobileUserAgent = RegExp(
  r'Mobile|Android|iPhone|iPad|iPod|Windows Phone',
  caseSensitive: false,
);

/// Whether the browser is running on a mobile device.
///
/// The user agent alone is not enough. Since iPadOS 13 an iPad requests
/// desktop sites by default and reports a `Macintosh; Intel Mac OS X`
/// user agent, so the `iPad` alternative above never matches and every
/// iPad would be reported as non-mobile. `maxTouchPoints` is the standard
/// supplement: a desktop Mac reports 0, a touch device reports the number
/// of simultaneous touches it supports.
///
/// Combining them keeps both directions honest — a UA-spoofing desktop
/// browser with no touchscreen stays desktop, and a touch-capable
/// Windows laptop only counts as mobile if its UA says so too.
@visibleForTesting
bool isMobileBrowser(String userAgent, int? maxTouchPoints) =>
    _mobileUserAgent.hasMatch(userAgent) ||
    (userAgent.contains('Macintosh') && (maxTouchPoints ?? 0) > 1);

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
      attributes[Browser.browserLanguage.key] = nav.language ?? '';
      attributes[Browser.browserPlatform.key] = nav.platform ?? '';
      // `user_agent.original` is the current OTel semconv key; the
      // older `browser.user_agent` was removed from the browser
      // namespace in favor of this top-level key.
      attributes[UserAgent.userAgentOriginal.key] = userAgent;
      attributes[_BrowserExtra.browserVendor.key] = nav.vendor ?? '';
      attributes[Browser.browserMobile.key] =
          isMobileBrowser(userAgent, nav.maxTouchPoints) ? 'true' : 'false';
      attributes[_BrowserExtra.browserLanguages.key] =
          nav.languages?.toDart.map((l) => l.toDart).join(',') ?? '';
    } catch (e) {
      // Resource detection is BEST EFFORT and must never interrupt
      // initialization: only `initialize` may throw, and a browser we have
      // never seen is not a reason to take the caller's app down. Whatever
      // was read before the failure is kept; the rest is omitted.
      //
      // Omitted, not blanked — a populated-but-empty resource hides the
      // failure, which is exactly how #190 stayed invisible. Empty strings
      // are dropped at attribute creation, so the `?? ''` fallbacks above
      // produce absent attributes rather than blank ones for the same
      // reason.
      if (OTelLog.isError()) OTelLog.error('Error detecting web resources: $e');
    }

    return ResourceCreate.create(
      OTelFactory.otelFactory!.attributesFromMap(attributes),
    );
  }
}
