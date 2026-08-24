import 'package:crm3_baf_ops/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system Back dismisses the keyboard before leaving a screen', (
    WidgetTester tester,
  ) async {
    final failure = StartupFailure(
      stage: 'firebase_initialize',
      error: StateError('Firebase failed'),
      stackTrace: StackTrace.current,
      occurredAt: DateTime.utc(2026, 5, 14, 12),
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(child: CrmBafApp(startupFailure: failure)),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder:
            (_) => Scaffold(
              body: TextField(
                key: const Key('keyboard-back-field'),
                focusNode: focusNode,
                autofocus: true,
              ),
            ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(find.byKey(const Key('keyboard-back-field')), findsOneWidget);

    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(find.byKey(const Key('keyboard-back-field')), findsOneWidget);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('keyboard-back-field')), findsNothing);
    expect(find.text('App startup failed'), findsOneWidget);
  });
}
