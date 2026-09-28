import 'dart:async';

import 'package:crm3_baf_ops/features/abnormalities/presentation/ra_performed_at_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/dev_issue_quality_journey_test.dart' as journey;

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  testWidgets('RA journey waits until the date control receives pointer events', (
    tester,
  ) async {
    final obscured = ValueNotifier(true);
    addTearDown(obscured.dispose);
    await tester.pumpWidget(_coveredRaField(obscured));
    final target = find.byKey(const ValueKey('ra-performed-at'));
    expect(target, findsOneWidget);
    expect(target.hitTestable(), findsNothing);

    // Native keyboard and dialog layout can still change after the helper's
    // first reveal. The date tile is mounted but a pointer cannot reach it yet.
    final transition = Timer(const Duration(milliseconds: 1100), () {
      obscured.value = false;
    });
    addTearDown(transition.cancel);
    await journey.tapControl(tester, target);

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RA journey fails when a control remains obscured', (
    tester,
  ) async {
    final obscured = ValueNotifier(true);
    addTearDown(obscured.dispose);
    await tester.pumpWidget(_coveredRaField(obscured));

    Object? failure;
    try {
      await journey.tapControl(
        tester,
        find.byKey(const ValueKey('ra-performed-at')),
      );
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<TestFailure>());

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _coveredRaField(ValueNotifier<bool> obscured) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        Center(
          child: SizedBox(
            width: 300,
            child: RaPerformedAtField(value: null, onChanged: (_) {}),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: obscured,
          builder: (context, blocked, child) => blocked
              ? const ModalBarrier(dismissible: false, color: Colors.black26)
              : const SizedBox.shrink(),
        ),
      ],
    ),
  ),
);
