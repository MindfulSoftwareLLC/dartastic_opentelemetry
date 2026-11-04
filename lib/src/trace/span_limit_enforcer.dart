// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:meta/meta.dart';

import '../otel.dart';
import '../util/attribute_limiter.dart';
import 'span_limits.dart';

/// Enforces limits on span attributes, events, and links and tracks dropped counts.
///
/// Each recording span owns an instance of [SpanLimitEnforcer], initialized
/// with a snapshot of [SpanLimits] at span creation time.
@internal
class SpanLimitEnforcer {
  /// The debug message logged when an attribute is truncated, discarded, or
  /// replaced due to a limit.
  ///
  /// Note: The OpenTelemetry specification requires logging discards and
  /// truncations, but does not prescribe the exact log message text.
  static const String discardLogMessage =
      'Attribute was truncated, discarded, or replaced due to a limit.';

  /// The immutable snapshot of limits applied to this span.
  final SpanLimits spanLimits;

  /// Limiter for span attributes.
  final AttributeLimiter spanAttributeLimiter;

  /// Limiter for event attributes.
  final AttributeLimiter eventAttributeLimiter;

  /// Limiter for link attributes.
  final AttributeLimiter linkAttributeLimiter;

  final Set<String> _spanAttributeKeys = {};

  int _droppedAttributesCount = 0;
  int _droppedEventsCount = 0;
  int _droppedLinksCount = 0;
  int _eventCount = 0;
  int _linkCount = 0;

  final Map<SpanEvent, int> _droppedAttributesPerEvent = {};
  final Map<SpanLink, int> _droppedAttributesPerLink = {};

  bool _loggedSpanDiscard = false;

  /// Creates a new [SpanLimitEnforcer] configured with [spanLimits].
  SpanLimitEnforcer(this.spanLimits)
      : spanAttributeLimiter = AttributeLimiter(
          countLimit: spanLimits.attributeCountLimit,
          valueLengthLimit: spanLimits.attributeValueLengthLimit,
        ),
        eventAttributeLimiter = AttributeLimiter(
          countLimit: spanLimits.attributePerEventCountLimit,
          valueLengthLimit: spanLimits.attributeValueLengthLimit,
        ),
        linkAttributeLimiter = AttributeLimiter(
          countLimit: spanLimits.attributePerLinkCountLimit,
          valueLengthLimit: spanLimits.attributeValueLengthLimit,
        );

  /// Number of attributes dropped on the span.
  int get droppedAttributesCount => _droppedAttributesCount;

  /// Number of events dropped on the span.
  int get droppedEventsCount => _droppedEventsCount;

  /// Number of links dropped on the span.
  int get droppedLinksCount => _droppedLinksCount;

  /// Number of dropped attributes for [event].
  int droppedAttributesCountForEvent(SpanEvent event) =>
      _droppedAttributesPerEvent[event] ?? 0;

  /// Number of dropped attributes for [link].
  int droppedAttributesCountForLink(SpanLink link) =>
      _droppedAttributesPerLink[link] ?? 0;

  /// Emits the debug log for the span record, at most once.
  void logSpanDiscard() {
    if (!_loggedSpanDiscard) {
      _loggedSpanDiscard = true;
      if (OTelLog.isDebug()) {
        OTelLog.debug(discardLogMessage);
      }
    }
  }

  /// Processes creation-time span attributes.
  Attributes? processCreationAttributes(Attributes? attributes) {
    if (attributes == null) return null;
    final result = spanAttributeLimiter.limitAttributes(attributes);
    _droppedAttributesCount += result.droppedCount;
    if (result.hadDiscardOrTruncation) {
      logSpanDiscard();
    }
    final limitedAttrs = result.attributes;
    if (limitedAttrs != null) {
      for (final attr in limitedAttrs.toList()) {
        _spanAttributeKeys.add(attr.key);
      }
    }
    return limitedAttrs;
  }

  /// Processes creation-time links.
  List<SpanLink>? processCreationLinks(List<SpanLink>? links) {
    if (links == null) return null;

    final keptLinks = <SpanLink>[];
    for (final link in links) {
      if (keptLinks.length >= spanLimits.linkCountLimit) {
        _droppedLinksCount++;
        logSpanDiscard();
        continue;
      }

      if (link.attributes.isEmpty) {
        keptLinks.add(link);
        continue;
      }

      final attrResult = linkAttributeLimiter.limitAttributes(link.attributes);
      if (attrResult.hadDiscardOrTruncation) {
        logSpanDiscard();
        final limitedLink = OTel.spanLink(
          link.spanContext,
          attributes: attrResult.attributes,
        );
        if (attrResult.droppedCount > 0) {
          _droppedAttributesPerLink[limitedLink] = attrResult.droppedCount;
        }
        keptLinks.add(limitedLink);
      } else {
        keptLinks.add(link);
      }
    }
    _linkCount = keptLinks.length;
    return keptLinks;
  }

