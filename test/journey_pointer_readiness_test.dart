import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/dev_abnormality_journey_test.dart' as abnormality;
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

  testWidgets(
    'route return waits for a delayed list before revealing its row',
    (tester) async {
      final listReady = ValueNotifier(false);
      addTearDown(listReady.dispose);
      var opened = 0;
      await _returnToLoadingList(tester, listReady, () => opened++);
      final target = find.text('Abnormalities');
      expect(find.byType(ListView), findsNothing);
      expect(target, findsNothing);
      final load = Timer(const Duration(milliseconds: 1200), () {
        listReady.value = true;
      });
      addTearDown(load.cancel);

      await abnormality.reveal(tester, target);

      expect(listReady.value, isTrue);
      expect(target.hitTestable(), findsOneWidget);
      expect(opened, 0, reason: 'Revealing a row must not invoke its action.');
      await pointer.tapControl(tester, target);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('route return fails boundedly when its list never mounts', (
    tester,
  ) async {
    final listReady = ValueNotifier(false);
    addTearDown(listReady.dispose);
    var opened = 0;
    await _returnToLoadingList(tester, listReady, () => opened++);
    final target = find.text('Abnormalities');
    final started = tester.binding.clock.now();
    Object? failure;
    try {
      await abnormality.reveal(tester, target);
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<TestFailure>());
    expect('$failure', contains('Abnormalities'));
    expect(
      tester.binding.clock.now().difference(started),
      lessThanOrEqualTo(const Duration(seconds: 10)),
    );
    expect(find.byType(ListView), findsNothing);
    expect(target, findsNothing);
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveal accepts a mounted control without any ListView', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => opened++,
              child: const Text('Open mounted control'),
            ),
          ),
        ),
      ),
    );
    final target = find.text('Open mounted control');
    expect(find.byType(ListView), findsNothing);

    await abnormality.reveal(tester, target);

    expect(target.hitTestable(), findsOneWidget);
    expect(opened, 0);
    await pointer.tapControl(tester, target);
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'popup waits for its own list and leaves the retained list alone',
    (tester) async {
      final listReady = ValueNotifier(false);
      final underlying = ScrollController(initialScrollOffset: 224);
      final popup = ScrollController();
      addTearDown(listReady.dispose);
      addTearDown(underlying.dispose);
      addTearDown(popup.dispose);
      var selected = 0;
      var underlyingActions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              key: const Key('retained-list'),
              controller: underlying,
              itemCount: 40,
              itemExtent: 56,
              itemBuilder: (context, index) => ListTile(
                title: Text('Underlying $index'),
                onTap: () => underlyingActions++,
              ),
            ),
            floatingActionButton: Builder(
              builder: (context) => FloatingActionButton(
                key: const Key('open-list-popup'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: SizedBox(
                      width: 300,
                      height: 280,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: listReady,
                        builder: (context, ready, child) => ready
                            ? ListView.builder(
                                key: const Key('popup-list'),
                                controller: popup,
                                itemCount: 40,
                                itemExtent: 56,
                                itemBuilder: (context, index) => ListTile(
                                  title: Text(
                                    index == 25
                                        ? 'Popup choice'
                                        : 'Choice $index',
                                  ),
                                  onTap: index == 25 ? () => selected++ : null,
                                ),
                              )
                            : const Center(child: Text('Loading choices')),
                      ),
                    ),
                  ),
                ),
                child: const Icon(Icons.list),
              ),
            ),
          ),
        ),
      );
      await pointer.tapControl(
        tester,
        find.byKey(const Key('open-list-popup')),
      );
      await tester.pumpAndSettle();
      final originalOffset = underlying.offset;
      expect(originalOffset, greaterThan(0));
      expect(find.byKey(const Key('retained-list')), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(pointer.currentRouteLists(), findsNothing);
      final target = find.descendant(
        of: pointer.currentRouteLists(),
        matching: find.text('Popup choice'),
      );
      expect(target, findsNothing);
      final load = Timer(const Duration(milliseconds: 1200), () {
        listReady.value = true;
      });
      addTearDown(load.cancel);

      // Even a broad list scope must wait for the popup's viewport rather than
      // returning the still-mounted page underneath its modal barrier.
      final viewport = await pointer.waitForScrollable(
        tester,
        find.byType(ListView),
      );
      expect(
        tester.state<ScrollableState>(viewport).position,
        same(popup.position),
      );
      await abnormality.reveal(tester, target);

      expect(target.hitTestable(), findsOneWidget);
      expect(popup.offset, greaterThan(0));
      expect(underlying.offset, originalOffset);
      expect(selected, 0);
      expect(underlyingActions, 0);
      await pointer.tapControl(tester, target);
      expect(selected, 1);
      expect(underlyingActions, 0);
      expect(underlying.offset, originalOffset);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing popup target fails without scrolling the retained list',
    (tester) async {
      final underlying = ScrollController(initialScrollOffset: 224);
      addTearDown(underlying.dispose);
      var underlyingActions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              key: const Key('retained-list'),
              controller: underlying,
              itemCount: 40,
              itemExtent: 56,
              itemBuilder: (context, index) => ListTile(
                title: Text('Underlying $index'),
                onTap: () => underlyingActions++,
              ),
            ),
            floatingActionButton: Builder(
              builder: (context) => FloatingActionButton(
                key: const Key('open-missing-popup'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const Dialog(
                    child: SizedBox(
                      width: 300,
                      height: 280,
                      child: Center(child: Text('Loading choices')),
                    ),
                  ),
                ),
                child: const Icon(Icons.list),
              ),
            ),
          ),
        ),
      );
      await pointer.tapControl(
        tester,
        find.byKey(const Key('open-missing-popup')),
      );
      await tester.pumpAndSettle();
      final originalOffset = underlying.offset;
      expect(originalOffset, greaterThan(0));
      expect(find.byType(ListView), findsOneWidget);
      expect(pointer.currentRouteLists(), findsNothing);
      final target = find.descendant(
        of: pointer.currentRouteLists(),
        matching: find.text('Missing popup choice'),
      );
      final started = tester.binding.clock.now();
      Object? failure;
      try {
        await abnormality.reveal(tester, target);
      } catch (error) {
        failure = error;
      }

      expect(failure, isA<TestFailure>());
      expect('$failure', contains('Missing popup choice'));
      expect(
        tester.binding.clock.now().difference(started),
        lessThanOrEqualTo(const Duration(seconds: 10)),
      );
      expect(target, findsNothing);
      expect(underlying.offset, originalOffset);
      expect(underlyingActions, 0);
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _returnToLoadingList(
  WidgetTester tester,
  ValueNotifier<bool> listReady,
  VoidCallback onOpen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ValueListenableBuilder<bool>(
          valueListenable: listReady,
          builder: (context, ready, child) => ready
              ? ListView.builder(
                  itemCount: 40,
                  itemExtent: 56,
                  itemBuilder: (context, index) => index == 25
                      ? ListTile(
                          title: const Text('Abnormalities'),
                          onTap: onOpen,
                        )
                      : ListTile(title: Text('Destination $index')),
                )
              : const Center(child: Text('Loading destinations')),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            key: const Key('open-quality'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Quality')),
                  body: const Center(child: Text('Warning verified')),
                ),
              ),
            ),
            child: const Icon(Icons.fact_check),
          ),
        ),
      ),
    ),
  );
  await pointer.tapControl(tester, find.byKey(const Key('open-quality')));
  await tester.pumpAndSettle();
  expect(find.text('Quality'), findsOneWidget);
  await abnormality.goBack(tester);
  await tester.pumpAndSettle();
  expect(find.text('Quality'), findsNothing);
  expect(find.text('Loading destinations'), findsOneWidget);
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
