// Actual phone screens -> normal services -> local Firebase -> server readback.
// Local DEV: seed tool/dev/seed_quality_phone_actor.py before running.
// CI: use the isolated catalogue plus CRM_QUALITY_SI_EMAIL for its existing SI.
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
const _qualitySiEmail = String.fromEnvironment(
  'CRM_QUALITY_SI_EMAIL',
  defaultValue: 'dev.quality-si@example.invalid',
);
const _operationsEmail = 'dev.operations@example.invalid';

Future<void> _waitForFeedback(WidgetTester tester) => waitFor(
  tester,
  () => find.byType(SnackBar).evaluate().isEmpty,
  'Normal confirmation feedback must dismiss before bottom navigation.',
  seconds: 20,
);

DateTime _physicalRaTime(Map<String, dynamic> record) {
  final assessment = record['assessment'];
  expect(assessment, isA<Map<String, dynamic>>());
  final raw = (assessment as Map<String, dynamic>)['raPerformedAt'];
  expect(raw, isNotNull, reason: 'Explicit physical RA time must persist.');
  final value = raw is Timestamp ? raw.toDate() : DateTime.parse(raw as String);
  expect(value.isAfter(DateTime.now()), isFalse);
  return value.toUtc();
}

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

Future<void> _submitAdjudicationEvidence(
  WidgetTester tester,
  String text,
) async {
  final dialog = find.byType(AlertDialog);
  final evidence = find.descendant(
    of: dialog,
    matching: field('Decision evidence'),
  );
  expect(evidence, findsOneWidget);
  await showControl(tester, evidence);
  // Let the actual Android keyboard finish attaching before replacing the
  // prefilled opinion. Injecting text during attachment can race its old value.
  await tester.tap(evidence.hitTestable());
  await tester.pumpAndSettle();
  await tester.enterText(evidence, text);
  await tester.pump();
  expect(
    tester.widget<TextField>(evidence).controller!.text,
    text,
    reason: 'The active adjudication field must contain the entered evidence.',
  );
  final submit = find.descendant(
    of: dialog,
    matching: find.text('Close warning'),
  );
  await showControl(tester, submit);
  expect(
    tester.widget<TextField>(evidence).controller!.text,
    text,
    reason: 'Decision evidence must survive keyboard dismissal before sending.',
  );
  await tester.tap(submit.hitTestable());
  await tester.pump(const Duration(milliseconds: 500));
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
  await _waitForFeedback(tester);
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
    of: find.byKey(const ValueKey('quality-warning-status-filter')),
    matching: find.text(name),
  );
  await tapControl(tester, control);
}

