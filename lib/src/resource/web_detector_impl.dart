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
/// repeated here. This one has no registry equivalent, so it is declared
/// rather than written as a literal at the call site.
///
/// NOTE for a follow-up, deliberately not changed in a bug fix: it
/// occupies the official `browser.*` namespace without being in the
/// registry, and it should be an array rather than a comma-joined
/// string, per the naming rule that an attribute representing multiple
/// entities "SHOULD be pluralized and the value type SHOULD be an
/// array". Both are wire changes and belong in their own PR.
///
/// `browser.vendor` used to sit alongside this and has been dropped:
/// `navigator.vendor` is a frozen legacy API returning a hardcoded
/// vendor string, and `browser.brands` is the registry's structured
/// answer to the same question.
enum _BrowserExtra implements OTelSemantic {
  /// All languages the user accepts, comma-joined. `browser.language`
  /// (registry) carries only the preferred one.
  browserLanguages('browser.languages');

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
/// The user agent alone is not enough, and no amount of UA parsing can
/// fix that. Since iPadOS 13 an iPad requests desktop sites by default
/// and reports a `Macintosh; Intel Mac OS X` user agent, so the `iPad`
/// alternative above never matches and every iPad reads as non-mobile.
///
/// There is no version or silicon hint to fall back on. Apple froze the
/// macOS platform token, so EVERY Mac — Apple Silicon included — also
/// reports `Intel Mac OS X`, pinned at `10_15_7` (Catalina) indefinitely;
/// Safari and Chrome both do this deliberately, because introducing an
/// `arm64` token would break UA sniffing across the web. An iPad in
/// desktop mode is reusing that already-frozen Mac string, so the two are
/// indistinguishable by user agent BY DESIGN. Do not "simplify" this back
/// into a UA-only test.
///
/// `maxTouchPoints` is the only signal left: a Mac reports 0 (a trackpad
/// is not a touch point) and iPadOS reports 5. Requiring both keeps each
/// direction honest — a UA-spoofing desktop with no touchscreen stays
/// desktop, and a touch-capable Windows laptop counts as mobile only if
/// its UA says so too.
///
/// KNOWN DEVIATION from semconv, tracked for follow-up rather than
/// decided here: the registry says this value "is intended to be taken
/// from the UA client hints API (`navigator.userAgentData.mobile`). If
/// unavailable, this attribute SHOULD be left unset." UA Client Hints is
/// Chromium-only — Safari does not implement `navigator.userAgentData` at
/// all — so strict conformance would leave `browser.mobile` unset for
/// every WebKit and Gecko user. We derive it instead. That trade-off
/// belongs upstream, not in a silent local choice.
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
      // `navigator.platform` — the legacy source the registry sanctions
      // when UA Client Hints is unavailable. Note it reports `MacIntel`
      // for an iPad in desktop mode, for the same frozen-token reason
      // described on [isMobileBrowser]: misleading, but conformant, and
      // unlike `browser.mobile` we cannot correct it without departing
      // from the spec.
      attributes[Browser.browserPlatform.key] = nav.platform ?? '';
      // `user_agent.original` is the current OTel semconv key; the
      // older `browser.user_agent` was removed from the browser
      // namespace in favor of this top-level key.
      attributes[UserAgent.userAgentOriginal.key] = userAgent;
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
