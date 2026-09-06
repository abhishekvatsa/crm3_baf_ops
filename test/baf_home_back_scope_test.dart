import 'package:crm3_baf_ops/core/widgets/baf_home_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Back from another workspace tab returns to Home', (
    WidgetTester tester,
  ) async {
    var returnedHome = false;

    await tester.pumpWidget(
      MaterialApp(
        home: BafHomeBackScope(
          isHomeSelected: false,
          onReturnHome: () => returnedHome = true,
          child: const Scaffold(body: Text('Issues tab')),
        ),
      ),
    );

    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pump();

    expect(returnedHome, isTrue);
    expect(find.text('Exit CRM-III BAF Ops?'), findsNothing);
  });

  testWidgets('Back on Home confirms before exiting', (
    WidgetTester tester,
  ) async {
    var exitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BafHomeBackScope(
          isHomeSelected: true,
          onReturnHome: () {},
          onExitApp: () async => exitCount += 1,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Exit CRM-III BAF Ops?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(exitCount, 0);
    expect(find.text('Home'), findsOneWidget);

    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit app'));
    await tester.pumpAndSettle();
    expect(exitCount, 1);
  });

  testWidgets('an active form owns Back before the Home exit guard', (
    WidgetTester tester,
  ) async {
    var activeFormBackCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BafHomeBackScope(
          isHomeSelected: true,
          onReturnHome: () {},
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    final context = tester.element(find.text('Home'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Form(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) activeFormBackCount += 1;
            },
            child: const Text('Active work'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(activeFormBackCount, 1);
    expect(find.text('Active work'), findsOneWidget);
    expect(find.text('Exit CRM-III BAF Ops?'), findsNothing);
  });

  testWidgets('an ordinary page returns toward Home without an exit prompt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BafHomeBackScope(
          isHomeSelected: true,
          onReturnHome: () {},
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    final context = tester.element(find.text('Home'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Ordinary page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(await WidgetsBinding.instance.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Ordinary page'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Exit CRM-III BAF Ops?'), findsNothing);
  });

  testWidgets(
    'predictive Back from another workspace tab returns to Home',
    (WidgetTester tester) async {
      var returnedHome = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BafHomeBackScope(
            isHomeSelected: false,
            onReturnHome: () => returnedHome = true,
            child: const Scaffold(body: Text('Work tab')),
          ),
        ),
      );

      await _sendBackGesture(tester, 'startBackGesture', _startArguments);
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();

      expect(returnedHome, isTrue);
      expect(find.text('Exit CRM-III BAF Ops?'), findsNothing);
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
