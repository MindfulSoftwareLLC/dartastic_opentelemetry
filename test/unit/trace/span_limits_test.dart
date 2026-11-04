// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/trace/span_limit_enforcer.dart';
import 'package:dartastic_opentelemetry/src/util/attribute_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('SpanLimits model', () {
    test('defaults are 128 / null / 128 / 128 / 128 / 128', () {
      final limits = const SpanLimits();
      expect(limits.attributeCountLimit, equals(128));
      expect(limits.attributeValueLengthLimit, isNull);
      expect(limits.eventCountLimit, equals(128));
      expect(limits.linkCountLimit, equals(128));
      expect(limits.attributePerEventCountLimit, equals(128));
      expect(limits.attributePerLinkCountLimit, equals(128));
    });

    test('custom values are retained', () {
      final limits = const SpanLimits(
        attributeCountLimit: 10,
        attributeValueLengthLimit: 20,
        eventCountLimit: 30,
        linkCountLimit: 40,
        attributePerEventCountLimit: 50,
        attributePerLinkCountLimit: 60,
      );
      expect(limits.attributeCountLimit, equals(10));
      expect(limits.attributeValueLengthLimit, equals(20));
      expect(limits.eventCountLimit, equals(30));
      expect(limits.linkCountLimit, equals(40));
      expect(limits.attributePerEventCountLimit, equals(50));
      expect(limits.attributePerLinkCountLimit, equals(60));
    });

    test('asserts reject negative values', () {
      expect(
        () => SpanLimits(attributeCountLimit: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SpanLimits(attributeValueLengthLimit: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SpanLimits(eventCountLimit: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SpanLimits(linkCountLimit: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SpanLimits(attributePerEventCountLimit: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SpanLimits(attributePerLinkCountLimit: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equality and hashCode', () {
      final a = const SpanLimits(
        attributeCountLimit: 10,
        attributeValueLengthLimit: 20,
      );
      final b = const SpanLimits(
        attributeCountLimit: 10,
        attributeValueLengthLimit: 20,
      );
      final c = const SpanLimits(
        attributeCountLimit: 11,
        attributeValueLengthLimit: 20,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString contains all limits', () {
      final limits = const SpanLimits(
        attributeCountLimit: 10,
        attributeValueLengthLimit: 20,
        eventCountLimit: 30,
        linkCountLimit: 40,
        attributePerEventCountLimit: 50,
        attributePerLinkCountLimit: 60,
      );
      final str = limits.toString();
      expect(str, contains('attributeCountLimit: 10'));
      expect(str, contains('attributeValueLengthLimit: 20'));
      expect(str, contains('eventCountLimit: 30'));
      expect(str, contains('linkCountLimit: 40'));
      expect(str, contains('attributePerEventCountLimit: 50'));
      expect(str, contains('attributePerLinkCountLimit: 60'));
    });
  });

  group('AttributeLimiter unit tests', () {
    test('string truncation', () {
      expect(
        AttributeLimiter.truncateString('hello world', 5),
        equals('hello'),
      );
      expect(AttributeLimiter.truncateString('hello', 5), equals('hello'));
      expect(AttributeLimiter.truncateString('hello', null), equals('hello'));
      expect(AttributeLimiter.truncateString('hello', 0), isEmpty);
    });

    test('string list truncation', () {
      final list = ['alpha', 'beta', 'gamma'];
      final truncated = AttributeLimiter.truncateStringList(list, 3);
      expect(truncated, equals(['alp', 'bet', 'gam']));

      expect(AttributeLimiter.truncateStringList(list, null), equals(list));
      expect(
        AttributeLimiter.truncateStringList(list, 0),
        equals(['', '', '']),
      );
    });

    test('surrogate pair truncation does not split surrogate pairs', () {
      // 😀 is '\uD83D\uDE00' (2 UTF-16 code units)
      final str =
          'a😀b'; // 'a' (idx 0), '\uD83D' (idx 1), '\uDE00' (idx 2), 'b' (idx 3)
      // Truncating at limit 2 would cut right after '\uD83D' (the lead surrogate).
      // It must back up to length 1 ('a').
      expect(AttributeLimiter.truncateString(str, 2), equals('a'));
      // Truncating at limit 3 preserves the whole surrogate pair: 'a😀'.
      expect(AttributeLimiter.truncateString(str, 3), equals('a😀'));
    });

    test('string that would truncate to empty is retained as empty', () {
      final emoji = '😀'; // '\uD83D\uDE00'
      // Limit 1 lands on lead surrogate and backs up to an empty string.
      expect(AttributeLimiter.truncateString(emoji, 1), isEmpty);
    });

    test('count limit and updating existing keys', () {
      const limiter = AttributeLimiter(countLimit: 2);
      final initial = OTel.attributesFromMap({'a': 1, 'b': 2});
      final res1 = limiter.limitAttributes(initial);
      expect(res1.attributes!.toList(), hasLength(2));
      expect(res1.droppedCount, equals(0));

      // Adding a 3rd key exceeds limit
      final withThird = OTel.attributesFromMap({'a': 1, 'b': 2, 'c': 3});
      final res2 = limiter.limitAttributes(withThird);
      expect(res2.attributes!.toList(), hasLength(2));
      expect(res2.droppedCount, equals(1));

      // Updating an existing key is allowed at limit
      final updated = OTel.attributesFromMap({'a': 1, 'b': 20});
      final res3 = limiter.limitAttributes(updated);
      expect(res3.attributes!.getInt('b'), equals(20));
      expect(res3.droppedCount, equals(0));
    });

    test('string list truncation keeps element count stable', () {
      // 😀 is '\uD83D\uDE00'
      final list = ['😀', 'hello'];
      final truncated = AttributeLimiter.truncateStringList(list, 1);
      // '😀' at limit 1 cannot split surrogate, truncates to empty string ''
      // 'hello' at limit 1 truncates to 'h'
      // Element count remains 2 (not silently removed!)
      expect(truncated, equals(['', 'h']));
      expect(truncated, hasLength(2));
    });

    test('string list limit 0 retains empty elements', () {
      final list = ['a', 'b'];
      expect(AttributeLimiter.truncateStringList(list, 0), equals(['', '']));
      expect(AttributeLimiter.truncateStringList(<String>[], 0), isEmpty);
    });

    test(
        'returns original Attributes when nothing dropped or truncated and keeps null attributes null',
        () {
      const limiter = AttributeLimiter(countLimit: 10, valueLengthLimit: 20);
      final original = OTel.attributesFromMap({'k': 'v', 'num': 42});
      final res = limiter.limitAttributes(original);
      expect(identical(res.attributes, original), isTrue);
      expect(res.droppedCount, equals(0));
      expect(res.hadDiscardOrTruncation, isFalse);

      final resNull = limiter.limitAttributes(null);
      expect(resNull.attributes, isNull);
      expect(resNull.droppedCount, equals(0));
      expect(resNull.hadDiscardOrTruncation, isFalse);
    });

    test(
        'SpanLimitEnforcer returns original event/link when nothing was dropped or truncated, and keeps null event attributes null',
        () async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-enforcer');
      final enforcer = SpanLimitEnforcer(const SpanLimits());
      final ctx = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );

      // Event with null attributes
      final eventWithNullAttrs = OTel.spanEvent('ev1', null, DateTime.now());
      final processedEvent = enforcer.processAddEvent(eventWithNullAttrs);
      expect(identical(processedEvent, eventWithNullAttrs), isTrue);
      expect(processedEvent!.attributes, isNull);

      // Link with null attributes
      final linkWithNullAttrs = OTel.spanLink(ctx, attributes: null);
      final processedLink = enforcer.processAddLink(linkWithNullAttrs);
      expect(identical(processedLink, linkWithNullAttrs), isTrue);
      expect(identical(processedLink!.attributes, linkWithNullAttrs.attributes),
          isTrue);

      // Event with non-empty attributes that are not truncated
      final attrs = OTel.attributesFromMap({'k': 'v'});
      final eventWithAttrs = OTel.spanEvent('ev2', attrs, DateTime.now());
      final processedEvent2 = enforcer.processAddEvent(eventWithAttrs);
      expect(identical(processedEvent2, eventWithAttrs), isTrue);

      // Link with non-empty attributes that are not truncated
      final linkWithAttrs = OTel.spanLink(ctx, attributes: attrs);
      final processedLink2 = enforcer.processAddLink(linkWithAttrs);
      expect(identical(processedLink2, linkWithAttrs), isTrue);
    });
  });

  group('SpanLimits enforcement on Span: 6 limits', () {
    late TracerProvider provider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
      provider = OTel.tracerProvider();
      tracer = provider.getTracer('test');
    });

    tearDown(() async {
      await OTel.shutdown();
      await provider.shutdown();
    });

    test('attributeCountLimit: at limit, limit+1, and 0', () {
      provider.spanLimits = const SpanLimits(attributeCountLimit: 2);

      // At limit
      final span1 = tracer.startSpan('s1');
      span1.setStringAttribute<String>('k1', 'v1');
      span1.setStringAttribute<String>('k2', 'v2');
      expect(span1.droppedAttributesCount, equals(0));
      expect(span1.attributes.toList(), hasLength(2));

      // Limit + 1
      span1.setStringAttribute<String>('k3', 'v3');
      expect(span1.droppedAttributesCount, equals(1));
      expect(span1.attributes.toList(), hasLength(2));

      // Updating existing key at limit is allowed
      span1.setStringAttribute<String>('k2', 'v2_updated');
      expect(span1.droppedAttributesCount, equals(1));
      expect(span1.attributes.getString('k2'), equals('v2_updated'));

      // Limit 0
      final zeroProvider = OTel.addTracerProvider(
        'zero-provider',
        spanLimits: const SpanLimits(attributeCountLimit: 0),
      );
      final zeroTracer = zeroProvider.getTracer('zero');
      final spanZero = zeroTracer.startSpan('szero');
      spanZero.setStringAttribute<String>('k1', 'v1');
      expect(spanZero.droppedAttributesCount, equals(1));
      expect(spanZero.attributes.toList(), isEmpty);
      zeroProvider.shutdown();
    });

    test('attributeValueLengthLimit: at limit, limit+1, and 0', () {
      provider.spanLimits = const SpanLimits(attributeValueLengthLimit: 5);

      final span = tracer.startSpan('s');
      // At limit
      span.setStringAttribute<String>('exact', '12345');
      expect(span.attributes.getString('exact'), equals('12345'));

      // Limit + 1
      span.setStringAttribute<String>('longer', '123456');
      expect(span.attributes.getString('longer'), equals('12345'));

      // String list elements truncated
      span.setStringListAttribute<String>('list', ['12345', '1234567']);
      expect(span.attributes.getStringList('list'), equals(['12345', '12345']));

      // Limit 0 retains strings as empty values.
      final zeroProvider = OTel.addTracerProvider(
        'zero-val-provider',
        spanLimits: const SpanLimits(attributeValueLengthLimit: 0),
      );
      final zeroTracer = zeroProvider.getTracer('zero');
      final spanZero = zeroTracer.startSpan('szero');
      spanZero.setStringAttribute<String>('str', 'hello');
      expect(spanZero.droppedAttributesCount, equals(0));
      expect(spanZero.attributes.getString('str'), isEmpty);

      // Replacing an existing value with a truncated string updates the value
      // without reporting a drop.
      spanZero.setIntAttribute('existing', 1);
      spanZero.setStringAttribute<String>('existing', 'x');
      expect(spanZero.attributes.getString('existing'), isEmpty);
      expect(spanZero.droppedAttributesCount, equals(0));

      // Non-string attributes unaffected by length limit
      spanZero.setIntAttribute('num', 42);
      expect(spanZero.attributes.getInt('num'), equals(42));
      zeroProvider.shutdown();
    });

    test('eventCountLimit: at limit, limit+1, and 0', () {
      provider.spanLimits = const SpanLimits(eventCountLimit: 2);

      final span = tracer.startSpan('s');
      // At limit
      span.addEventNow('e1');
      span.addEventNow('e2');
      expect(span.droppedEventsCount, equals(0));
      expect(span.spanEvents, hasLength(2));

      // Limit + 1
      span.addEventNow('e3');
      expect(span.droppedEventsCount, equals(1));
      expect(span.spanEvents, hasLength(2));

      // Limit 0
      final zeroProvider = OTel.addTracerProvider(
        'zero-events-provider',
        spanLimits: const SpanLimits(eventCountLimit: 0),
      );
      final zeroTracer = zeroProvider.getTracer('zero');
      final spanZero = zeroTracer.startSpan('szero');
      spanZero.addEventNow('e1');
      expect(spanZero.droppedEventsCount, equals(1));
      expect(spanZero.spanEvents ?? [], isEmpty);
      zeroProvider.shutdown();
    });

    test('linkCountLimit: at limit, limit+1, and 0', () {
      provider.spanLimits = const SpanLimits(linkCountLimit: 2);

      final ctx1 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final ctx2 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556602'),
      );
      final ctx3 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556603'),
      );

      final span = tracer.startSpan('s');
      // At limit
      span.addLink(ctx1);
      span.addLink(ctx2);
      expect(span.droppedLinksCount, equals(0));
      expect(span.spanLinks, hasLength(2));

      // Limit + 1
      span.addLink(ctx3);
      expect(span.droppedLinksCount, equals(1));
      expect(span.spanLinks, hasLength(2));

      // Limit 0
      final zeroProvider = OTel.addTracerProvider(
        'zero-links-provider',
        spanLimits: const SpanLimits(linkCountLimit: 0),
      );
      final zeroTracer = zeroProvider.getTracer('zero');
      final spanZero = zeroTracer.startSpan('szero');
      spanZero.addLink(ctx1);
      expect(spanZero.droppedLinksCount, equals(1));
      expect(spanZero.spanLinks ?? [], isEmpty);
      zeroProvider.shutdown();
    });

    test('attributePerEventCountLimit: at limit, limit+1, and 0', () {
      provider.spanLimits = const SpanLimits(attributePerEventCountLimit: 2);

      final span = tracer.startSpan('s');

      // At limit
      span.addEventNow('e1', OTel.attributesFromMap({'a': 1, 'b': 2}));
      expect(span.spanEvents, hasLength(1));
      expect(
        span.droppedAttributesCountForEvent(span.spanEvents!.first),
        equals(0),
      );
      expect(span.spanEvents!.first.attributes?.toList(), hasLength(2));

      // Limit + 1
      span.addEventNow('e2', OTel.attributesFromMap({'a': 1, 'b': 2, 'c': 3}));
      expect(span.spanEvents, hasLength(2));
      final event2 = span.spanEvents![1];
      expect(span.droppedAttributesCountForEvent(event2), equals(1));
      expect(event2.attributes?.toList(), hasLength(2));

      // Limit 0
      final zeroProvider = OTel.addTracerProvider(
        'zero-event-attrs-provider',
        spanLimits: const SpanLimits(attributePerEventCountLimit: 0),
      );
      final zeroTracer = zeroProvider.getTracer('zero');
      final spanZero = zeroTracer.startSpan('szero');
      spanZero.addEventNow('e', OTel.attributesFromMap({'a': 1}));
      expect(spanZero.spanEvents, hasLength(1));
      final zEvent = spanZero.spanEvents!.first;
      expect(spanZero.droppedAttributesCountForEvent(zEvent), equals(1));
      expect(zEvent.attributes?.toList(), isEmpty);
      zeroProvider.shutdown();
    });

    test('attributePerLinkCountLimit: at limit, limit+1, and 0', () {
      provider.spanLimits = const SpanLimits(attributePerLinkCountLimit: 2);

      final ctx1 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final ctx2 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556602'),
      );

      final span = tracer.startSpan('s');

      // At limit
      span.addLink(ctx1, OTel.attributesFromMap({'a': 1, 'b': 2}));
      expect(span.spanLinks, hasLength(1));
      expect(
        span.droppedAttributesCountForLink(span.spanLinks!.first),
        equals(0),
      );
      expect(span.spanLinks!.first.attributes.toList(), hasLength(2));

      // Limit + 1
      span.addLink(ctx2, OTel.attributesFromMap({'a': 1, 'b': 2, 'c': 3}));
      expect(span.spanLinks, hasLength(2));
      final link2 = span.spanLinks![1];
      expect(span.droppedAttributesCountForLink(link2), equals(1));
      expect(link2.attributes.toList(), hasLength(2));

      // Limit 0
      final zeroProvider = OTel.addTracerProvider(
        'zero-link-attrs-provider',
        spanLimits: const SpanLimits(attributePerLinkCountLimit: 0),
      );
      final zeroTracer = zeroProvider.getTracer('zero');
      final spanZero = zeroTracer.startSpan('szero');
      spanZero.addLink(ctx1, OTel.attributesFromMap({'a': 1}));
      expect(spanZero.spanLinks, hasLength(1));
      final zLink = spanZero.spanLinks!.first;
      expect(spanZero.droppedAttributesCountForLink(zLink), equals(1));
      expect(zLink.attributes.toList(), isEmpty);
      zeroProvider.shutdown();
    });
  });

  group('Value length limit applies to event and link attributes', () {
    late TracerProvider provider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
      provider = OTel.tracerProvider();
      tracer = provider.getTracer('test');
    });

    tearDown(() async {
      await OTel.shutdown();
      await provider.shutdown();
    });

    test('truncates strings in event and link attributes', () {
      provider.spanLimits = const SpanLimits(attributeValueLengthLimit: 4);

      final ctx = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );

      final span = tracer.startSpan('s');
      span.addEventNow(
        'evt',
        OTel.attributesFromMap({
          'str': '12345678',
          'list': ['abcdef', 'xyz'],
        }),
      );
      span.addLink(ctx, OTel.attributesFromMap({'linkStr': 'abcdefgh'}));

      final evt = span.spanEvents!.first;
      expect(evt.attributes?.getString('str'), equals('1234'));
      expect(evt.attributes?.getStringList('list'), equals(['abcd', 'xyz']));

      final lnk = span.spanLinks!.first;
      expect(lnk.attributes.getString('linkStr'), equals('abcd'));
    });
  });

  group('All Span mutators enforce limits', () {
    late TracerProvider provider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
      provider = OTel.tracerProvider();
      tracer = provider.getTracer('test');
    });

    tearDown(() async {
      await OTel.shutdown();
      await provider.shutdown();
    });

    test('all set*Attribute methods, addAttributes, and attributes setter', () {
      provider.spanLimits = const SpanLimits(
        attributeCountLimit: 5,
        attributeValueLengthLimit: 3,
      );

      final span = tracer.startSpan('s');
      span.setBoolAttribute('bool', true);
      span.setIntAttribute('int', 10);
      span.setDoubleAttribute('double', 3.14);
      span.setStringAttribute<String>('str', 'hello'); // truncated to 'hel'
      span.setBoolListAttribute('bools', [true, false]);

      expect(span.attributes.getString('str'), equals('hel'));
      expect(span.attributes.toList(), hasLength(5));
      expect(span.droppedAttributesCount, equals(0));

      // 6th attribute exceeds count limit
      span.setIntListAttribute('ints', [1, 2]);
      expect(span.droppedAttributesCount, equals(1));

      span.setDoubleListAttribute('doubles', [1.1, 2.2]);
      expect(span.droppedAttributesCount, equals(2));

      span.setStringListAttribute<String>('strings', ['abcd']);
      expect(span.droppedAttributesCount, equals(3));

      // addAttributes
      span.addAttributes(OTel.attributesFromMap({'extra': 'val'}));
      expect(span.droppedAttributesCount, equals(4));

      // attributes setter replaces all attributes and enforces limits
      span.attributes = OTel.attributesFromMap({
        'a': 'test1', // truncated
        'b': 'test2', // truncated
        'c': 'test3', // truncated
        'd': 'test4', // truncated
        'e': 'test5', // truncated
        'f': 'test6', // dropped due to count limit 5
      });
      expect(span.attributes.toList(), hasLength(5));
      expect(span.attributes.getString('a'), equals('tes'));
      expect(span.droppedAttributesCount, equals(5));
    });

    test('empty attribute keys do not consume the count limit', () {
      provider.spanLimits = const SpanLimits(attributeCountLimit: 1);

      final span = tracer.startSpan('s');
      span.setIntAttribute('', 1);
      span.setIntAttribute('valid', 2);

      expect(span.attributes.getInt('valid'), equals(2));
      expect(span.droppedAttributesCount, equals(0));
    });

    test(
      'recordException routes through addEvent and enforces event limits',
      () {
        provider.spanLimits = const SpanLimits(
          eventCountLimit: 1,
          attributePerEventCountLimit: 2,
        );

        final span = tracer.startSpan('s');

        // First exception: added, with stackTrace so it has 3 attributes (exception.type,
        // exception.message, exception.stacktrace), capped by attributePerEventCountLimit (2).
        span.recordException(Exception('boom'), stackTrace: StackTrace.current);
        expect(span.spanEvents, hasLength(1));
        final excEvent = span.spanEvents!.first;
        expect(excEvent.attributes?.toList(), hasLength(2));
        expect(span.droppedAttributesCountForEvent(excEvent), equals(1));
        expect(span.droppedEventsCount, equals(0));

        // Second exception: dropped due to eventCountLimit (1)
        span.recordException(Exception('boom2'));
        expect(span.droppedEventsCount, equals(1));
        expect(span.spanEvents, hasLength(1));
      },
    );

    test('addEvents and addSpanLink enforce limits', () {
      provider.spanLimits = const SpanLimits(
        eventCountLimit: 1,
        linkCountLimit: 1,
      );

      final span = tracer.startSpan('s');
      span.addEvents({
        'ev1': OTel.attributesFromMap({'k': 1}),
        'ev2': OTel.attributesFromMap({'k': 2}),
      });
      expect(span.spanEvents, hasLength(1));
      expect(span.droppedEventsCount, equals(1));

      final ctx1 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final ctx2 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556602'),
      );

      span.addSpanLink(OTel.spanLink(ctx1));
      span.addSpanLink(OTel.spanLink(ctx2));
      expect(span.spanLinks, hasLength(1));
      expect(span.droppedLinksCount, equals(1));
    });
  });

  group('Creation-time enforcement in Tracer.createSpan', () {
    late TracerProvider provider;
    late Tracer tracer;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
      provider = OTel.tracerProvider();
    });

    tearDown(() async {
      await OTel.shutdown();
      await provider.shutdown();
    });

    test('creation-time attributes, links, events, and sampler attributes', () {
      final customSampler = _AttributeAddingSampler(
        OTel.attributesFromMap({'sampler_attr': 'sampler_val_long'}),
      );

      provider.sampler = customSampler;
      provider.spanLimits = const SpanLimits(
        attributeCountLimit: 2,
        attributeValueLengthLimit: 5,
        eventCountLimit: 1,
        linkCountLimit: 1,
      );
      tracer = provider.getTracer('test');

      final ctx1 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final ctx2 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556602'),
      );

      final span = tracer.createSpan(
        name: 'created',
        attributes: OTel.attributesFromMap({
          'k1': 'value_too_long', // truncated to 'value'
          'k2': 'v2',
        }),
        links: [OTel.spanLink(ctx1), OTel.spanLink(ctx2)],
        spanEvents: [
          OTel.spanEventNow('e1', OTel.attributes()),
          OTel.spanEventNow('e2', OTel.attributes()),
        ],
      );

      // Creation links: 1 kept, 1 dropped
      expect(span.spanLinks, hasLength(1));
      expect(span.droppedLinksCount, equals(1));

      // Creation events: 1 kept, 1 dropped
      expect(span.spanEvents, hasLength(1));
      expect(span.droppedEventsCount, equals(1));

      // Creation attributes: k1 and k2 take 2 slots, sampler_attr was dropped or
      // capped by attributeCountLimit (2)
      expect(span.attributes.toList(), hasLength(2));
      expect(span.attributes.getString('k1'), equals('value'));
      expect(
        span.droppedAttributesCount,
        equals(1),
      ); // sampler_attr exceeded limit
    });

    test('creation-time event and link lists are copied before counting', () {
      provider.spanLimits = const SpanLimits(
        eventCountLimit: 2,
        linkCountLimit: 2,
      );
      tracer = provider.getTracer('test');

      final ctx = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final events = [OTel.spanEventNow('creation', OTel.attributes())];
      final links = [OTel.spanLink(ctx)];
      final span = tracer.createSpan(
        name: 'created',
        links: links,
        spanEvents: events,
      );

      events.add(OTel.spanEventNow('external', OTel.attributes()));
      links.add(OTel.spanLink(ctx));
      expect(span.spanEvents, hasLength(1));
      expect(span.spanLinks, hasLength(1));

      span.addEventNow('added');
      span.addLink(ctx);
      expect(span.spanEvents, hasLength(2));
      expect(span.spanLinks, hasLength(2));
      expect(span.droppedEventsCount, equals(0));
      expect(span.droppedLinksCount, equals(0));
    });
  });

  group('Discard logging (v1.60.0 debug log at most once per span)', () {
    late LogLevel savedLevel;
    late LogFunction? savedLogFn;
    late List<String> logs;

    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
      savedLevel = OTelLog.currentLevel;
      savedLogFn = OTelLog.logFunction;
      logs = [];
      OTelLog.logFunction = logs.add;
      OTelLog.enableDebugLogging();
    });

    tearDown(() async {
      OTelLog.currentLevel = savedLevel;
      OTelLog.logFunction = savedLogFn;
      await OTel.shutdown();
    });

    test('logs at debug level at most once per span', () {
      final provider = OTel.tracerProvider();
      provider.spanLimits = const SpanLimits(
        attributeCountLimit: 1,
        attributeValueLengthLimit: 3,
        attributePerEventCountLimit: 1,
        attributePerLinkCountLimit: 1,
      );
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('logged-span');

      // First drop on span triggers log
      span.setStringAttribute<String>(
        'a',
        'toolong',
      ); // truncated -> triggers span discard log
      expect(
        logs.where((l) => l.contains(SpanLimitEnforcer.discardLogMessage)),
        hasLength(1),
      );

      // Second drop on same span does NOT log again
      span.setStringAttribute<String>(
        'b',
        'extra',
      ); // dropped due to count limit -> no second log
      expect(
        logs.where((l) => l.contains(SpanLimitEnforcer.discardLogMessage)),
        hasLength(1),
      );

      // Event attribute limits do not produce another log for this span.
      span.addEventNow(
        'ev',
        OTel.attributesFromMap({'e1': 'toolong', 'e2': 'extra'}),
      );
      expect(
        logs.where((l) => l.contains(SpanLimitEnforcer.discardLogMessage)),
        hasLength(1),
      );

      // Link attribute limits do not produce another log for this span.
      final ctx = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      span.addLink(
        ctx,
        OTel.attributesFromMap({'l1': 'toolong', 'l2': 'extra'}),
      );
      expect(
        logs.where((l) => l.contains(SpanLimitEnforcer.discardLogMessage)),
        hasLength(1),
      );

      provider.shutdown();
    });

    test('does not emit discard log when log level is above debug', () {
      OTelLog.currentLevel = LogLevel.info;

      final provider = OTel.tracerProvider();
      provider.spanLimits = const SpanLimits(attributeCountLimit: 1);
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('quiet-span');
      span.setIntAttribute('a', 1);
      span.setIntAttribute('b', 2); // dropped
      expect(span.droppedAttributesCount, equals(1));
      expect(logs, isEmpty);

      provider.shutdown();
    });

    test('event and link count drops log at most once per span', () {
      final provider = OTel.tracerProvider();
      provider.spanLimits = const SpanLimits(
        eventCountLimit: 1,
        linkCountLimit: 1,
      );
      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('count-drop-span');

      span.addEventNow('ev1');
      span.addEventNow('ev2'); // dropped due to eventCountLimit
      expect(span.droppedEventsCount, equals(1));
      expect(
        logs.where((l) => l.contains(SpanLimitEnforcer.discardLogMessage)),
        hasLength(1),
      );

      final ctx = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      span.addLink(ctx);
      span.addLink(ctx); // dropped due to linkCountLimit
      expect(span.droppedLinksCount, equals(1));
      expect(
        logs.where((l) => l.contains(SpanLimitEnforcer.discardLogMessage)),
        hasLength(1),
      );

      provider.shutdown();
    });
  });

  group('Non-recording and post-end spans', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
    });

    tearDown(() async {
      await OTel.shutdown();
    });

    test('non-recording span mutations are ignored without tracking drops', () {
      final provider = OTel.tracerProvider();
      provider.sampler = const AlwaysOffSampler();
      provider.spanLimits = const SpanLimits(attributeCountLimit: 1);
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('non-recording');
      expect(span.isRecording, isFalse);

      span.setIntAttribute('a', 1);
      span.setIntAttribute('b', 2);
      span.addEventNow('ev');
      span.addLink(
        OTel.spanContext(
          traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
          spanId: OTel.spanIdFrom('0011223344556601'),
        ),
      );

      expect(span.droppedAttributesCount, equals(0));
      expect(span.droppedEventsCount, equals(0));
      expect(span.droppedLinksCount, equals(0));

      provider.shutdown();
    });

    test('mutations after end() are ignored without increasing drops', () {
      final provider = OTel.tracerProvider();
      provider.spanLimits = const SpanLimits(attributeCountLimit: 1);
      final tracer = provider.getTracer('test');

      final span = tracer.startSpan('ended-span');
      span.setIntAttribute('a', 1);
      span.setIntAttribute('b', 2); // dropped
      expect(span.droppedAttributesCount, equals(1));

      span.end();
      expect(span.isEnded, isTrue);

      // Subsequent mutations must be ignored
      span.setIntAttribute('c', 3);
      span.addEventNow('ev_after_end');
      expect(span.droppedAttributesCount, equals(1));
      expect(span.droppedEventsCount, equals(0));

      provider.shutdown();
    });
  });

  group('OTel.initialize and OTel.reset', () {
    tearDown(() async {
      await OTel.reset();
    });

    test(
      'OTel.initialize(spanLimits:) configures default and new providers',
      () async {
        await OTel.reset();
        final customLimits = const SpanLimits(attributeCountLimit: 42);
        await OTel.initialize(
            serviceName: 'test-svc', spanLimits: customLimits);

        final defaultProvider = OTel.tracerProvider();
        expect(defaultProvider.spanLimits.attributeCountLimit, equals(42));

        final addedProvider = OTel.addTracerProvider('added');
        expect(addedProvider.spanLimits.attributeCountLimit, equals(42));

        await OTel.reset();
        await OTel.initialize(serviceName: 'after-reset');
        final afterReset = OTel.tracerProvider();
        expect(afterReset.spanLimits.attributeCountLimit, equals(128));
      },
    );
  });

  group('Environment variables precedence and invalid values', () {
    late LogLevel savedLevel;
    late LogFunction? savedLogFn;
    late List<String> logs;

    void env(Map<String, String> vars) {
      EnvironmentService.testOverrides = vars;
    }

    setUp(() {
      savedLevel = OTelLog.currentLevel;
      savedLogFn = OTelLog.logFunction;
      logs = [];
      OTelLog.logFunction = logs.add;
      OTelLog.currentLevel = LogLevel.warn;
    });

    tearDown(() {
      EnvironmentService.testOverrides = null;
      OTelLog.currentLevel = savedLevel;
      OTelLog.logFunction = savedLogFn;
    });

    test('OTEL_SPAN_* overrides OTEL_ATTRIBUTE_* and falls back properly', () {
      env({
        'OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT': '50',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': '100',
        'OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT': '20',
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '40',
        'OTEL_SPAN_EVENT_COUNT_LIMIT': '15',
        'OTEL_SPAN_LINK_COUNT_LIMIT': '25',
        'OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT': '35',
        'OTEL_LINK_ATTRIBUTE_COUNT_LIMIT': '45',
      });

      final parsed = OTelEnv.getSpanLimits();
      expect(parsed.attributeCountLimit, equals(50));
      expect(parsed.attributeValueLengthLimit, equals(20));
      expect(parsed.eventCountLimit, equals(15));
      expect(parsed.linkCountLimit, equals(25));
      expect(parsed.attributePerEventCountLimit, equals(35));
      expect(parsed.attributePerLinkCountLimit, equals(45));

      final limits = SpanLimits.fromEnvironment();
      expect(limits.attributeCountLimit, equals(50));
      expect(limits.attributeValueLengthLimit, equals(20));
      expect(limits.eventCountLimit, equals(15));
      expect(limits.linkCountLimit, equals(25));
      expect(limits.attributePerEventCountLimit, equals(35));
      expect(limits.attributePerLinkCountLimit, equals(45));
    });

    test('fallback to OTEL_ATTRIBUTE_* when OTEL_SPAN_* unset', () {
      env({
        'OTEL_ATTRIBUTE_COUNT_LIMIT': '88',
        'OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT': '99',
      });

      final parsed = OTelEnv.getSpanLimits();
      expect(parsed.attributeCountLimit, equals(88));
      expect(parsed.attributeValueLengthLimit, equals(99));
      expect(parsed.eventCountLimit, isNull);
      expect(parsed.linkCountLimit, isNull);
      expect(parsed.attributePerEventCountLimit, equals(88));
      expect(parsed.attributePerLinkCountLimit, equals(88));

      final limits = SpanLimits.fromEnvironment();
      expect(limits.attributeCountLimit, equals(88));
      expect(limits.attributeValueLengthLimit, equals(99));
      // Event/link collection limits have no fallback to attribute limits.
      expect(limits.eventCountLimit, equals(128));
      expect(limits.linkCountLimit, equals(128));
      expect(limits.attributePerEventCountLimit, equals(88));
      expect(limits.attributePerLinkCountLimit, equals(88));
    });

    test('invalid model-specific values fall back to general limits', () {
      env({
        'OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT': 'invalid',
        'OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT': '-1',
        'OTEL_LINK_ATTRIBUTE_COUNT_LIMIT': 'invalid',
        'OTEL_ATTRIBUTE_COUNT_LIMIT': '7',
      });

      final parsed = OTelEnv.getSpanLimits();
      expect(parsed.attributeCountLimit, equals(7));
      expect(parsed.attributePerEventCountLimit, equals(7));
      expect(parsed.attributePerLinkCountLimit, equals(7));
      expect(logs, hasLength(3));
    });

    test('invalid env values log warnings and fall back to null/default', () {
      env({
        'OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT': '-5',
        'OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT': 'not-a-number',
      });

      final parsed = OTelEnv.getSpanLimits();
      expect(parsed.attributeCountLimit, isNull);
      expect(parsed.attributeValueLengthLimit, isNull);

      expect(
        logs.where(
          (l) =>
              l.contains('for OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT.') &&
              l.contains('"-5"'),
        ),
        hasLength(1),
      );
      expect(
        logs.where(
          (l) =>
              l.contains('for OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT.') &&
              l.contains('"not-a-number"'),
        ),
        hasLength(1),
      );

      final limits = SpanLimits.fromEnvironment();
      expect(limits.attributeCountLimit, equals(128));
      expect(limits.attributeValueLengthLimit, isNull);
    });
  });

  group('OtlpSpanTransformer writes dropped counts to protobuf', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-limits');
    });

    tearDown(() async {
      await OTel.shutdown();
    });

    test('writes dropped counts for span, events, and links', () {
      final provider = OTel.tracerProvider();
      provider.spanLimits = const SpanLimits(
        attributeCountLimit: 1,
        eventCountLimit: 1,
        linkCountLimit: 1,
        attributePerEventCountLimit: 1,
        attributePerLinkCountLimit: 1,
      );
      final tracer = provider.getTracer('test');

      final ctx1 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final ctx2 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556602'),
      );

      final span = tracer.startSpan('otlp-span');
      span.setStringAttribute<String>('k1', 'v1');
      span.setStringAttribute<String>('k2', 'v2'); // dropped attribute

      span.addEventNow(
        'e1',
        OTel.attributesFromMap({'ea': 1, 'eb': 2}),
      ); // 1 event kept, 1 attr dropped
      span.addEventNow('e2'); // dropped event

      span.addLink(
        ctx1,
        OTel.attributesFromMap({'la': 1, 'lb': 2}),
      ); // 1 link kept, 1 attr dropped
      span.addLink(ctx2); // dropped link

      expect(span.droppedAttributesCount, equals(1));
      expect(span.droppedEventsCount, equals(1));
      expect(span.droppedLinksCount, equals(1));

      final exportReq = OtlpSpanTransformer.transformSpans([span]);
      final resourceSpan = exportReq.resourceSpans.first;
      final scopeSpan = resourceSpan.scopeSpans.first;
      final protoSpan = scopeSpan.spans.first;

      expect(protoSpan.droppedAttributesCount, equals(1));
      expect(protoSpan.droppedEventsCount, equals(1));
      expect(protoSpan.droppedLinksCount, equals(1));

      expect(protoSpan.events, hasLength(1));
      expect(protoSpan.events.first.droppedAttributesCount, equals(1));

      expect(protoSpan.links, hasLength(1));
      expect(protoSpan.links.first.droppedAttributesCount, equals(1));

      provider.shutdown();
    });
  });

  group('Provider overrides, environment limiting, and Span edge cases', () {
    tearDown(() async {
      EnvironmentService.testOverrides = null;
      await OTel.reset();
    });

    test('per-provider override survives OTel.tracerProvider()', () async {
      await OTel.reset();
      await OTel.initialize(
        serviceName: 'test-svc',
        spanLimits: const SpanLimits(attributeCountLimit: 10),
      );

      final provider = OTel.tracerProvider();
      expect(provider.spanLimits.attributeCountLimit, equals(10));

      // Override on this provider
      provider.spanLimits = const SpanLimits(attributeCountLimit: 5);

      // Subsequent call to OTel.tracerProvider() must not overwrite the per-provider override
      final providerAgain = OTel.tracerProvider();
      expect(providerAgain.spanLimits.attributeCountLimit, equals(5));

      // Spans created from provider use the override
      final span = providerAgain.getTracer('test').startSpan('override-span');
      for (var i = 0; i < 7; i++) {
        span.setIntAttribute('k$i', i);
      }
      expect(span.droppedAttributesCount, equals(2));

      // Also named provider override survives OTel.tracerProvider(name:)
      final named = OTel.addTracerProvider(
        'named-override',
        spanLimits: const SpanLimits(attributeCountLimit: 3),
      );
      expect(named.spanLimits.attributeCountLimit, equals(3));
      final namedAgain = OTel.tracerProvider(name: 'named-override');
      expect(namedAgain.spanLimits.attributeCountLimit, equals(3));
    });

    test('end-to-end env var limiting through the lazy provider getter',
        () async {
      await OTel.reset();
      EnvironmentService.testOverrides = {
        'OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT': '2',
        'OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT': '5',
        'OTEL_SPAN_EVENT_COUNT_LIMIT': '1',
        'OTEL_SPAN_LINK_COUNT_LIMIT': '1',
      };
      await OTel.initialize(serviceName: 'test-lazy');

      // Lazy provider getter without explicit spanLimits in OTel.initialize()
      final provider = OTel.tracerProvider();
      expect(provider.spanLimits.attributeCountLimit, equals(2));
      expect(provider.spanLimits.attributeValueLengthLimit, equals(5));
      expect(provider.spanLimits.eventCountLimit, equals(1));
      expect(provider.spanLimits.linkCountLimit, equals(1));

      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('lazy-span');

      // Attribute count and value length limiting
      span.setStringAttribute<String>('short', '12345');
      span.setStringAttribute<String>('long', '1234567890');
      span.setStringAttribute<String>('dropped', 'value');

      expect(span.attributes.toList(), hasLength(2));
      final longAttr =
          span.attributes.toList().firstWhere((a) => a.key == 'long');
      expect(longAttr.value, equals('12345'));
      expect(span.droppedAttributesCount, equals(1));

      // Event count limiting
      span.addEventNow('event1');
      span.addEventNow('event2');
      expect(span.spanEvents, hasLength(1));
      expect(span.droppedEventsCount, equals(1));

      // Link count limiting
      final ctx1 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556601'),
      );
      final ctx2 = OTel.spanContext(
        traceId: OTel.traceIdFrom('00112233445566778899aabbccddeeff'),
        spanId: OTel.spanIdFrom('0011223344556602'),
      );
      span.addLink(ctx1);
      span.addLink(ctx2);
      expect(span.spanLinks, hasLength(1));
      expect(span.droppedLinksCount, equals(1));
    });

    test('recordException with a throwing toString() does not crash', () async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-exc');
      final provider = OTel.tracerProvider();
      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('exc-span');

      span.recordException(_ThrowingToStringException());

      expect(span.spanEvents, hasLength(1));
      final event = span.spanEvents!.first;
      expect(event.name, equals('exception'));
      final messageAttr = event.attributes!.toList().firstWhere(
            (a) => a.key == ExceptionAttributes.exceptionMessage.key,
          );
      expect(
        messageAttr.value,
        equals(
          'Exception when calling toString of span exception: Bad state: boom',
        ),
      );
      final typeAttr = event.attributes!.toList().firstWhere(
            (a) => a.key == ExceptionAttributes.exceptionType.key,
          );
      expect(typeAttr.value, equals('_ThrowingToStringException'));
    });

    test('event helpers use the tracer time provider snapshot', () async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-time');
      final fixedTime = DateTime.utc(2026, 10, 11, 15, 30, 0);
      final provider = OTel.tracerProvider();
      provider.timeProvider = _CustomTimeProvider(fixedTime);

      final tracer = provider.getTracer('test');
      provider.timeProvider = _CustomTimeProvider(
        fixedTime.add(const Duration(hours: 1)),
      );
      final span = tracer.startSpan('event-time-span');
      span.addEventNow('custom_time_event');
      span.addEvents({'custom_time_event_2': null});
      span.recordException(Exception('custom_time_exception'));

      expect(span.spanEvents, hasLength(3));
      for (final event in span.spanEvents!) {
        expect(event.timestamp, equals(fixedTime));
      }
    });

    test('setDateTimeAsStringAttribute format unchanged', () async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-dt');
      final provider = OTel.tracerProvider();
      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('dt-span');

      final dt = DateTime.utc(2026, 10, 11, 14, 30, 45, 123);
      span.setDateTimeAsStringAttribute('my_time', dt);

      final attr =
          span.attributes.toList().firstWhere((a) => a.key == 'my_time');
      expect(attr.value, equals(Timestamp.dateTimeToString(dt)));
    });

    test(
        'empty-name events are dropped, not thrown, and not counted as limit drops',
        () async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-empty-event');
      final provider = OTel.tracerProvider();
      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('empty-event-span');

      // The API reports the invalid name and the span drops the event.
      span.addEventNow('');
      expect(span.spanEvents, isNull);
      expect(span.droppedEventsCount, equals(0));

      // addEvents also reports and drops the empty name, then adds the valid one.
      span.addEvents({'': null, 'valid_event': null});
      expect(span.spanEvents, hasLength(1));
      expect(span.spanEvents!.first.name, equals('valid_event'));
      expect(span.droppedEventsCount, equals(0));
    });

    test(
        'setStringListAttribute with emoji and valueLengthLimit 1 stores empty and truncated string',
        () async {
      await OTel.reset();
      await OTel.initialize(serviceName: 'test-emoji-list');
      final provider = OTel.tracerProvider();
      provider.spanLimits = const SpanLimits(attributeValueLengthLimit: 1);
      final tracer = provider.getTracer('test');
      final span = tracer.startSpan('emoji-span');

      span.setStringListAttribute<List<String>>(
        'emoji_list',
        ['😀', 'hello'],
      );

      final attr =
          span.attributes.toList().firstWhere((a) => a.key == 'emoji_list');
      expect(attr.value, equals(['', 'h']));
    });
  });
}

class _ThrowingToStringException {
  @override
  String toString() => throw StateError('boom');
}

class _CustomTimeProvider implements TimeProvider {
  final DateTime fixedTime;
  _CustomTimeProvider(this.fixedTime);

  @override
  DateTime nowDateTime() => fixedTime;
}

class _AttributeAddingSampler implements Sampler {
  final Attributes extraAttributes;
  const _AttributeAddingSampler(this.extraAttributes);

  @override
  String get description => 'AttributeAddingSampler';

  @override
  SamplingResult shouldSample({
    required Context parentContext,
    required String traceId,
    required String name,
    required SpanKind spanKind,
    required Attributes? attributes,
    required List<SpanLink>? links,
  }) {
    return SamplingResult(
      decision: SamplingDecision.recordAndSample,
      source: SamplingDecisionSource.tracerConfig,
      attributes: extraAttributes,
    );
  }
}
