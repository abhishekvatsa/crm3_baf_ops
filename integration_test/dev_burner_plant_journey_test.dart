// Real Android UI and authenticated emulator readback. No repository overrides.
// Fresh CI needs only the governed Furnace 01 registry and approved Operations
// and seniorInstrumentation actors. No round/directive/compliance is pre-seeded.
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
import 'package:crm3_baf_ops/features/directives/data/remote_operational_directive_reader.dart';
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
const _operationsEmail = 'dev.operations@example.invalid';
const _instrumentationEmail =
    'dev.usability-seniorinstrumentation@example.invalid';
const _freshCi = crm3DemoProjectId == 'demo-crm3-ci-journeys';

void _verifyEnvironment() {
  expect(crm3UseEmulators, isTrue);
  expect(
    crm3DemoProjectId,
    isIn(const ['demo-crm3-baf-ops', 'demo-crm3-ci-journeys']),
    reason:
        'Only the existing local DEV or isolated CI namespace is supported.',
  );
  if (_freshCi) {
    expect(crm3AuthEmulatorPort, 19099);
    expect(crm3FirestoreEmulatorPort, 18080);
    expect(crm3FunctionsEmulatorPort, 15001);
  }
}

Future<Map<String, Map<String, dynamic>>> _furnaceDocuments(
  String collection,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection(collection)
      .where('assetInstanceId', isEqualTo: _furnaceId)
      .get(_server);
  return {for (final document in snapshot.docs) document.id: document.data()};
}

Future<Map<String, Map<String, Map<String, dynamic>>>>
_installationEvidence() async => {
  for (final collection in const [
    'burner_block_lifecycle_events',
    'burner_block_lifecycle_current',
    'uv_detector_lifecycle_events',
    'uv_detector_lifecycle_current',
  ])
    collection: await _furnaceDocuments(collection),
};

