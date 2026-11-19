// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/src/export/export_error_scope.dart';
import 'package:test/test.dart';

void main() {
  test('overlapping operations do not suppress each other', () async {
    final errors = <Object>[];
    OTel.setErrorHandler((error, _) => errors.add(error));
    addTearDown(() => OTel.setErrorHandler(null));
    final reported = Completer<void>();
    final release = Completer<void>();
    final first = ExportErrorScope.run((scope) async {
      ExportErrorScope.report('original');
      reported.complete();
      await release.future;
      scope.reportIfNeeded('duplicate');
    });
    await reported.future;
    await ExportErrorScope.run((scope) async {
      scope.reportIfNeeded('independent failure');
    });
    release.complete();
    await first;
    expect(errors, ['original', 'independent failure']);
  });

  test('strict handler exception crosses nested scopes without reporting again',
      () async {
    final errors = <Object>[];
    final strict = StateError('strict');
    final stack = StackTrace.fromString('original stack');
    OTel.setErrorHandler((error, _) {
      errors.add(error);
      Error.throwWithStackTrace(strict, stack);
    });
    addTearDown(() => OTel.setErrorHandler(null));
    StackTrace? receivedStack;
    final operation = ExportErrorScope.run((outer) async {
      try {
        await ExportErrorScope.run((inner) async {
          try {
            ExportErrorScope.report('original');
          } catch (error, stack) {
            inner.reportIfNeeded(error, stack);
          }
        });
      } catch (error, stack) {
        receivedStack = stack;
        outer.reportIfNeeded(error, stack);
      }
    });
    await expectLater(operation, throwsA(same(strict)));
    expect(errors, ['original']);
    expect(receivedStack.toString(), stack.toString());
  });
  test('late nested reports are ignored after the parent scope finishes',
      () async {
    final errors = <Object>[];
    OTel.setErrorHandler((error, _) => errors.add(error));
    addTearDown(() => OTel.setErrorHandler(null));
    final release = Completer<void>();
    late Future<void> pending;
    await ExportErrorScope.run((outer) async {
      pending = ExportErrorScope.run((inner) async {
        await release.future;
        ExportErrorScope.report('late transport failure');
        inner.reportIfNeeded('late fallback');
      });
      outer.reportIfNeeded('outer timeout');
    });
    release.complete();
    await pending;
    expect(errors, ['outer timeout']);
  });

  test('handled siblings do not suppress independent delegate failures',
      () async {
    final errors = <Object>[];
    OTel.setErrorHandler((error, _) => errors.add(error));
    addTearDown(() => OTel.setErrorHandler(null));
    await ExportErrorScope.run((outer) async {
      for (final error in ['first', 'second']) {
        await ExportErrorScope.run((inner) async {
          ExportErrorScope.report(error);
          ExportErrorScope.report('duplicate');
        });
      }
      outer.reportIfNeeded('duplicate fallback');
    });
    expect(errors, ['first', 'second']);
  });
}
