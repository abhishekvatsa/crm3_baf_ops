// Actual Android forms and authenticated emulator readback. No outcome is seeded.
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
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_programmes_screen.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_provider.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show waitFor;
import 'dev_issue_quality_journey_test.dart'
    show enter, openMore, select, showControl, tapControl;
import 'support/required_red_journey.dart' show returnRequiredRedHome;

const _server = GetOptions(source: Source.server);

void _confirmed(SnapshotMetadata metadata) {
  expect(
    metadata.isFromCache,
    isFalse,
    reason: 'Only current server evidence is accepted.',
  );
  expect(
    metadata.hasPendingWrites,
    isFalse,
    reason: 'Pending local writes are not server acceptance.',
  );
}

Future<Map<String, dynamic>> read(String path) async {
  final document = await FirebaseFirestore.instance.doc(path).get(_server);
  _confirmed(document.metadata);
  expect(document.exists, isTrue, reason: path);
  return document.data()!;
}

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _rows(
  String collection,
  String key,
  Object value,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection(collection)
      .where(key, isEqualTo: value)
      .get(_server);
  _confirmed(snapshot.metadata);
  for (final document in snapshot.docs) {
    _confirmed(document.metadata);
  }
  return snapshot.docs;
}

Future<QueryDocumentSnapshot<Map<String, dynamic>>> _accepted(
  WidgetTester tester,
  String collection,
  String key,
  Object value, {
  int count = 1,
}) async {
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(end)) {
    final rows = await _rows(collection, key, value);
    if (rows.length == count) return rows.last;
    expect(
      rows.length,
      lessThanOrEqualTo(count),
      reason: 'No duplicate accepted records.',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure(
    'Expected $count accepted $collection records for $key=$value.',
  );
}

Future<void> _programmes(WidgetTester tester) async {
  await returnRequiredRedHome(tester, find.byType(HomeScreen));
  await openMore(tester, 'Inspection programmes');
  await waitFor(
    tester,
    () => find.byType(InspectionProgrammesScreen).evaluate().isNotEmpty,
    'The actual inspection programme screen must open.',
  );
}

Future<void> _fillKey(WidgetTester tester, String key, String value) async {
  final input = find.byKey(ValueKey(key));
  await showControl(tester, input);
  // Attach the real Android keyboard before replacing a previous answer.
  await tapControl(tester, input);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
  await tester.enterText(input, value);
  await tester.pump();
  expect(
    tester.widget<TextFormField>(input).controller!.text,
    value,
    reason: 'The focused field must contain the entered value.',
  );
  await showControl(tester, input);
  expect(
    tester.widget<TextFormField>(input).controller!.text,
    value,
    reason: 'The entered value must survive native keyboard dismissal.',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'labelled Yes/No and Date readings survive creation, reopening and correction',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      expect(crm3DemoProjectId, 'demo-crm3-ci-journeys');
      expect(crm3EmulatorHost, '10.0.2.2');
      expect(crm3AuthEmulatorPort, 19099);
      expect(crm3FirestoreEmulatorPort, 18080);
      expect(crm3FunctionsEmulatorPort, 15001);
      final flutterError = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = flutterError;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, 'demo-crm3-ci-journeys');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'DEV access gate',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tapControl(tester, find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'DEV Home',
      );
      final actor = FirebaseAuth.instance.currentUser!;
      expect(actor.email, 'dev.cf01-b@example.invalid');
      final user = await read('users/${actor.uid}');
      expect(user['roles'], ['admin']);
      expect(user['isApproved'], isTrue);
      final furnace = await read('asset_instances/seed-asset-furnace-01');
      final assetClass = await read('asset_classes/${furnace['assetClassId']}');
      final runId = DateTime.now().microsecondsSinceEpoch.toString();
      final code = 'DEV_READING_$runId';
      final title = 'DEV seal examination $runId';
      final purpose = 'DEV labelled reading acceptance $runId';
      expect(await _rows('inspection_definitions', 'code', code), isEmpty);

      await _programmes(tester);
      await tapControl(tester, find.text('Definitions'));
      await tapControl(
        tester,
        find.byKey(const ValueKey('inspection-add-definition')),
      );
      await enter(tester, 'Definition code', code);
      await enter(tester, 'Field-facing title', title);
      await enter(
        tester,
        'What this inspection establishes',
        'Verify the seal and record its examination date together.',
      );
      await select(
        tester,
        find.byType(DropdownButtonFormField<String>),
        assetClass['name'] as String,
      );
      await tapControl(tester, find.text('Yes/No'));
      await tapControl(tester, find.text('Add another reading'));
      await _fillKey(tester, 'inspection-reading-label', 'Completion date');
      await select(
        tester,
        find.byKey(const ValueKey('inspection-reading-type')),
        'Date (dd-mm-yyyy)',
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('inspection-reading-save')),
      );
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Save version'),
      );
      final definitionDoc = await _accepted(
        tester,
        'inspection_definitions',
        'code',
        code,
      );
      final definition = InspectionDefinition.fromMap(
        definitionDoc.data(),
        definitionDoc.id,
      );
      expect(definition.frozen.schemaVersion, 2);
      expect(definition.frozen.readingFields.map((row) => row.valueType), [
        InspectionValueType.boolean,
        InspectionValueType.date,
      ]);
      expect(definition.frozen.readingFields[1].label, 'Completion date');
      final booleanId = definition.frozen.readingFields[0].id;
      final dateId = definition.frozen.readingFields[1].id;

      await tapControl(tester, find.text('Active'));
      await tapControl(tester, find.widgetWithText(FilledButton, 'New'));
      await select(
        tester,
        find.byType(DropdownButtonFormField<InspectionDefinition>),
        title,
      );
      await enter(tester, 'Purpose of this programme', purpose);
      await tapControl(tester, find.widgetWithText(TextButton, 'Choose'));
      await tapControl(tester, find.widgetWithText(TextButton, 'Clear'));
      await tapControl(
        tester,
        find.widgetWithText(CheckboxListTile, furnace['name'] as String),
      );
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Use selection'),
      );
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Open programme'),
      );
      final campaignDoc = await _accepted(
        tester,
        'inspection_campaigns',
        'purpose',
        purpose,
      );
      final campaign = InspectionCampaign.fromMap(
        campaignDoc.data(),
        campaignDoc.id,
      );
      expect(
        campaign.definition.readingFields.map((row) => row.toMap()).toList(),
        definition.frozen.readingFields.map((row) => row.toMap()).toList(),
      );
      expect(campaign.targets, hasLength(1));
      expect(campaign.targets.single.assetInstanceId, 'seed-asset-furnace-01');
      await tapControl(tester, find.textContaining(purpose));
      await waitFor(
        tester,
        () => find.byType(InspectionCampaignDetailScreen).evaluate().isNotEmpty,
        'Fresh programme must open.',
      );
      await tapControl(tester, find.text('Add reading'));
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Save reading'),
      );
      await showControl(tester, find.text('Choose Yes or No.'));
      expect(
        await _rows('inspection_observations', 'campaignId', campaign.id),
        isEmpty,
      );
      await tapControl(tester, find.widgetWithText(ChoiceChip, 'No'));
      await _fillKey(tester, 'inspection-reading-$dateId', '31-02-2026');
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Save reading'),
      );
      await showControl(tester, find.text('Enter a valid date as DD-MM-YYYY.'));
      expect(
        await _rows('inspection_observations', 'campaignId', campaign.id),
        isEmpty,
      );
      await _fillKey(tester, 'inspection-reading-$dateId', '03-10-2026');
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Save reading'),
      );
      final originalDoc = await _accepted(
        tester,
        'inspection_observations',
        'campaignId',
        campaign.id,
      );
      final originalMap = originalDoc.data();
      final original = InspectionObservation.fromMap(
        originalMap,
        originalDoc.id,
      );
      expect(originalMap['value'], {
        'schemaVersion': 2,
        'readings': [
          {'fieldId': booleanId, 'valueType': 'boolean', 'value': false},
          {'fieldId': dateId, 'valueType': 'date', 'value': '2026-10-03'},
        ],
      });
      expect(originalMap.containsKey('readings'), isFalse);
      expect(original.booleanValue, isNull);
      expect(original.outOfRange, isFalse);
      expect(original.observerUid, actor.uid);

      // Navigate away and reopen the server-backed programme before correction.
      await _programmes(tester);
      await tapControl(tester, find.textContaining(purpose));
      final detail = find.byType(InspectionCampaignDetailScreen);
      await waitFor(
        tester,
        () => detail.evaluate().isNotEmpty,
        'Reopened programme detail must mount before its evidence is inspected.',
      );
      final container = ProviderScope.containerOf(
        tester.element(detail),
        listen: false,
      );
      await waitFor(
        tester,
        () {
          final state = container.read(inspectionCampaignsProvider);
          if (state.isLoading || state.hasError) return false;
          final snapshot = state.asData?.value;
          if (snapshot == null ||
              !snapshot.isServerVerified ||
              !snapshot.isComplete) {
            return false;
          }
          final observationState = container.read(
            inspectionObservationsProvider(campaign.id),
          );
          if (observationState.isLoading || observationState.hasError) {
            return false;
          }
          final observationSnapshot = observationState.asData?.value;
          if (observationSnapshot == null ||
              !observationSnapshot.isServerVerified ||
              !observationSnapshot.isComplete ||
              !observationSnapshot.records.any(
                (row) =>
                    row.id == original.id &&
                    row.targetKey == original.targetKey,
              )) {
            return false;
          }
          return snapshot.records.any(
            (row) =>
                row.id == campaign.id &&
                row.targets.any(
                  (target) =>
                      target.targetKey == original.targetKey &&
                      target.lastObservationId == original.id,
                ),
          );
        },
        'The actual campaign projection must identify the accepted reading before correction.',
      );
      await showControl(tester, find.byTooltip('Reading actions'));
      await tapControl(tester, find.byTooltip('Reading actions'));
      await tapControl(tester, find.text('Record correction'));
      await showControl(
        tester,
        find.byKey(ValueKey('inspection-reading-$dateId')),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(ValueKey('inspection-reading-$dateId')),
            )
            .controller!
            .text,
        '03-10-2026',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'No'))
            .selected,
        isTrue,
      );
      await _fillKey(tester, 'inspection-reading-$dateId', '04-10-2026');
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Record correction'),
      );
      await _accepted(
        tester,
        'inspection_observations',
        'campaignId',
        campaign.id,
        count: 2,
      );
      final all = await _rows(
        'inspection_observations',
        'campaignId',
        campaign.id,
      );
      final correctionDoc = all.singleWhere((row) => row.id != original.id);
      final corrected = InspectionObservation.fromMap(
        correctionDoc.data(),
        correctionDoc.id,
      );
      expect(corrected.supersedesObservationId, original.id);
      expect(corrected.observedAt, original.observedAt);
      expect(corrected.readings[0].value, false);
      expect(corrected.readings[1].value, '2026-10-04');
      expect(corrected.displayValue, contains('Completion date: 04-10-2026'));
      expect(await read('inspection_observations/${original.id}'), originalMap);
      final finalCampaign = InspectionCampaign.fromMap(
        await read('inspection_campaigns/${campaign.id}'),
        campaign.id,
      );
      expect(finalCampaign.observationCount, 2);
      expect(finalCampaign.targets.single.lastObservationId, corrected.id);
      expect(FirebaseAuth.instance.currentUser!.uid, actor.uid);
      binding.reportData = {
        'projectId': crm3DemoProjectId,
        'definitionId': definition.id,
        'campaignId': campaign.id,
        'originalObservationId': original.id,
        'correctionObservationId': corrected.id,
        'readingCount': 2,
        'unansweredRejected': true,
        'invalidDateRejected': true,
        'originalPreserved': true,
        'normalUiSubmission': true,
        'productionTouched': false,
      };
      debugPrint(
        'DEV_INSPECTION_READINGS_PASS ${jsonEncode(binding.reportData)}',
      );
    },
  );
}