Future<void> _showWarning(WidgetTester tester, String reason) async {
  final list = find.byKey(const ValueKey('quality-warnings-list'));
  final target = find.descendant(of: list, matching: find.text(reason));
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  // Retained local DEV data can contain more than the first 15 warnings. Use
  // the ordinary Show more action; never widen the canonical provider query.
  for (var step = 0; step < 200; step++) {
    if (target.evaluate().isNotEmpty) {
      await showControl(tester, target);
      return;
    }
    final more = find.descendant(
      of: list,
      matching: find.byKey(const ValueKey('business-list-show-more')),
    );
    if (more.evaluate().isNotEmpty) {
      await tapControl(tester, more);
    } else {
      final before = position.pixels;
      await tester.drag(list, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 250));
      if (position.pixels == before && position.atEdge) break;
    }
  }
  throw TestFailure('Expected warning is absent from the filtered UI: $reason');
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
  await _showWarning(tester, reason);
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
  await _waitForFeedback(tester);
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
  expect(ticket['loggedByUid'], FirebaseAuth.instance.currentUser!.uid);
  expect(abnormality['loggedByUid'], FirebaseAuth.instance.currentUser!.uid);
  final assessment = abnormality['assessment'] as Map;
  expect(assessment['observationKind'], 'processEquipment');
  expect(assessment['candidateCauses'], isEmpty);
  expect(assessment['raPerformedAt'], isNull);
  expect(assessment['postRaResult'], 'notAssessed');
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
  await _waitForFeedback(tester);
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
  DateTime? chosenRaTime;
  if (ra != null) {
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-ra-performed')),
    );
    await enter(tester, 'New RA charge number', '$ra');
    chosenRaTime = await confirmCurrentRaTime(tester);
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
      final assessment = matching.single.data()['assessment'] as Map;
      expect(assessment['observationKind'], 'resultFinding');
      expect(assessment['candidateCauses'], isEmpty);
      expect(assessment['postRaResult'], 'notAssessed');
      if (ra == null) {
        expect(assessment['raPerformedAt'], isNull);
      } else {
        expect(_physicalRaTime(matching.single.data()), chosenRaTime);
      }
    } else {
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  expect(id, isNotNull);
  expect((await read('quality_warnings/abnormality_$id'))['status'], 'open');
  // These terminal/not-applicable RA states are intentionally outside the
  // default Open / RA pending list. Verify visibility through its real All filter.
  await select(
    tester,
    find.byKey(const ValueKey('charge-abnormality-status-filter')),
    'All',
  );
  await tester.scrollUntilVisible(
    find.textContaining(reason).first,
    300,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('charge-abnormalities-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  expect(find.textContaining(reason), findsOneWidget);
  await goBack(tester);
  await goBack(tester);
  debugPrint('PHONE_QUALITY direct=$id charge=$charge ra=$ra accepted');
  return id!;
}

Future<DateTime> confirmCurrentRaTime(WidgetTester tester) async {
  // Synthetic physical work recorded shortly afterwards: choose an explicit
  // earlier minute so a server receipt timestamp cannot satisfy the assertion.
  // Minute precision matches the public picker, including across midnight.
  final earlier = DateTime.now().subtract(const Duration(minutes: 5));
  final selected = DateTime(
    earlier.year,
    earlier.month,
    earlier.day,
    earlier.hour,
    earlier.minute,
  );
  await tapControl(tester, find.byKey(const ValueKey('ra-performed-at')));
  await waitFor(
    tester,
    () => find.byType(DatePickerDialog).evaluate().isNotEmpty,
    'Explicit RA date picker',
  );
  final dateDialog = find.byType(DatePickerDialog);
  final dateLabels = MaterialLocalizations.of(tester.element(dateDialog));
  await tester.tap(find.byTooltip(dateLabels.inputDateModeButtonLabel));
  await tester.pump(const Duration(milliseconds: 250));
  final dateInput = find.descendant(
    of: dateDialog,
    matching: find.byType(TextField),
  );
  expect(dateInput, findsOneWidget);
  await tester.enterText(dateInput, dateLabels.formatCompactDate(selected));
  await tester.tap(
    find.descendant(
      of: dateDialog,
      matching: find.text(dateLabels.okButtonLabel),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await waitFor(
    tester,
    () => find.byType(TimePickerDialog).evaluate().isNotEmpty,
    'Explicit RA time picker',
  );
  final timeDialog = find.byType(TimePickerDialog);
  final timeContext = tester.element(timeDialog);
  final timeLabels = MaterialLocalizations.of(timeContext);
  final use24Hours = MediaQuery.alwaysUse24HourFormatOf(timeContext);
  await tester.tap(find.byTooltip(timeLabels.inputTimeModeButtonLabel));
  await tester.pump(const Duration(milliseconds: 250));
  final timeInputs = find.descendant(
    of: timeDialog,
    matching: find.byType(TextField),
  );
  expect(timeInputs, findsNWidgets(2));
  final selectedTime = TimeOfDay.fromDateTime(selected);
  await tester.enterText(
    timeInputs.first,
    timeLabels.formatHour(selectedTime, alwaysUse24HourFormat: use24Hours),
  );
  await tester.enterText(
    timeInputs.last,
    timeLabels.formatMinute(selectedTime),
  );
  final period = find.descendant(
    of: timeDialog,
    matching: find.text(
      selectedTime.period == DayPeriod.am
          ? timeLabels.anteMeridiemAbbreviation
          : timeLabels.postMeridiemAbbreviation,
    ),
  );
  if (period.evaluate().isNotEmpty) {
    await tester.tap(period);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(
    find.descendant(
      of: timeDialog,
      matching: find.text(timeLabels.okButtonLabel),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(TimePickerDialog), findsNothing);
  return selected.toUtc();
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
      expect(crm3DemoProjectId, startsWith('demo-'));
      expect(Firebase.app().options.projectId, crm3DemoProjectId);
      expect(_qualitySiEmail, endsWith('@example.invalid'));
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
      if (FirebaseAuth.instance.currentUser?.email != _operationsEmail) {
        await switchActor(tester, _operationsEmail);
      }
      final originalActor = FirebaseAuth.instance.currentUser!.uid;
      final originalProfile = await read('users/$originalActor');
      expect(originalProfile['isApproved'], isTrue);
      expect(originalProfile['roles'], ['operations']);
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
      await _showWarning(tester, firstReason);
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
      final chosenIssueRaTime = await confirmCurrentRaTime(tester);
      await tapControl(tester, find.text('Record completion'));
      await awaitRecord(
        tester,
        'quality_warnings/issue_$second',
        (d) => d['status'] == 'closureRequested',
      );
      final recordedRa = await read(
        'charge_abnormalities/issue_quality_$second',
      );
      expect(recordedRa['reannealedToChargeNo'], charge + 1);
      final recordedRaTime = _physicalRaTime(recordedRa);
      expect(recordedRaTime, chosenIssueRaTime);
      expect((recordedRa['assessment'] as Map)['postRaResult'], 'notAssessed');
      await filter(tester, 'Review');
      await _showWarning(tester, raReason);
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
      final independentRaTime = _physicalRaTime(
        await read('charge_abnormalities/$completed'),
      );
      expect((await read('quality_warnings/issue_$first'))['status'], 'open');
      expect(
        (await read('quality_warnings/issue_$second'))['status'],
        'closureRequested',
      );
      await _waitForFeedback(tester);
      await switchActor(tester, _qualitySiEmail);
      final adjudicator = FirebaseAuth.instance.currentUser!.uid;
      expect(adjudicator, isNot(originalActor));
      final adjudicatorProfile = await read('users/$adjudicator');
      expect(adjudicatorProfile['isApproved'], isTrue);
      expect(adjudicatorProfile['roles'], ['si']);
      await openQuality(tester);
      await warningAction(tester, firstReason, 'Adjudicate');
      expect(find.text('Coil found acceptable'), findsOneWidget);
      await _submitAdjudicationEvidence(
        tester,
        'PHONE $charge SI coil examination acceptable; no RA',
      );
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
      await _submitAdjudicationEvidence(
        tester,
        'PHONE $charge SI verifies completed RA ${charge + 1}',
      );
      await awaitRecord(
        tester,
        'quality_warnings/issue_$second',
        (d) => d['status'] == 'closed',
      );
      await filter(tester, 'Closed');
      await _showWarning(tester, firstReason);
      await _showWarning(tester, raReason);
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
      final finalPlain = allCases.docs.singleWhere((d) => d.id == plain).data();
      expect(finalPlain['reannealingStatus'], 'notApplicable');
      expect(finalPlain['reannealedToChargeNo'], isNull);
      expect((finalPlain['assessment'] as Map)['raPerformedAt'], isNull);
      expect((finalPlain['assessment'] as Map)['postRaResult'], 'notAssessed');
      final finalIndependentRa = allCases.docs
          .singleWhere((d) => d.id == completed)
          .data();
      expect(finalIndependentRa['reannealingStatus'], 'completed');
      expect(finalIndependentRa['reannealedToChargeNo'], charge + 2);
      expect(_physicalRaTime(finalIndependentRa), independentRaTime);
      expect(
        (finalIndependentRa['assessment'] as Map)['postRaResult'],
        'notAssessed',
        reason: 'Adjudicating another case must not inspect this RA result.',
      );
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
      expect(_physicalRaTime(completedCase), recordedRaTime);
      expect(
        (completedCase['assessment'] as Map)['postRaResult'],
        'notAssessed',
      );
      for (final record in allCases.docs) {
        expect(record.data()['loggedByUid'], originalActor);
      }
      expect(allWarnings.docs.map((d) => d.id).toSet(), {
        'issue_$first',
        'issue_$second',
        'abnormality_$plain',
        'abnormality_$completed',
      });
      await goBack(tester);
      await _waitForFeedback(tester);
      await switchActor(tester, _operationsEmail);
      expect(FirebaseAuth.instance.currentUser!.uid, originalActor);
      final probe = {
        'projectId': crm3DemoProjectId,
        'operationsUid': originalActor,
        'adjudicatorUid': adjudicator,
        'chargeNo': charge,
        'maintenanceTickets': [first, second],
        'directAbnormalities': [plain, completed],
        'raChargeNos': [charge + 1, charge + 2],
        'issueRaPerformedAt': recordedRaTime.toIso8601String(),
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