  /// Processes creation-time events.
  List<SpanEvent>? processCreationEvents(List<SpanEvent>? events) {
    if (events == null) return null;

    final keptEvents = <SpanEvent>[];
    for (final event in events) {
      if (event.name.isEmpty) {
        continue;
      }
      if (keptEvents.length >= spanLimits.eventCountLimit) {
        _droppedEventsCount++;
        logSpanDiscard();
        continue;
      }

      if (event.attributes == null) {
        keptEvents.add(event);
        continue;
      }

      final attrResult =
          eventAttributeLimiter.limitAttributes(event.attributes);
      if (attrResult.hadDiscardOrTruncation) {
        logSpanDiscard();
        final limitedEvent = OTel.spanEvent(
          event.name,
          attrResult.attributes,
          event.timestamp,
        );
        if (attrResult.droppedCount > 0) {
          _droppedAttributesPerEvent[limitedEvent] = attrResult.droppedCount;
        }
        keptEvents.add(limitedEvent);
      } else {
        keptEvents.add(event);
      }
    }
    _eventCount = keptEvents.length;
    return keptEvents;
  }

  /// Evaluates and limits a single span attribute.
  ///
  /// Returns the limited value to set on the span, or `null` if dropped.
  Object? evaluateSpanAttribute(String key, Object value) {
    if (key.isEmpty) return value;

    final isExisting = _spanAttributeKeys.contains(key);

    if (!isExisting &&
        _spanAttributeKeys.length >= spanLimits.attributeCountLimit) {
      _droppedAttributesCount++;
      logSpanDiscard();
      return null;
    }

    final limited = spanAttributeLimiter.limitValue(value);
    if (AttributeLimiter.wasValueTruncated(value, limited)) {
      logSpanDiscard();
    }

    _spanAttributeKeys.add(key);
    return limited;
  }

  /// Processes replacing all span attributes via setter.
  Attributes replaceSpanAttributes(Attributes newAttributes) {
    _spanAttributeKeys.clear();
    final result = spanAttributeLimiter.limitAttributes(newAttributes);
    _droppedAttributesCount += result.droppedCount;
    if (result.hadDiscardOrTruncation) {
      logSpanDiscard();
      for (final attr in result.attributes!.toList()) {
        _spanAttributeKeys.add(attr.key);
      }
      return result.attributes!;
    } else {
      for (final attr in newAttributes.toList()) {
        _spanAttributeKeys.add(attr.key);
      }
      return newAttributes;
    }
  }

  /// Processes adding multiple span attributes via [addAttributes].
  Attributes addSpanAttributes(Attributes attributes) {
    var anyModified = false;
    final keptMap = <String, Object>{};
    for (final attr in attributes.toList()) {
      final limited = evaluateSpanAttribute(attr.key, attr.value);
      if (limited != null) {
        keptMap[attr.key] = limited;
        if (!identical(limited, attr.value) && limited != attr.value) {
          anyModified = true;
        }
      } else {
        anyModified = true;
      }
    }
    if (!anyModified && keptMap.length == attributes.length) {
      return attributes;
    }
    return OTel.attributesFromMap(keptMap);
  }

  /// Processes adding a span event. Returns the limited event, or `null` if dropped.
  SpanEvent? processAddEvent(SpanEvent spanEvent) {
    if (spanEvent.name.isEmpty) {
      return null;
    }
    if (_eventCount >= spanLimits.eventCountLimit) {
      _droppedEventsCount++;
      logSpanDiscard();
      return null;
    }
    _eventCount++;

    if (spanEvent.attributes == null) {
      return spanEvent;
    }

    final attrResult =
        eventAttributeLimiter.limitAttributes(spanEvent.attributes);

    if (attrResult.hadDiscardOrTruncation) {
      logSpanDiscard();
      final limitedEvent = OTel.spanEvent(
        spanEvent.name,
        attrResult.attributes,
        spanEvent.timestamp,
      );
      if (attrResult.droppedCount > 0) {
        _droppedAttributesPerEvent[limitedEvent] = attrResult.droppedCount;
      }
      return limitedEvent;
    }

    return spanEvent;
  }

  /// Processes adding a span link. Returns the limited link, or `null` if dropped.
  SpanLink? processAddLink(SpanLink spanLink) {
    if (_linkCount >= spanLimits.linkCountLimit) {
      _droppedLinksCount++;
      logSpanDiscard();
      return null;
    }
    _linkCount++;

    if (spanLink.attributes.isEmpty) {
      return spanLink;
    }

    final attrResult =
        linkAttributeLimiter.limitAttributes(spanLink.attributes);

    if (attrResult.hadDiscardOrTruncation) {
      logSpanDiscard();
      final limitedLink = OTel.spanLink(
        spanLink.spanContext,
        attributes: attrResult.attributes,
      );
      if (attrResult.droppedCount > 0) {
        _droppedAttributesPerLink[limitedLink] = attrResult.droppedCount;
      }
      return limitedLink;
    }

    return spanLink;
  }
}
