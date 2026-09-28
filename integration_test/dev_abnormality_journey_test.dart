// Runs the actual application against the demo Firebase suite on Android.
// No provider, repository, callable, or success result is substituted.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/quality/presentation/quality_home_screen.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'support/journey_pointer.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready,
  String reason, {
  int seconds = 90,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: reason);
}

// A mounted button is not evidence that startup sync or route/keyboard layout
// has finished. Wait for the real prerequisites, then send exactly one tap.
// This helper never seeds data, retries the action or bypasses its actor guard.
Future<void> openAbnormalityForm(
  WidgetTester tester, {
  String requiredTypeCode = 'SURF-SCALE',
  int readinessSeconds = 90,
}) async {
  final target = find.byKey(const ValueKey('charge-abnormalities-create'));
  expect(target, findsOneWidget);
  final container = ProviderScope.containerOf(tester.element(target));
  final catalogue = container.listen(activeAbnormalityTypesProvider, (_, _) {});
  Rect? previousRect;
  String lastState = 'not checked';
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    await waitFor(
      tester,
      () {
        final types = container.read(activeAbnormalityTypesProvider);
        final actor = CurrentActorAccess.resolve(
          container.read(currentAppUserProvider),
        ).actor;
        final hasType =
            types.asData?.value.any((type) => type.code == requiredTypeCode) ==
            true;
        final elements = target.evaluate().toList();
        final route = elements.length == 1
            ? ModalRoute.of(elements.single)
            : null;
        final routeReady =
            route?.isCurrent == true &&
            route?.animation?.status == AnimationStatus.completed &&
            route?.secondaryAnimation?.status == AnimationStatus.dismissed;
        final keyboardClosed = tester.view.viewInsets.bottom == 0;
        final reachable =
            elements.length == 1 && target.hitTestable().evaluate().length == 1;
        lastState =
            'catalogueLoading=${types.isLoading}, '
            'catalogueError=${types.hasError}, requiredTypePresent=$hasType, '
            'actorAllowed=${actor?.canLogChargeAbnormality == true}, '
            'routeReady=$routeReady, keyboardClosed=$keyboardClosed, '
            'reachable=$reachable';
        if (!hasType ||
            actor?.canLogChargeAbnormality != true ||
            !routeReady ||
            !keyboardClosed ||
            !reachable) {
          previousRect = null;
          return false;
        }
        final rect = tester.getRect(target);
        final stable = previousRect == rect;
        previousRect = rect;
        return stable;
      },
      'Abnormality catalogue, account and visible control must be ready.',
      seconds: readinessSeconds,
    );
    await tester.tap(target);
    await waitFor(
      tester,
      () => find.text('Log charge abnormality').evaluate().isNotEmpty,
      'Real abnormality form opens with synced master data.',
      seconds: readinessSeconds,
    );
  } catch (_) {
    debugPrint('ABNORMALITY_FORM_ENTRY_FAILURE $lastState');
    // This journey runs only with demo data. Preserve visible refusal/guard
    // feedback so a future CI timeout identifies the failed business step.
    debugPrint(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .join(' | '),
    );
    rethrow;
  } finally {
    catalogue.close();
  }
}

Future<void> reveal(WidgetTester tester, Finder target) =>
    showControl(tester, target, maxScrolls: 30, scrollDelta: 250);

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Finder keyedPrefix(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(prefix),
);

