// Shared real-pointer interactions for Android business journeys.
// Retry readiness only: the action itself is sent exactly once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showControl(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 350));
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    // A user may have left the list at any position. Reset only navigation.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: scrollable,
      maxScrolls: 100,
    );
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> tapControl(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    await showControl(tester, target);
    // The real, movable safety shortcut can overlap a form control. Reposition
    // it using the user gesture rather than tapping through it or hiding it.
    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    if (launcher.hitTestable().evaluate().isNotEmpty &&
        tester.getRect(launcher).contains(tester.getCenter(target))) {
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final current = tester.getCenter(launcher);
      final destination = Offset(
        current.dx > size.width / 2 ? 36 : size.width - 36,
        120,
      );
      await tester.drag(launcher, destination - current);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.getRect(launcher).contains(tester.getCenter(target)),
        isFalse,
        reason:
            'The safety shortcut must move clear before tapping the control.',
      );
    }
    // Android keyboard metrics can resize the dialog after ensureVisible.
    // Reveal again if its mounted tile is now clipped behind the modal barrier.
    // Never suppress a missed tap or invoke the control's callback directly.
    if (tester.view.viewInsets.bottom != 0 ||
        target.hitTestable().evaluate().isEmpty) {
      continue;
    }
    final rect = tester.getRect(target);
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.view.viewInsets.bottom != 0 ||
        target.hitTestable().evaluate().isEmpty ||
        tester.getRect(target) != rect) {
      continue;
    }
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 500));
    return;
  }
  fail('Control remained unreachable after five reveal attempts: $target');
}
