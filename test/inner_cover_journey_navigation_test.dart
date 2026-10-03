import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/required_red_journey.dart'
    show returnRequiredRedHome;

// Real Navigator timing for the IC acceptance dialog -> details sheet ->
// lifecycle -> history -> Home stack. These fixtures establish navigation only;
// their delayed local reply is not a server/business acceptance simulation.
void main() {
  testWidgets(
    'IC return waits for each real route to leave before another Back',
    (tester) async {
      final fixture = await _open(tester);
      await returnRequiredRedHome(tester, find.byKey(_home));
      expect(fixture.observer.popped, ['lifecycle', 'history']);
      expect(fixture.backGestures, ['lifecycle', 'history']);
      expect(fixture.lifecycleDisposed, isTrue);
      expect(find.byKey(_home), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IC return ignores duplicate Back tooltips during reverse', (
    tester,
  ) async {
    final fixture = await _open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.lifecycle.animation!.status, AnimationStatus.reverse);
    expect(find.byTooltip('Back'), findsNWidgets(2));
    expect(fixture.lifecycleDisposed, isFalse);
    await returnRequiredRedHome(tester, find.byKey(_home));
    expect(fixture.observer.popped, ['lifecycle', 'history']);
    expect(fixture.backGestures, ['lifecycle', 'history']);
    expect(fixture.lifecycleDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'IC return waits for acceptance dialog and sheet automatic return',
    (tester) async {
      final fixture = await _open(tester);
      await tester.tap(find.text('Cover details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect and accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record acceptance'));
      await tester.pump();
      expect(fixture.replyPending, isTrue);
      expect(fixture.observer.popped, isEmpty);
      final timer = Timer(
        const Duration(milliseconds: 400),
        () => fixture.reply.complete(),
      );
      addTearDown(timer.cancel);
      await returnRequiredRedHome(tester, find.byKey(_home));
      expect(fixture.observer.popped, [
        'acceptance',
        'details',
        'lifecycle',
        'history',
      ]);
      expect(fixture.backGestures, ['lifecycle', 'history']);
      expect(fixture.lifecycleDisposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IC return refuses unresolved modal instead of tapping behind it',
    (tester) async {
      final fixture = await _open(tester);
      await tester.tap(find.text('Cover details'));
      await tester.pumpAndSettle();
      final failure = await _failure(
        () => returnRequiredRedHome(tester, find.byKey(_home), maxPumps: 4),
      );
      expect(failure, isA<TestFailure>());
      expect(fixture.observer.popped, isEmpty);
      expect(fixture.backGestures, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IC return refuses ambiguous current-route Back controls', (
    tester,
  ) async {
    final fixture = await _open(tester, duplicateBack: true);
    expect(find.byTooltip('Back').hitTestable(), findsNWidgets(2));
    final failure = await _failure(
      () => returnRequiredRedHome(tester, find.byKey(_home), maxPumps: 4),
    );
    expect(failure, isA<TestFailure>());
    expect(fixture.observer.popped, isEmpty);
    expect(fixture.backGestures, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('IC return sends one Back then fails bounded if pop is refused', (
    tester,
  ) async {
    final fixture = await _open(tester, refusePop: true);
    final failure = await _failure(
      () => returnRequiredRedHome(
        tester,
        find.byKey(_home),
        maxPumps: 4,
        popPumps: 4,
      ),
    );
    expect(failure, isA<TestFailure>());
    expect(fixture.observer.popped, isEmpty);
    expect(fixture.backGestures, ['lifecycle']);
    expect(fixture.lifecycleDisposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

const _home = ValueKey('ic-navigation-home');
Future<Object?> _failure(Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    return error;
  }
  return null;
}

Future<_Fixture> _open(
  WidgetTester tester, {
  bool duplicateBack = false,
  bool refusePop = false,
}) async {
  final fixture = _Fixture();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: fixture.navigator,
      navigatorObservers: [fixture.observer],
      home: const Scaffold(body: Text('Home', key: _home)),
    ),
  );
  unawaited(
    fixture.navigator.currentState!.push<void>(
      _SlowRoute(
        name: 'history',
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: fixture.back(context, 'history'),
            title: const Text('Stuck-up history'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  fixture.lifecycle = _SlowRoute(
    name: 'lifecycle',
    builder: (_) => _Lifecycle(
      fixture: fixture,
      duplicateBack: duplicateBack,
      refusePop: refusePop,
    ),
  );
  unawaited(fixture.navigator.currentState!.push<void>(fixture.lifecycle));
  await tester.pumpAndSettle();
  return fixture;
}

class _Fixture {
  final navigator = GlobalKey<NavigatorState>();
  final observer = _Observer();
  final reply = Completer<void>();
  final backGestures = <String>[];
  late _SlowRoute lifecycle;
  bool lifecycleDisposed = false;
  bool replyPending = false;
  Widget back(BuildContext context, String name) => BackButton(
    onPressed: () {
      backGestures.add(name);
      Navigator.of(context).maybePop();
    },
  );
}

class _SlowRoute extends MaterialPageRoute<void> {
  _SlowRoute({required String name, required super.builder})
    : super(settings: RouteSettings(name: name));
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 900);
}

class _Observer extends NavigatorObserver {
  final popped = <String>[];
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route.settings.name!);
    super.didPop(route, previousRoute);
  }
}

class _Lifecycle extends StatefulWidget {
  const _Lifecycle({
    required this.fixture,
    required this.duplicateBack,
    required this.refusePop,
  });
  final _Fixture fixture;
  final bool duplicateBack;
  final bool refusePop;
  @override
  State<_Lifecycle> createState() => _LifecycleState();
}

class _LifecycleState extends State<_Lifecycle> {
  @override
  void dispose() {
    widget.fixture.lifecycleDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !widget.refusePop,
    child: Scaffold(
      appBar: AppBar(
        leading: widget.fixture.back(context, 'lifecycle'),
        title: const Text('Inner Covers'),
      ),
      body: Column(
        children: [
          if (widget.duplicateBack)
            widget.fixture.back(context, 'ambiguous lifecycle'),
          FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              routeSettings: const RouteSettings(name: 'details'),
              builder: (sheetContext) => FilledButton(
                onPressed: () async {
                  final accepted = await showDialog<bool>(
                    context: sheetContext,
                    routeSettings: const RouteSettings(name: 'acceptance'),
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Post-event inspection'),
                      actions: [
                        FilledButton(
                          onPressed: () async {
                            widget.fixture.replyPending = true;
                            await widget.fixture.reply.future;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          },
                          child: const Text('Record acceptance'),
                        ),
                      ],
                    ),
                  );
                  if (accepted == true && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
                child: const Text('Inspect and accept'),
              ),
            ),
            child: const Text('Cover details'),
          ),
        ],
      ),
    ),
  );
}
