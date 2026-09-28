// Shared real-pointer interactions for Android business journeys.
// Retry readiness only: the action itself is sent exactly once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _routeReady(Element element) {
  final route = ModalRoute.of(element);
  return route == null ||
      (route.isCurrent &&
          (route.animation == null ||
              route.animation!.status == AnimationStatus.completed) &&
          (route.secondaryAnimation == null ||
              route.secondaryAnimation!.status == AnimationStatus.dismissed));
}

// Unlike ListView.last, this finder can safely be empty during navigation or
// profile loading. A retained list beneath a popup is not its current viewport.
Finder currentRouteLists() => find.byElementPredicate(
  (element) => element.widget is ListView && _routeReady(element),
);

Future<Finder> waitForScrollable(WidgetTester tester, Finder scope) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final candidates = find.descendant(
      of: scope,
      matching: find.byType(Scrollable),
    );
    final ready = candidates.evaluate().where(_routeReady).toList();
    if (ready.isNotEmpty) {
      final selected = ready.first;
      return find.byElementPredicate((element) => identical(element, selected));
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('Current-route scrollable did not become ready: $scope');
}

Future<void> showControl(
  WidgetTester tester,
  Finder target, {
  int maxScrolls = 100,
  double scrollDelta = 300,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 350));
  for (var attempt = 0; attempt < 40; attempt++) {
    final matches = target.evaluate().toList();
    if (matches.isNotEmpty && matches.every(_routeReady)) {
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
      await tester.pump(const Duration(milliseconds: 450));
      return;
    }
    // An already mounted control may not have any enclosing ListView. Only
    // acquire a list for an unbuilt target, and only on the settled top route.
    final lists = currentRouteLists().evaluate().toList();
    if (matches.isEmpty && lists.isNotEmpty) {
      final list = lists.last;
      final viewport = find.descendant(
        of: find.byElementPredicate((element) => identical(element, list)),
        matching: find.byType(Scrollable),
      );
      if (viewport.evaluate().isNotEmpty) {
        final scrollable = viewport.first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.scrollUntilVisible(
          target,
          scrollDelta,
          scrollable: scrollable,
          maxScrolls: maxScrolls,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
        await tester.pump(const Duration(milliseconds: 450));
        return;
      }
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('Control or current-route viewport did not become ready: $target');
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
