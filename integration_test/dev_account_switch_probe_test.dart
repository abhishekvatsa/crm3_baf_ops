// Diagnostic real-device account switch; no business records are written.
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;
import 'dev_abnormality_journey_test.dart'
    show waitFor, goBack, openAbnormalityForm;
import 'dev_issue_quality_journey_test.dart' as journey;

class _Errors extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint(
      'PHONE_PROVIDER_FAILURE id=${identityHashCode(error)} $provider $error',
    );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (newValue is AsyncValue && newValue.hasError) {
      debugPrint('PHONE_PROVIDER_ASYNC_ERROR $provider ${newValue.error}');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'DEV actual account replacement keeps query errors handled',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      final error = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = (details) {
          debugPrint(
            'PHONE_FRAMEWORK_ERROR id=${identityHashCode(details.exception)} ${details.exception}',
          );
          error?.call(details);
        };
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, 'demo-crm3-baf-ops');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'Reach approved home or sign-in',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await journey.tapControl(tester, find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Approved home',
      );
      ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
        listen: false,
      ).observers.add(_Errors());
      await journey.openQuality(tester);
      await goBack(tester);
      await journey.openMore(tester, 'Raise issue');
      await tester.pump(const Duration(seconds: 1));
      await goBack(tester);
      await journey.openMore(tester, 'Abnormalities');
      await tester.enterText(find.byType(TextField).first, '76575');
      await journey.tapControl(tester, find.text('Open').first);
      await waitFor(
        tester,
        () => find
            .byKey(const ValueKey('charge-abnormalities-create'))
            .evaluate()
            .isNotEmpty,
        'Charge workspace',
      );
      await openAbnormalityForm(tester, requiredTypeCode: 'SURF-SCALE');
      await tester.pump(const Duration(seconds: 1));
      await journey.tapControl(tester, find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 700));
      await goBack(tester);
      await goBack(tester);
      debugPrint('PHONE_SWITCH_PROBE before sign-out');
      await journey.switchActor(tester, 'dev.quality-si@example.invalid');
      await journey.openQuality(tester);
      await goBack(tester);
      await journey.switchActor(tester, 'dev.operations@example.invalid');
      debugPrint('PHONE_SWITCH_PROBE_PASS');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
