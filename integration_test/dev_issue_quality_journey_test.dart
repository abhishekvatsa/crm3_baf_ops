// Actual phone screens -> normal services -> local Firebase -> server readback.
// Seed tool/dev/seed_quality_phone_actor.py before running this DEV-only test.
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_form.dart';
import 'package:crm3_baf_ops/features/quality/presentation/quality_home_screen.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart'
    show field, keyedPrefix, waitFor, goBack;

const _server = GetOptions(source: Source.server);

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
  await showControl(tester, target);
  // The real, movable safety shortcut can overlap a form control. Reposition
  // it using the user gesture rather than tapping through it or hiding it.
  final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
  if (launcher.evaluate().isNotEmpty &&
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
      reason: 'The safety shortcut must move clear before tapping the control.',
    );
  }
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  await showControl(tester, field(label));
  await tester.enterText(field(label), text);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> select(WidgetTester tester, Finder control, String option) async {
  await tapControl(tester, control);
  final exact = find.descendant(
    of: find.byType(ListView).last,
    matching: find.text(option),
  );
  await tapControl(
    tester,
    exact.evaluate().isNotEmpty
        ? exact
        : find.descendant(
            of: find.byType(ListView).last,
            matching: find.textContaining(option),
          ),
  );
}

Future<void> openMore(WidgetTester tester, String label) async {
  await tester.tap(find.text('More'));
  await tester.pump(const Duration(milliseconds: 500));
  await tapControl(tester, find.text(label));
}

Future<void> openQuality(WidgetTester tester) async {
  await openMore(tester, 'Quality');
  await waitFor(
    tester,
    () =>
        find.byType(QualityHomeScreen).evaluate().isNotEmpty &&
        find.text('Loading quality warnings').evaluate().isEmpty &&
        find.byType(ListView).evaluate().isNotEmpty,
    'Quality must load its actual warning feed.',
  );
}

Future<void> filter(WidgetTester tester, String name) async {
  final control = find.descendant(
    of: find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('SegmentedButton<'),
    ),
    matching: find.text(name),
  );
  await tapControl(tester, control);
}

Finder card(String reason) => find
    .ancestor(
      of: find.text(reason),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_WarningCard',
      ),
    )
    .first;

