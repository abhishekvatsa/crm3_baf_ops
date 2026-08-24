import 'package:crm3_baf_ops/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'system Back dismisses the keyboard and forwards a rapid second press',
    (WidgetTester tester) async {
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

      expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('keyboard-back-field')), findsNothing);
      expect(find.text('App startup failed'), findsOneWidget);
    },
  );

  testWidgets(
    'predictive Back dismisses the keyboard before popping the route',
    (WidgetTester tester) async {
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
                  key: const Key('predictive-keyboard-back-field'),
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
      await _sendBackGesture(tester, 'startBackGesture', _startArguments);
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isFalse);
      expect(
        find.byKey(const Key('predictive-keyboard-back-field')),
        findsOneWidget,
      );

      await _sendBackGesture(tester, 'startBackGesture', _startArguments);
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('predictive-keyboard-back-field')),
        findsNothing,
      );
      expect(find.text('App startup failed'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'cancelled predictive Back keeps the editor focused',
    (WidgetTester tester) async {
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
                  key: const Key('cancelled-predictive-back-field'),
                  focusNode: focusNode,
                  autofocus: true,
                ),
              ),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();

      await _sendBackGesture(tester, 'startBackGesture', _startArguments);
      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
      expect(
        find.byKey(const Key('cancelled-predictive-back-field')),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

const Map<String, dynamic> _startArguments = <String, dynamic>{
  'touchOffset': <double>[5, 300],
  'progress': 0.0,
  'swipeEdge': 0,
};

Future<void> _sendBackGesture(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
}
