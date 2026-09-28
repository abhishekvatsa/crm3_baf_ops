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

  testWidgets(
    'RA journey waits for the time picker and records the chosen time',
    (tester) async {
      final obscured = ValueNotifier(false);
      addTearDown(obscured.dispose);
      final recorded = <DateTime>[];
      var mountedButUnreachable = false;
      Timer? transition;
      addTearDown(() => transition?.cancel());
      final observer = _TimePickerObserver(() {
        obscured.value = true;
        transition = Timer(const Duration(milliseconds: 1500), () {
          final dialog = find.byType(TimePickerDialog);
          expect(dialog, findsOneWidget);
          final labels = MaterialLocalizations.of(tester.element(dialog));
          final mode = find.descendant(
            of: dialog,
            matching: find.byTooltip(labels.inputTimeModeButtonLabel),
          );
          mountedButUnreachable =
              mode.evaluate().isNotEmpty &&
              mode.hitTestable().evaluate().isEmpty;
          obscured.value = false;
        });
      });
      await tester.pumpWidget(
        _coveredTimePicker(obscured, observer, recorded.add),
      );
      final started = DateTime.now().toUtc();

      final selected = await journey.confirmCurrentRaTime(tester);

      expect(mountedButUnreachable, isTrue);
      expect(recorded, hasLength(1));
      expect(recorded.single.toUtc(), selected);
      expect(selected.second, 0);
      expect(selected.millisecond, 0);
      expect(
        selected.isAfter(started.subtract(const Duration(minutes: 6))),
        isTrue,
      );
      expect(
        selected.isBefore(started.subtract(const Duration(minutes: 4))),
        isTrue,
      );
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RA journey fails when the time picker remains obscured', (
    tester,
  ) async {
    final obscured = ValueNotifier(false);
    addTearDown(obscured.dispose);
    final recorded = <DateTime>[];
    final observer = _TimePickerObserver(() => obscured.value = true);
    await tester.pumpWidget(
      _coveredTimePicker(obscured, observer, recorded.add),
    );

    Object? failure;
    try {
      await journey.confirmCurrentRaTime(tester);
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<TestFailure>());
    expect(
      '$failure',
      contains('Control remained unreachable after five reveal attempts'),
    );
    expect(recorded, isEmpty);
    final dialog = find.byType(TimePickerDialog);
    expect(dialog, findsOneWidget);
    final labels = MaterialLocalizations.of(tester.element(dialog));
    expect(
      find
          .descendant(
            of: dialog,
            matching: find.byTooltip(labels.inputTimeModeButtonLabel),
          )
          .hitTestable(),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

// Cover the Navigator itself so the real second (time) picker is obstructed,
// while the date picker and the underlying RA field remain fully interactive.
class _TimePickerObserver extends NavigatorObserver {
  _TimePickerObserver(this.onTimePicker);

  final VoidCallback onTimePicker;
  var dialogCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute<dynamic> && ++dialogCount == 2) onTimePicker();
  }
}

Widget _coveredTimePicker(
  ValueNotifier<bool> obscured,
  NavigatorObserver observer,
  ValueChanged<DateTime> onChanged,
) => MaterialApp(
  navigatorObservers: [observer],
  builder: (context, child) => Stack(
    children: [
      child!,
      ValueListenableBuilder<bool>(
        valueListenable: obscured,
        builder: (context, blocked, child) => blocked
            ? const ModalBarrier(dismissible: false, color: Colors.black26)
            : const SizedBox.shrink(),
      ),
    ],
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 300,
        child: RaPerformedAtField(value: null, onChanged: onChanged),
      ),
    ),
  ),
);

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