Future<void> warningAction(
  WidgetTester tester,
  String reason,
  String action,
) async {
  await showControl(tester, find.text(reason));
  final button = find.descendant(of: card(reason), matching: find.text(action));
  await waitFor(tester, () {
    if (button.evaluate().isEmpty) return false;
    final parent = find.ancestor(
      of: button,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    return parent.evaluate().isNotEmpty &&
        (tester.widget(parent.first) as ButtonStyleButton).onPressed != null;
  }, 'The exact warning action $action must be available.');
  await tapControl(tester, button);
}

Future<Map<String, dynamic>> read(String path) async {
  final value = await FirebaseFirestore.instance.doc(path).get(_server);
  expect(value.exists, isTrue, reason: 'Canonical record $path must exist.');
  return value.data()!;
}

Future<Map<String, dynamic>> awaitRecord(
  WidgetTester tester,
  String path,
  bool Function(Map<String, dynamic>) ready,
) async {
  final until = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(until)) {
    final value = await FirebaseFirestore.instance.doc(path).get(_server);
    if (value.exists && ready(value.data()!)) return value.data()!;
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw TestFailure('Server did not reach the expected state for $path');
}

Future<String> raiseIssue(
  WidgetTester tester,
  int charge,
  String reason,
) async {
  await openMore(tester, 'Raise issue');
  await waitFor(
    tester,
    () => find.byType(MaintenanceForm).evaluate().isNotEmpty,
    'Real maintenance issue form must open.',
  );
  await tapControl(tester, find.text('Suspected'));
  await select(
    tester,
    find.byKey(const ValueKey('issue-asset-class')),
    'Annealing furnace',
  );
  await select(tester, keyedPrefix('issue-physical-asset-'), 'Furnace 01');
  await select(
    tester,
    find.byKey(const ValueKey('maintenance-component-intake-state')),
    'Known but not registered',
  );
  await select(tester, keyedPrefix('quality-abnormality-'), 'BURN-FAULT');
  await enter(tester, 'Suspected quality effect', reason);
  await enter(tester, 'Component name / unlisted component', 'Furnace seal');
  await enter(tester, 'Fault description', '$reason: physical seal fault');
  await enter(tester, 'Charge number', '$charge');
  await tapControl(tester, find.text('Submit Issue'));
  await waitFor(
    tester,
    () => find.byType(MaintenanceForm).evaluate().isEmpty,
    'Issue submission must leave the completed form.',
  );
  String? ticketId;
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (ticketId == null && DateTime.now().isBefore(end)) {
    final records = await FirebaseFirestore.instance
        .collection('maintenance_records')
        .where('chargeNoAtEvent', isEqualTo: charge)
        .get(_server);
    final matching = records.docs.where(
      (d) => d.data()['description'] == '$reason: physical seal fault',
    );
    if (matching.isNotEmpty) {
      expect(matching, hasLength(1));
      ticketId = matching.single.id;
    } else {
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  expect(
    ticketId,
    isNotNull,
    reason: 'A local pending save is not server acceptance.',
  );
  final warning = await read('quality_warnings/issue_$ticketId');
  final abnormality = await read(
    'charge_abnormalities/issue_quality_$ticketId',
  );
  final ticket = await read('maintenance_records/$ticketId');
  expect(warning['sourceId'], ticketId);
  expect(warning['sourceType'], 'issue');
  expect(warning['sourceChargeNo'], charge);
  expect(warning['status'], 'open');
  expect(abnormality['linkedTicketFirestoreId'], ticketId);
  expect(abnormality['reannealingStatus'], 'pendingDecision');
  expect(ticket['qualityWarningId'], 'issue_$ticketId');
  expect(ticket['qualityAbnormalityId'], 'issue_quality_$ticketId');
  expect(ticket['isResolved'], isFalse);
  debugPrint(
    'PHONE_QUALITY issue=$ticketId charge=$charge reason=$reason accepted',
  );
  return ticketId!;
}

Future<String> logAbnormality(
  WidgetTester tester,
  int charge,
  String reason, {
  int? ra,
}) async {
  await openMore(tester, 'Abnormalities');
  await tester.enterText(find.byType(TextField).first, '$charge');
  await tester.tap(find.text('Open').first);
  await waitFor(
    tester,
    () => find
        .byKey(const ValueKey('charge-abnormalities-create'))
        .evaluate()
        .isNotEmpty,
    'Charge workspace must open.',
  );
  await tapControl(
    tester,
    find.byKey(const ValueKey('charge-abnormalities-create')),
  );
  await waitFor(
    tester,
    () => find.text('Log charge abnormality').evaluate().isNotEmpty,
    'Real abnormality form must open.',
  );
  await select(tester, keyedPrefix('abnormality-type-'), 'SURF-SCALE');
  await showControl(
    tester,
    find.byKey(const ValueKey('abnormality-observation')),
  );
  await tester.enterText(
    find.byKey(const ValueKey('abnormality-observation')),
    reason,
  );
  await select(
    tester,
    find.byKey(const ValueKey('abnormality-asset-class')),
    'Annealing furnace',
  );
  await select(
    tester,
    keyedPrefix('abnormality-asset-seed-class-'),
    'Furnace 01',
  );
  await tapControl(tester, find.text('Add affected equipment'));
  await select(
    tester,
    find.byKey(const ValueKey('abnormality-ra-decision')),
    ra == null ? 'Not Applicable' : 'Required',
  );
  if (ra != null) {
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-ra-performed')),
    );
    await enter(tester, 'New RA charge number', '$ra');
    await confirmCurrentRaTime(tester);
  }
  await tapControl(tester, find.text('Log abnormality'));
  await waitFor(
    tester,
    () => find.text('Log charge abnormality').evaluate().isEmpty,
    'Abnormality submission must complete.',
  );
  String? id;
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (id == null && DateTime.now().isBefore(end)) {
    final records = await FirebaseFirestore.instance
        .collection('charge_abnormalities')
        .where('sourceChargeNo', isEqualTo: charge)
        .get(_server);
    final matching = records.docs.where(
      (d) => d.data()['observedReason'] == reason,
    );
    if (matching.isNotEmpty) {
      expect(matching, hasLength(1));
      id = matching.single.id;
      expect(
        matching.single.data()['reannealingStatus'],
        ra == null ? 'notApplicable' : 'completed',
      );
      expect(matching.single.data()['reannealedToChargeNo'], ra);
    } else {
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  expect(id, isNotNull);
  expect((await read('quality_warnings/abnormality_$id'))['status'], 'open');
  await showControl(tester, find.textContaining(reason).first);
  await goBack(tester);
  await goBack(tester);
  debugPrint('PHONE_QUALITY direct=$id charge=$charge ra=$ra accepted');
  return id!;
}

Future<void> confirmCurrentRaTime(WidgetTester tester) async {
  await tapControl(tester, find.byKey(const ValueKey('ra-performed-at')));
  await waitFor(
    tester,
    () => find.byType(DatePickerDialog).evaluate().isNotEmpty,
    'Explicit RA date picker',
  );
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('OK'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await waitFor(
    tester,
    () => find.byType(TimePickerDialog).evaluate().isNotEmpty,
    'Explicit RA time picker',
  );
  await tester.tap(
    find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.text('OK'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> switchActor(WidgetTester tester, String email) async {
  // Sign out through the actual UI, pumping frames while cleanup runs so the
  // normal signing-out gate can tear down the old account's screen listeners.
  await tester.tap(find.text('Home'));
  await tester.pump(const Duration(milliseconds: 400));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
    listen: false,
  );
  await waitFor(
    tester,
    () => !container
        .read(localRecoverySessionGuardProvider)
        .isRecoveryProtectionActive,
    'Normal startup recovery check must finish before requesting sign-out',
  );
  await tapControl(
    tester,
    find.byKey(const ValueKey('dashboard-profile-action')),
  );
  await tapControl(tester, find.text('Sign Out'));
  debugPrint(
    'PHONE_QUALITY signout requested; actor=${FirebaseAuth.instance.currentUser?.email}; visible=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().join(' | ')}',
  );
  try {
    await waitFor(
      tester,
      () => find.text('Sign in with Google').evaluate().isNotEmpty,
      'Normal sign-out must finish before changing the test actor.',
    );
  } catch (_) {
    debugPrint(
      'PHONE_QUALITY signout timed out; actor=${FirebaseAuth.instance.currentUser?.email}; visible=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().join(' | ')}',
    );
    rethrow;
  }
  await tester.runAsync(
    () => FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: 'emulator-local-only',
    ),
  );
  await waitFor(
    tester,
    () => find.byType(HomeScreen).evaluate().isNotEmpty,
    'The new actor must pass the real online approval gate.',
  );
  expect(FirebaseAuth.instance.currentUser?.email, email);
  debugPrint('PHONE_QUALITY account transition accepted email=$email');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'DEV maintenance Quality, adjudication, RA and independent same-charge observations',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      final error = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = error;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, 'demo-crm3-baf-ops');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'Reach the real approval gate.',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Approved Operations home.',
      );
      if (FirebaseAuth.instance.currentUser?.email !=
          'dev.operations@example.invalid') {
        await switchActor(tester, 'dev.operations@example.invalid');
      }
      var charge = 70000 + DateTime.now().millisecondsSinceEpoch % 10000;
      while ((await FirebaseFirestore.instance
              .collection('charge_abnormalities')
              .where('sourceChargeNo', isEqualTo: charge)
              .get(_server))
          .docs
          .isNotEmpty) {
        charge++;
      }
      final firstReason = 'PHONE $charge maintenance acceptable';
      final raReason = 'PHONE $charge maintenance RA';
      debugPrint('PHONE_QUALITY starting charge=$charge');
      final first = await raiseIssue(tester, charge, firstReason);
      final second = await raiseIssue(tester, charge, raReason);

      await openQuality(tester);
      await showControl(tester, find.text(firstReason));
      expect(
        find.descendant(
          of: card(firstReason),
          matching: find.text('Adjudicate'),
        ),
        findsNothing,
        reason: 'Operations must not gain SI adjudication authority.',
      );
      await warningAction(tester, raReason, 'RA required');
      await enter(
        tester,
        'Decision evidence',
        'PHONE $charge RA required after coil examination',
      );
      await tapControl(tester, find.text('Submit'));
      await awaitRecord(
        tester,
        'charge_abnormalities/issue_quality_$second',
        (d) => d['reannealingStatus'] == 'required',
      );
      await warningAction(tester, raReason, 'Record RA completion');
      await enter(tester, 'New RA charge number', '${charge + 1}');
      await enter(
        tester,
        'Completion evidence',
        'PHONE $charge completed as charge ${charge + 1}',
      );
      await confirmCurrentRaTime(tester);
      await tapControl(tester, find.text('Record completion'));
      await awaitRecord(
        tester,
        'quality_warnings/issue_$second',
        (d) => d['status'] == 'closureRequested',
      );
      expect(
        (await read(
          'charge_abnormalities/issue_quality_$second',
        ))['reannealedToChargeNo'],
        charge + 1,
      );
      await filter(tester, 'Review');
      await showControl(tester, find.text(raReason));
      expect(
        find.descendant(
          of: card(raReason),
          matching: find.textContaining('RA completion submitted for review'),
        ),
        findsOneWidget,
      );
      debugPrint(
        'PHONE_QUALITY RA completion verified charge=$charge target=${charge + 1}',
      );
      await goBack(tester);

      final plain = await logAbnormality(
        tester,
        charge,
        'PHONE $charge independent without RA',
      );
      final completed = await logAbnormality(
        tester,
        charge,
        'PHONE $charge independent with RA',
        ra: charge + 2,
      );
      expect((await read('quality_warnings/issue_$first'))['status'], 'open');
      expect(
        (await read('quality_warnings/issue_$second'))['status'],
        'closureRequested',
      );
      await switchActor(tester, 'dev.quality-si@example.invalid');
      await openQuality(tester);
      await warningAction(tester, firstReason, 'Adjudicate');
      expect(find.text('Coil found acceptable'), findsOneWidget);
      await enter(
        tester,
        'Decision evidence',
        'PHONE $charge SI coil examination acceptable; no RA',
      );
      await tapControl(tester, find.text('Close warning'));
      await awaitRecord(
        tester,
        'quality_warnings/issue_$first',
        (d) => d['status'] == 'closed',
      );
      expect(
        (await read(
          'charge_abnormalities/issue_quality_$first',
        ))['reannealingStatus'],
        'notRequired',
      );
      await filter(tester, 'Review');
      await warningAction(tester, raReason, 'Adjudicate');
      expect(find.text('Re-annealing completed'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('RA charge number')).readOnly,
        isTrue,
      );
      expect(
        tester.widget<TextField>(field('RA charge number')).controller!.text,
        '${charge + 1}',
      );
      await enter(
        tester,
        'Decision evidence',
        'PHONE $charge SI verifies completed RA ${charge + 1}',
      );
      await tapControl(tester, find.text('Close warning'));
      await awaitRecord(
        tester,
        'quality_warnings/issue_$second',
        (d) => d['status'] == 'closed',
      );
      await filter(tester, 'Closed');
      await showControl(tester, find.text(firstReason));
      await showControl(tester, find.text(raReason));
      for (final id in [first, second]) {
        expect(
          (await read('maintenance_records/$id'))['isResolved'],
          isFalse,
          reason:
              'Quality adjudication must not pretend physical maintenance is finished.',
        );
      }
      final allCases = await FirebaseFirestore.instance
          .collection('charge_abnormalities')
          .where('sourceChargeNo', isEqualTo: charge)
          .get(_server);
      expect(allCases.docs.map((d) => d.id).toSet(), {
        'issue_quality_$first',
        'issue_quality_$second',
        plain,
        completed,
      });
      final allWarnings = await FirebaseFirestore.instance
          .collection('quality_warnings')
          .where('sourceChargeNo', isEqualTo: charge)
          .get(_server);
      expect(allWarnings.docs, hasLength(4));
      expect(
        (await read('quality_warnings/abnormality_$plain'))['status'],
        'open',
      );
      expect(
        (await read('quality_warnings/abnormality_$completed'))['status'],
        'open',
      );
      final acceptableWarning = await read('quality_warnings/issue_$first');
      final raWarning = await read('quality_warnings/issue_$second');
      final adjudicator = FirebaseAuth.instance.currentUser!.uid;
      expect(acceptableWarning['closureDisposition'], 'coilFoundAcceptable');
      expect(acceptableWarning['closedByUid'], adjudicator);
      expect(
        acceptableWarning['decisionReason'],
        'PHONE $charge SI coil examination acceptable; no RA',
      );
      expect(raWarning['closureDisposition'], 'reannealingCompleted');
      expect(raWarning['closedByUid'], adjudicator);
      expect(raWarning['linkedReannealingChargeNos'], [charge + 1]);
      expect(
        raWarning['decisionReason'],
        'PHONE $charge SI verifies completed RA ${charge + 1}',
      );
      final completedCase = await read(
        'charge_abnormalities/issue_quality_$second',
      );
      expect(completedCase['reannealingStatus'], 'completed');
      expect(completedCase['reannealedToChargeNo'], charge + 1);
      await goBack(tester);
      await switchActor(tester, 'dev.operations@example.invalid');
      final probe = {
        'chargeNo': charge,
        'maintenanceTickets': [first, second],
        'directAbnormalities': [plain, completed],
        'raChargeNos': [charge + 1, charge + 2],
        'status': 'passed',
      };
      await (await SharedPreferences.getInstance()).setString(
        'crm3.dev.lastIssueQualityJourney',
        jsonEncode(probe),
      );
      debugPrint('DEV_ISSUE_QUALITY_PASS ${jsonEncode(probe)}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
