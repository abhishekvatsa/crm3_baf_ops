import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/journey_pointer.dart' as pointer;

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  testWidgets(
    'popup selection waits for reachability and selects exactly once',
    (tester) async {
      final blocked = ValueNotifier(false);
      addTearDown(blocked.dispose);
      final selected = <String>[];
      int? selectionCountBeforeRelease;
      Timer? release;
      addTearDown(() => release?.cancel());
      final observer = _PopupObserver(() {
        blocked.value = true;
        release = Timer(const Duration(milliseconds: 1500), () {
          selectionCountBeforeRelease = selected.length;
          blocked.value = false;
        });
      });
      await tester.pumpWidget(
        _coveredApp(blocked, _popup(selected.add), observer: observer),
      );

      await pointer.tapControl(tester, find.byKey(const Key('open-options')));
      final option = find.text('Inspect furnace');
      expect(option, findsOneWidget);
      expect(option.hitTestable(), findsNothing);
      await pointer.tapControl(tester, option);
      await tester.pumpAndSettle();

      expect(selectionCountBeforeRelease, 0);
      expect(selected, ['inspect']);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permanently blocked popup does not select an option', (
    tester,
  ) async {
    final blocked = ValueNotifier(false);
    addTearDown(blocked.dispose);
    final selected = <String>[];
    await tester.pumpWidget(
      _coveredApp(
        blocked,
        _popup(selected.add),
        observer: _PopupObserver(() => blocked.value = true),
      ),
    );

    await pointer.tapControl(tester, find.byKey(const Key('open-options')));
    final option = find.text('Inspect furnace');
    expect(option, findsOneWidget);
    expect(option.hitTestable(), findsNothing);
    await _expectBlocked(tester, option);

    expect(selected, isEmpty);
    expect(option, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked enabled recovery action is never invoked', (
    tester,
  ) async {
    final blocked = ValueNotifier(true);
    addTearDown(blocked.dispose);
    var requests = 0;
    await tester.pumpWidget(
      _coveredApp(
        blocked,
        ElevatedButton(
          key: const Key('recheck-recovery'),
          onPressed: () => requests++,
          child: const Text('Recheck recovery gate'),
        ),
      ),
    );
    final action = find.byKey(const Key('recheck-recovery'));
    expect(tester.widget<ElevatedButton>(action).onPressed, isNotNull);
    expect(action.hitTestable(), findsNothing);

    await _expectBlocked(tester, action);

    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'charge Open waits for keyboard layout and preserves entered text',
    (tester) async {
      final charge = TextEditingController();
      addTearDown(charge.dispose);
      addTearDown(tester.view.resetViewInsets);
      final bottomSpace = ValueNotifier(16.0);
      addTearDown(bottomSpace.dispose);
      final opened = <String>[];
      final insetsAtOpen = <double>[];
      final layoutAtOpen = <double>[];
      final actionsDuringTransition = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: bottomSpace,
              builder: (context, bottom, child) => Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextField(key: const Key('charge'), controller: charge),
                    ElevatedButton(
                      key: const Key('open-charge'),
                      onPressed: () {
                        opened.add(charge.text);
                        insetsAtOpen.add(tester.view.viewInsets.bottom);
                        layoutAtOpen.add(bottomSpace.value);
                      },
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('charge')), '73182');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pump();
      final open = find.byKey(const Key('open-charge'));
      final keyboardRect = tester.getRect(open);
      final resizing = Timer(const Duration(milliseconds: 700), () {
        actionsDuringTransition.add(opened.length);
        tester.view.viewInsets = const FakeViewPadding(bottom: 120);
      });
      final closing = Timer(const Duration(milliseconds: 1500), () {
        actionsDuringTransition.add(opened.length);
        tester.view.viewInsets = const FakeViewPadding();
      });
      // One final layout update follows the closing keyboard metrics. The
      // action must also wait for its new position to stop changing.
      final repositioning = Timer(const Duration(milliseconds: 1650), () {
        actionsDuringTransition.add(opened.length);
        bottomSpace.value = 80;
      });
      addTearDown(resizing.cancel);
      addTearDown(closing.cancel);
      addTearDown(repositioning.cancel);

      await pointer.tapControl(tester, open);

      expect(actionsDuringTransition, [0, 0, 0]);
      expect(opened, ['73182']);
      expect(insetsAtOpen, [0.0]);
      expect(layoutAtOpen, [80.0]);
      expect(charge.text, '73182');
      expect(tester.getRect(open), isNot(keyboardRect));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('launcher underneath a modal is not dragged', (tester) async {
    var drags = 0;
    var confirmed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Stack(
              children: [
                Center(
                  child: GestureDetector(
                    key: const Key('global-critical-alarm-launcher'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (_) => drags++,
                    child: const SizedBox(width: 120, height: 48),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    key: const Key('open-dialog'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        child: SizedBox(
                          width: 120,
                          height: 48,
                          child: TextButton(
                            onPressed: () {
                              confirmed++;
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Continue'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Open confirmation'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    expect(launcher.hitTestable(), findsOneWidget);
    await pointer.tapControl(tester, find.byKey(const Key('open-dialog')));
    final confirm = find.text('Continue');
    expect(launcher, findsOneWidget);
    expect(launcher.hitTestable(), findsNothing);
    expect(confirm.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(launcher).contains(tester.getCenter(confirm)),
      isTrue,
    );

    await pointer.tapControl(tester, confirm);
    await tester.pumpAndSettle();

    expect(confirmed, 1);
    expect(drags, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _expectBlocked(WidgetTester tester, Finder target) async {
  Object? failure;
  try {
    await pointer.tapControl(tester, target);
  } catch (error) {
    failure = error;
  }
  expect(failure, isA<TestFailure>());
  expect(
    '$failure',
    contains('Control remained unreachable after five reveal attempts'),
  );
}

Widget _popup(ValueChanged<String> onSelected) => PopupMenuButton<String>(
  key: const Key('open-options'),
  onSelected: onSelected,
  itemBuilder: (_) => const [
    PopupMenuItem(value: 'inspect', child: Text('Inspect furnace')),
  ],
  child: const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Choose action'),
  ),
);

Widget _coveredApp(
  ValueNotifier<bool> blocked,
  Widget control, {
  NavigatorObserver? observer,
}) => MaterialApp(
  navigatorObservers: [if (observer != null) observer],
  builder: (context, child) => Stack(
    children: [
      child!,
      ValueListenableBuilder<bool>(
        valueListenable: blocked,
        builder: (context, covered, child) => covered
            ? const ModalBarrier(dismissible: false, color: Colors.black26)
            : const SizedBox.shrink(),
      ),
    ],
  ),
  home: Scaffold(body: Center(child: control)),
);

class _PopupObserver extends NavigatorObserver {
  _PopupObserver(this.onPopup);

  final VoidCallback onPopup;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute<dynamic>) onPopup();
  }
}