Future<void> chooseDropdown(
  WidgetTester tester,
  Finder dropdown,
  Finder item,
) async {
  await reveal(tester, dropdown);
  await tapControl(tester, dropdown);
  await tester.pump(const Duration(milliseconds: 600));
  // The popup lazily builds a long catalogue. Select through its real viewport
  // instead of assuming every fixture is already rendered.
  final menuItem = find.descendant(of: currentRouteLists(), matching: item);
  await reveal(tester, menuItem);
  await tapControl(tester, menuItem);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> goBack(WidgetTester tester) async {
  final reachableBack = find.byTooltip('Back').hitTestable();
  for (
    var attempt = 0;
    attempt < 50 && reachableBack.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    reachableBack.evaluate(),
    isNotEmpty,
    reason: 'The current route must expose a reachable Back button.',
  );
  final back = reachableBack.first;
  final route = ModalRoute.of(tester.element(back));
  expect(route, isNotNull, reason: 'Back must belong to the current route.');
  var removed = false;
  unawaited(
    route!.completed.then<void>((_) {
      removed = true;
    }),
  );
  await tapControl(tester, back);
  for (var attempt = 0; attempt < 50 && !removed; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    removed,
    isTrue,
    reason:
        'The popped route must finish leaving before revealing its destination.',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets(
    'DEV real UI abnormality persists and appears in Quality',
    (tester) async {
      expect(
        crm3UseEmulators,
        isTrue,
        reason: 'This journey must never run against production.',
      );
      final testErrorHandler = FlutterError.onError;
      final testPlatformHandler = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        // Application startup installs Crashlytics handlers. Assertions and
        // framework failures in this test must still reach the test runner.
        FlutterError.onError = testErrorHandler;
        PlatformDispatcher.instance.onError = testPlatformHandler;
      }
      debugPrint('PHONE_STEP startup complete');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'Application must reach sign-in or approved home.',
      );
      expect(Firebase.app().options.projectId, startsWith('demo-'));
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tapControl(tester, find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Seeded approved Operations account must reach home.',
      );

      await tapControl(tester, find.text('More'));
      await tester.pump(const Duration(milliseconds: 400));
      debugPrint('PHONE_STEP More workspace');
      final abnormalityEntry = find.text('Abnormalities');
      await reveal(tester, abnormalityEntry);
      await tapControl(tester, abnormalityEntry);
      debugPrint('PHONE_STEP Abnormalities');
      await waitFor(
        tester,
        () => find.byType(AbnormalitiesHomeScreen).evaluate().isNotEmpty,
        'Open abnormalities through the home screen.',
      );
      final chargeNo = 80000 + DateTime.now().millisecondsSinceEpoch % 10000;
      final observation = 'DEV phone journey $chargeNo';
      await tester.enterText(find.byType(TextField).first, '$chargeNo');
      await tapControl(tester, find.text('Open').first);
      await waitFor(
        tester,
        () => find
            .byKey(const ValueKey('charge-abnormalities-create'))
            .evaluate()
            .isNotEmpty,
        'Operations may log an abnormality.',
      );
      await openAbnormalityForm(tester);
      await chooseDropdown(
        tester,
        keyedPrefix('abnormality-type-'),
        find.textContaining('SURF-SCALE'),
      );
      await reveal(
        tester,
        find.byKey(const ValueKey('abnormality-observation')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('abnormality-observation')),
        observation,
      );
      await chooseDropdown(
        tester,
        find.byKey(const ValueKey('abnormality-asset-class')),
        find.text('Annealing furnace'),
      );
      await waitFor(
        tester,
        () =>
            keyedPrefix('abnormality-asset-seed-class-').evaluate().isNotEmpty,
        'Registered fixture asset loads through real Rules.',
      );
      await chooseDropdown(
        tester,
        keyedPrefix('abnormality-asset-seed-class-'),
        find.textContaining('Furnace 01'),
      );
      await reveal(tester, find.text('Add affected equipment'));
      await tapControl(tester, find.text('Add affected equipment'));
      await tester.pump(const Duration(seconds: 2));
      await reveal(tester, find.text('Log abnormality'));
      await tapControl(tester, find.text('Log abnormality'));
      await waitFor(
        tester,
        () => find.text('Log charge abnormality').evaluate().isEmpty,
        'Validated form must submit successfully.',
      );

      QuerySnapshot<Map<String, dynamic>>? records;
      final end = DateTime.now().add(const Duration(seconds: 90));
      while (DateTime.now().isBefore(end)) {
        records = await FirebaseFirestore.instance
            .collection('charge_abnormalities')
            .where('sourceChargeNo', isEqualTo: chargeNo)
            .get(const GetOptions(source: Source.server));
        if (records.docs.isNotEmpty) break;
        await tester.pump(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(
        records?.docs,
        hasLength(1),
        reason:
            'A local save is insufficient: exactly one canonical server case must exist.',
      );
      final record = records!.docs.single;
      expect(record.data()['observedReason'], observation);
      final warnings = await FirebaseFirestore.instance
          .collection('quality_warnings')
          .where('sourceId', isEqualTo: record.id)
          .get(const GetOptions(source: Source.server));
      expect(
        warnings.docs,
        hasLength(1),
        reason: 'Server acceptance must create the linked Quality warning.',
      );

      // Return via the actual navigation stack and open the normal Quality screen.
      await goBack(tester);
      await goBack(tester);
      await reveal(tester, find.text('Quality'));
      await tapControl(tester, find.text('Quality'));
      await waitFor(
        tester,
        () => find.byType(QualityHomeScreen).evaluate().isNotEmpty,
        'Quality opens through the home screen.',
      );
      await waitFor(
        tester,
        () =>
            find.text('Loading quality warnings').evaluate().isEmpty &&
            find
                .descendant(
                  of: find.byType(QualityHomeScreen),
                  matching: find.byType(ListView),
                )
                .evaluate()
                .isNotEmpty,
        'Quality must load its real warning feed.',
      );
      await reveal(tester, find.textContaining(observation));
      expect(
        find.textContaining(observation),
        findsWidgets,
        reason:
            'The user must see the warning through the real Quality provider.',
      );
      // Reopening the charge must retain the case after the form has been destroyed.
      await goBack(tester);
      await reveal(tester, find.text('Abnormalities'));
      await tapControl(tester, find.text('Abnormalities'));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).first, '$chargeNo');
      await tapControl(tester, find.text('Open').first);
      await waitFor(
        tester,
        () =>
            find.byType(ChargeAbnormalitiesScreen).evaluate().isNotEmpty &&
            find.textContaining(observation).evaluate().isNotEmpty,
        'Reopening the charge must retain its abnormality.',
      );
      debugPrint(
        'DEV_JOURNEY_PASS charge=$chargeNo abnormality=${record.id} warning=${warnings.docs.single.id}',
      );
      final saved = await (await SharedPreferences.getInstance()).setString(
        'crm3.dev.lastVerifiedJourney',
        jsonEncode({
          'project': Firebase.app().options.projectId,
          'chargeNo': chargeNo,
          'abnormalityId': record.id,
          'warningId': warnings.docs.single.id,
          'observation': observation,
        }),
      );
      expect(
        saved,
        isTrue,
        reason: 'Persist the probe for a separate process restart.',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
