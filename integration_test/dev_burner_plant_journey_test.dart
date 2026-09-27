// Real device UI and authenticated emulator readback. No repository overrides.
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/burner_condition_round_screen.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_component_condition_audit_screen.dart';
import 'package:crm3_baf_ops/features/directives/presentation/directives_screen.dart';
import 'package:crm3_baf_ops/features/reports/presentation/burner_reliability_screen.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show field, waitFor, goBack;
import 'dev_issue_quality_journey_test.dart'
    show
        showControl,
        tapControl,
        enter,
        select,
        openMore,
        read,
        awaitRecord,
        switchActor;

const _server = GetOptions(source: Source.server);
const _furnaceId = 'seed-asset-furnace-01';

DateTime _instant(Object? value) => value is Timestamp
    ? value.toDate().toUtc()
    : DateTime.parse(value as String).toUtc();

Future<void> _home(WidgetTester tester) async {
  while (find.byType(HomeScreen).evaluate().isEmpty) {
    await goBack(tester);
  }
  await tester.tap(find.text('Home'));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<int> _verifyPhysicalPopulation(WidgetTester tester) async {
  final db = FirebaseFirestore.instance;
  final classes = await db.collection('asset_classes').get(_server);
  final assets = await db.collection('asset_instances').get(_server);
  final covers = await db.collection('inner_cover_profiles').get(_server);
  final coverClasses = classes.docs
      .where((row) => row.data()['legacyAssetTypeKey'] == 'innerCover')
      .map((row) => row.id)
      .toSet();
  final physicalAssets = assets.docs.where(
    (row) =>
        row.data()['status'] == 'active' &&
        !coverClasses.contains(row.data()['assetClassId']),
  );
  final physicalCovers = covers.docs.where(
    (row) => !const {
      'disposed',
      'fullyConsumedAsDonor',
    }.contains(row.data()['lifecycleState']),
  );
  final expected = physicalAssets.length + physicalCovers.length;
  expect(expected, greaterThan(0));
  await waitFor(
    tester,
    () {
      if (find.byType(PlantOverviewPanel).evaluate().isEmpty) return false;
      final panel = tester.widget<PlantOverviewPanel>(
        find.byType(PlantOverviewPanel),
      );
      return panel.overview.hasValue &&
          panel.overview.requireValue.total == expected;
    },
    'Home must count the complete physical register, including serial covers.',
  );
  final panel = tester.widget<PlantOverviewPanel>(
    find.byType(PlantOverviewPanel),
  );
  expect(panel.overview.requireValue.total, expected);
  await tapControl(
    tester,
    find
        .descendant(
          of: find.byType(PlantOverviewPanel),
          matching: find.textContaining('Plant condition'),
        )
        .first,
  );
  await waitFor(
    tester,
    () => find.byType(AssetConditionBoard).evaluate().isNotEmpty,
    'The ordinary plant condition board must open.',
  );
  await showControl(tester, find.text('$expected recorded assets'));
  expect(find.text('$expected recorded assets'), findsWidgets);
  debugPrint(
    'DEV_PLANT_POPULATION ${jsonEncode({'activePhysicalAssets': physicalAssets.length, 'serialCoversStillPhysicallyPresent': physicalCovers.length, 'expectedTotal': expected, 'homeAndBoardAgree': true})}',
  );
  await _home(tester);
  return expected;
}

Finder _position(int number) => find.byKey(ValueKey<int>(number));
Future<void> _bulk<T>(WidgetTester tester, String tooltip, String label) async {
  await tapControl(tester, find.byType(PopupMenuButton<T>));
  final option = find.widgetWithText(PopupMenuItem<T>, label);
  await waitFor(
    tester,
    () => option.evaluate().isNotEmpty,
    'The $tooltip menu must be open.',
  );
  await tester.tap(option);
  await waitFor(
    tester,
    () => find.byType(PopupMenuItem<T>).evaluate().isEmpty,
    'The bulk selection menu must close before another control is used.',
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _positionField(int number, String label) =>
    find.descendant(of: _position(number), matching: field(label));

Future<Map<String, dynamic>> _roundByNote(
  WidgetTester tester,
  String note,
) async {
  final until = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(until)) {
    final snapshot = await FirebaseFirestore.instance
        .collection('burner_condition_rounds')
        .where('roundNote', isEqualTo: note)
        .get(_server);
    if (snapshot.docs.isNotEmpty) {
      expect(snapshot.docs, hasLength(1));
      return snapshot.docs.single.data();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw TestFailure('Round was not accepted by the actual Functions emulator.');
}

Future<Map<String, dynamic>> _closedDirective(
  WidgetTester tester,
  String id,
) async {
  final until = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(until)) {
    final failure = find.textContaining('Failed to close directive:');
    if (failure.evaluate().isNotEmpty) {
      throw TestFailure(tester.widget<Text>(failure.first).data!);
    }
    final current = await read('directives/$id');
    if (current['status'] == 'closed') return current;
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('The directive closure was not accepted: $id');
}

Finder _directiveCard(String id) => find.byWidgetPredicate((widget) {
  if (widget.runtimeType.toString() != '_DirectiveCard') return false;
  return (widget as dynamic).directive.firestoreId == id;
});

Future<void> _directiveAction(
  WidgetTester tester,
  String id,
  String label,
) async {
  final button = find.descendant(
    of: _directiveCard(id),
    matching: find.text(label),
  );
  await showControl(tester, _directiveCard(id));
  await waitFor(
    tester,
    () => button.evaluate().isNotEmpty,
    'The exact saved directive must offer $label.',
  );
  await tapControl(tester, button);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real plant counts and burner round to I&A compliance',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      final flutterError = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = flutterError;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, 'demo-crm3-baf-ops');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'Normal access gate',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Approved home',
      );
      if (FirebaseAuth.instance.currentUser?.email !=
          'dev.operations@example.invalid') {
        await switchActor(tester, 'dev.operations@example.invalid');
      }
      await _home(tester);
      final population = await _verifyPhysicalPopulation(tester);
      await openMore(tester, 'Burner reliability');
      await waitFor(
        tester,
        () => find.byType(BurnerReliabilityScreen).evaluate().isNotEmpty,
        'Normal burner reliability screen',
      );
      await tapControl(tester, find.byTooltip('Record burner round'));
      await waitFor(
        tester,
        () =>
            find.byType(BurnerConditionRoundScreen).evaluate().isNotEmpty &&
            find.byType(DropdownButtonFormField<String>).evaluate().isNotEmpty,
        'Governed burner form with an unambiguous Furnace register',
      );
      await select(
        tester,
        find.byType(DropdownButtonFormField<String>).first,
        'Furnace 01 (1)',
      );
      await _bulk<BurnerRoundFlameObservation>(
        tester,
        'Apply flame observation to all burners',
        'Flame seen',
      );
      await _bulk<BurnerUvCondition>(
        tester,
        'Apply UV condition to all burners',
        'In service',
      );
      await tapControl(
        tester,
        find.descendant(
          of: _position(1),
          matching: find.text('Red-hot burner block observed'),
        ),
      );
      await showControl(tester, _positionField(1, 'Flame signal (optional)'));
      await tester.enterText(
        _positionField(1, 'Flame signal (optional)'),
        '1.2',
      );
      await showControl(tester, _positionField(2, 'Flame signal (optional)'));
      await tester.enterText(
        _positionField(2, 'Flame signal (optional)'),
        '6.4',
      );
      final note =
          'DEV burner phone validation ${DateTime.now().microsecondsSinceEpoch}';
      await enter(tester, 'Round note (optional)', note);
      await tapControl(tester, find.text('Record round'));
      await waitFor(
        tester,
        () => find.byType(BurnerConditionRoundScreen).evaluate().isEmpty,
        'Round must leave the form only after server acceptance.',
      );
      final round = await _roundByNote(tester, note);
      final roundId = round['roundId'] as String;
      final directiveId = round['directiveId'] as String;
      expect(round['assetInstanceId'], _furnaceId);
      expect(round['redHotPositions'], [1]);
      expect(round['directivePositions'], [1]);
      expect(round['observations'], hasLength(8));
      expect(round['uvObservations'], hasLength(8));
      expect(
        (round['uvObservations'] as List).first['condition'],
        'serviceable',
      );
      final directive = await read('directives/$directiveId');
      expect(directive['status'], 'open');
      expect(directive['priority'], 'critical');
      expect(directive['directedTo'], 'seniorInstrumentation');
      expect(
        jsonDecode(directive['metadataJson'] as String)['sourceRoundId'],
        roundId,
      );
      await tapControl(tester, find.byTooltip('Open Furnace condition matrix'));
      await waitFor(
        tester,
        () => find
            .byKey(const ValueKey('block-seed-asset-furnace-01-1'))
            .evaluate()
            .isNotEmpty,
        'Furnace matrix must accept the actual stored round.',
      );
      expect(find.byType(FurnaceComponentConditionAuditScreen), findsOneWidget);
      final blockCell = find.byKey(
        const ValueKey('block-seed-asset-furnace-01-1'),
      );
      expect(
        find.descendant(
          of: blockCell,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Tooltip && widget.message == 'Red hot observed',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('could not be verified'), findsNothing);
      await _home(tester);
      await switchActor(
        tester,
        'dev.usability-seniorinstrumentation@example.invalid',
      );
      await openMore(tester, 'Directives');
      await waitFor(
        tester,
        () => find.byType(DirectivesScreen).evaluate().isNotEmpty,
        'Recipient directives must load.',
      );
      await _directiveAction(tester, directiveId, 'Acknowledge');
      await awaitRecord(
        tester,
        'directives/$directiveId',
        (row) =>
            row['acknowledgedByUid'] == FirebaseAuth.instance.currentUser!.uid,
      );
      await _directiveAction(tester, directiveId, 'Close Directive');
      await select(
        tester,
        find
            .byType(
              DropdownButtonFormField<BurnerDirectiveComplianceDisposition>,
            )
            .first,
        'UV melted',
      );
      await enter(
        tester,
        'Remarks (optional)',
        'DEV trial: isolated burner; melted UV remains for replacement.',
      );
      await tapControl(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Close'),
        ),
      );
      final closed = await _closedDirective(tester, directiveId);
      expect(closed['closedByUid'], FirebaseAuth.instance.currentUser!.uid);
      final current = await read('burner_condition_current/$_furnaceId');
      final compliance = await read(
        'burner_condition_rounds/${current['roundId']}',
      );
      expect(compliance['evidenceKind'], 'directiveCompliance');
      expect(compliance['baselineRoundId'], roundId);
      final observations = compliance['observations'] as List;
      expect(
        observations.first['redHotObserved'],
        isTrue,
        reason:
            'Isolation must not falsely claim the burner block was repaired.',
      );
      expect(observations.first['flameObservation'], 'notOperating');
      expect(observations.first['microampReading'], isNull);
      expect(observations[1]['microampReading'], 6.4);
      expect(
        (compliance['uvObservations'] as List).first['condition'],
        'melted',
      );
      final inherited =
          (compliance['evidenceProvenance'] as Map)['burners.2.microampReading']
              as Map;
      expect(inherited['kind'], 'inherited');
      expect(inherited['sourceRoundId'], roundId);
      expect(_instant(inherited['observedAt']), _instant(round['observedAt']));
      await _home(tester);
      debugPrint(
        'DEV_BURNER_PLANT_PASS ${jsonEncode({'physicalPopulation': population, 'roundId': roundId, 'directiveId': directiveId, 'complianceRoundId': current['roundId'], 'redHotAndUvDamageRemain': true, 'untouchedReadingAgePreserved': true, 'status': 'passed'})}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