void _expectProvenance(
  Map<String, dynamic> round,
  String field, {
  required String kind,
  required String sourceRoundId,
  required String actorUid,
  required Object? observedAt,
}) {
  final evidence = (round['evidenceProvenance'] as Map)[field] as Map;
  expect(evidence['kind'], kind, reason: field);
  expect(evidence['sourceRoundId'], sourceRoundId, reason: field);
  expect(evidence['observerUid'], actorUid, reason: field);
  expect(_instant(evidence['observedAt']), _instant(observedAt), reason: field);
}

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
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'real plant counts and burner round to I&A compliance',
    (tester) async {
      _verifyEnvironment();
      final flutterError = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = flutterError;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, crm3DemoProjectId);
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
      if (FirebaseAuth.instance.currentUser?.email != _operationsEmail) {
        await switchActor(tester, _operationsEmail);
      }
      final operationsUid = FirebaseAuth.instance.currentUser!.uid;
      final operations = await read('users/$operationsUid');
      expect(operations['isApproved'], isTrue);
      expect(operations['roles'], ['operations']);
      final priorRounds = await _furnaceDocuments('burner_condition_rounds');
      final priorInstallations = await _installationEvidence();
      if (_freshCi) {
        expect(
          priorRounds,
          isEmpty,
          reason: 'CI must create its first burner round through the real UI.',
        );
        expect(
          (await FirebaseFirestore.instance
                  .doc('burner_condition_current/$_furnaceId')
                  .get(_server))
              .exists,
          isFalse,
        );
        for (final records in priorInstallations.values) {
          expect(
            records,
            isEmpty,
            reason: 'No installation is needed or seeded.',
          );
        }
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
      expect(round['evidenceKind'], 'inspection');
      expect(round['recordedByUid'], operationsUid);
      expect(round['assetInstanceId'], _furnaceId);
      expect(round['redHotPositions'], [1]);
      expect(round['directivePositions'], [1]);
      expect(round['observations'], hasLength(8));
      expect(round['uvObservations'], hasLength(8));
      expect(
        (round['observations'] as List).map((row) => row['position']),
        orderedEquals(List.generate(8, (index) => index + 1)),
      );
      expect((round['observations'] as List).first['microampReading'], 1.2);
      _expectProvenance(
        round,
        'burners.2.microampReading',
        kind: 'observed',
        sourceRoundId: roundId,
        actorUid: operationsUid,
        observedAt: round['observedAt'],
      );
      expect(
        (await read('burner_condition_current/$_furnaceId'))['roundId'],
        roundId,
      );
      expect(
        (round['uvObservations'] as List).first['condition'],
        'serviceable',
      );
      final directive = await read('directives/$directiveId');
      final parsedOpen = readRemoteOperationalDirective(
        directive,
        documentId: directiveId,
      );
      expect(parsedOpen.status.name, 'open');
      expect(directive['status'], 'open');
      expect(directive['priority'], 'critical');
      expect(directive['directedTo'], 'seniorInstrumentation');
      final metadata = jsonDecode(directive['metadataJson'] as String) as Map;
      expect(metadata['sourceRoundId'], roundId);
      expect(metadata['burnerPositions'], [1]);
      expect(metadata['automaticPlantActuation'], isFalse);
      expect(directiveId, 'burner_round_red_hot_$roundId');
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
      await switchActor(tester, _instrumentationEmail);
      final instrumentationUid = FirebaseAuth.instance.currentUser!.uid;
      expect(instrumentationUid, isNot(operationsUid));
      final instrumentation = await read('users/$instrumentationUid');
      expect(instrumentation['isApproved'], isTrue);
      expect(instrumentation['roles'], ['seniorInstrumentation']);
      await openMore(tester, 'Directives');
      await waitFor(
        tester,
        () => find.byType(DirectivesScreen).evaluate().isNotEmpty,
        'Recipient directives must load.',
      );
      // Emulated device clocks can lag the host that records server creation.
      // This journey requires a chronologically valid new acknowledgement;
      // separate guard tests prove clock-behind attempts cannot be persisted.
      // Do not change device time, rewrite evidence or bypass the real action.
      if (DateTime.now().toUtc().isBefore(parsedOpen.updatedAt.toUtc())) {
        debugPrint('DEV_BURNER_WAIT_FOR_VALID_DEVICE_CLOCK');
        await waitFor(
          tester,
          () => !DateTime.now().toUtc().isBefore(parsedOpen.updatedAt.toUtc()),
          'The emulator clock must reach the server-recorded directive time.',
          seconds: 60,
        );
      }
      await _directiveAction(tester, directiveId, 'Acknowledge');
      final acknowledged = await awaitRecord(
        tester,
        'directives/$directiveId',
        (row) => row['acknowledgedByUid'] == instrumentationUid,
      );
      final parsedAcknowledged = readRemoteOperationalDirective(
        acknowledged,
        documentId: directiveId,
      );
      expect(parsedAcknowledged.status.name, 'acknowledged');
      expect(parsedAcknowledged.version, parsedOpen.version + 1);
      expect(acknowledged['status'], 'acknowledged');
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
      final parsedClosed = readRemoteOperationalDirective(
        closed,
        documentId: directiveId,
      );
      expect(parsedClosed.status.name, 'closed');
      expect(parsedClosed.version, parsedAcknowledged.version + 1);
      expect(closed['closedWithoutAcknowledgement'], isFalse);
      expect(closed['closedByUid'], instrumentationUid);
      expect(closed['acknowledgedByUid'], instrumentationUid);
      final current = await read('burner_condition_current/$_furnaceId');
      final compliance = await read(
        'burner_condition_rounds/${current['roundId']}',
      );
      expect(compliance['evidenceKind'], 'directiveCompliance');
      expect(compliance['baselineRoundId'], roundId);
      expect(compliance['recordedByUid'], instrumentationUid);
      expect(
        _instant(compliance['observedAt']),
        parsedClosed.closedAt!.toUtc(),
        reason: 'The compliance round and directive closure commit together.',
      );
      expect(compliance['roundId'], isNot(roundId));
      expect(compliance['redHotPositions'], [1]);
      expect(compliance['directivePositions'], isEmpty);
      expect(compliance['directiveId'], isNull);
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
      // This is the partial update: I&A supplied a disposition for position 1,
      // not a second inspection of all eight positions or a physical repair.
      for (var position = 2; position <= 8; position++) {
        expect(
          observations[position - 1],
          (round['observations'] as List)[position - 1],
        );
        expect(
          (compliance['uvObservations'] as List)[position - 1],
          (round['uvObservations'] as List)[position - 1],
        );
        for (final field in [
          'burners.$position.flameObservation',
          'burners.$position.redHotObserved',
          'burners.$position.microampReading',
          'uv.$position.condition',
        ]) {
          _expectProvenance(
            compliance,
            field,
            kind: 'inherited',
            sourceRoundId: roundId,
            actorUid: operationsUid,
            observedAt: round['observedAt'],
          );
        }
      }
      _expectProvenance(
        compliance,
        'burners.1.redHotObserved',
        kind: 'inherited',
        sourceRoundId: roundId,
        actorUid: operationsUid,
        observedAt: round['observedAt'],
      );
      _expectProvenance(
        compliance,
        'uv.1.condition',
        kind: 'directiveDisposition',
        sourceRoundId: current['roundId'] as String,
        actorUid: instrumentationUid,
        observedAt: compliance['observedAt'],
      );
      // Receipt contents are verified by the governed backend suite. These
      // server-private documents must remain unreadable to the normal app.
      await expectLater(
        FirebaseFirestore.instance
            .doc('burner_condition_round_receipts/${current['roundId']}')
            .get(_server),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      final finalRounds = await _furnaceDocuments('burner_condition_rounds');
      expect(finalRounds.keys.toSet().difference(priorRounds.keys.toSet()), {
        roundId,
        current['roundId'],
      });
      final original = finalRounds[roundId]!;
      for (final field in [
        'observations',
        'uvObservations',
        'observedAt',
        'recordedByUid',
        'evidenceProvenance',
        'fingerprint',
      ]) {
        expect(
          original[field],
          round[field],
          reason: 'Original $field is immutable.',
        );
      }
      expect(
        await _installationEvidence(),
        priorInstallations,
        reason: 'Directive compliance cannot invent a block or UV replacement.',
      );
      await _home(tester);
      expect(await _verifyPhysicalPopulation(tester), population);
      debugPrint(
        'DEV_BURNER_PLANT_PASS ${jsonEncode({'projectId': crm3DemoProjectId, 'freshCi': _freshCi, 'physicalPopulation': population, 'roundId': roundId, 'directiveId': directiveId, 'complianceRoundId': current['roundId'], 'redHotAndUvDamageRemain': true, 'untouchedReadingAgePreserved': true, 'originalRoundPreserved': true, 'noInstallationInvented': true, 'status': 'passed'})}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
