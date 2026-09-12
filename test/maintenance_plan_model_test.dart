import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/maintenance_intelligence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> planMap() => <String, dynamic>{
  'schemaVersion': 2,
  'planId': 'plan-furnace-7',
  'version': 3,
  'status': 'ready',
  'assetIdentityKey': 'class-furnace:furnace-7',
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'assetClassId': 'class-furnace',
  'assetInstanceId': 'furnace-7',
  'assetInstanceVersion': 4,
  'assetInstanceName': 'Furnace 07',
  'maintenanceClass': <String, dynamic>{
    'schemaVersion': 1,
    'definitionId': 'maintenance-class-furnace-mid',
    'definitionVersion': 2,
    'code': 'FURNACE_MID',
    'title': 'Furnace Mid Maintenance',
    'assetTypeKeys': <String>['furnace'],
    'assetClassIds': <String>[],
    'principalLaneKey': 'mech',
    'resetCounters': <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'FURNACE_ANY',
        'label': 'Furnace any maintenance',
        'thresholdDays': 30,
      },
    ],
  },
  'targetWindowStart': '2026-08-25T02:00:00.000Z',
  'targetWindowEnd': '2026-08-25T10:00:00.000Z',
  'planningNotes': 'Use the next available operating window.',
  'releasedExecutionId': null,
};

Map<String, dynamic> completionEventMap() => <String, dynamic>{
  'schemaVersion': 1,
  'eventId': 'event-history-1',
  'sourceType': 'historicalMaintenance',
  'sourceId': 'history-furnace-7-20260810',
  'sourceRevision': 1,
  'assetIdentityKey': 'class-furnace:furnace-7',
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'assetClassId': 'class-furnace',
  'assetInstanceId': 'furnace-7',
  'assetDisplayName': 'Furnace 07',
  'maintenanceClass': planMap()['maintenanceClass'],
  'maintenanceClassDefinitionId': 'maintenance-class-furnace-mid',
  'maintenanceClassDefinitionVersion': 2,
  'maintenanceClassCode': 'FURNACE_MID',
  'maintenanceClassTitle': 'Furnace Mid Maintenance',
  'resetCounterKeys': <String>['FURNACE_ANY'],
  'completedAt': '2026-08-10T06:30:00.000Z',
  'completedByUid': null,
  'completedByName': 'Mechanical maintenance team',
  'recordedAt': '2026-08-21T08:00:00.000Z',
};

void main() {
  final subject = InnerCoverProfile(
    id: 'inner-cover-gr26',
    assetClassId: 'class-inner-cover',
    assetClassCode: 'INNER_COVER',
    assetClassName: 'Inner Cover',
    serialNumber: 'GR26',
    normalizedSerialNumber: 'GR26',
    sourceType: InnerCoverSourceType.legacyExisting,
    lifecycleState: InnerCoverLifecycleState.underRepair,
    traceabilityGrade: InnerCoverTraceabilityGrade.t0,
    version: 5,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 21),
    lastMutationId: 'review-fixture',
  );

  test(
    'additive subject review fields retain a strictly decoded original baseline',
    () {
      final data = planMap()
        ..['assetInstanceVersion'] = 5
        ..['originalAssetInstanceVersion'] = 4
        ..['subjectReview'] = <String, Object?>{
          'schemaVersion': 1,
          'reviewedByUid': 'supervisor-1',
          'auditId': 'review-1',
          'reason': 'Reviewed the same physical subject',
        };
      final plan = MaintenancePlan.fromMap(data, 'plan-furnace-7');
      expect(plan.originalAssetInstanceVersion, 4);
      expect(plan.assetInstanceVersion, 5);
      for (final malformed in <Object>[0, 6, '4']) {
        data['originalAssetInstanceVersion'] = malformed;
        expect(
          () => MaintenancePlan.fromMap(data, 'plan-furnace-7'),
          throwsA(isA<PersistedDataFormatException>()),
        );
      }
    },
  );

  test('subject review request binds the exact displayed subject snapshot', () {
    expect(
      maintenancePlanSubjectReviewPayload(subject, ' Reviewed after removal. '),
      {
        'status': 'ready',
        'executionId': null,
        'reason': 'Reviewed after removal.',
        'revalidation': {
          'assetClassId': 'class-inner-cover',
          'assetInstanceId': 'inner-cover-gr26',
          'assetInstanceVersion': 5,
          'serialNumber': 'GR26',
          'lifecycleState': 'underRepair',
          'currentBaseAssetInstanceId': null,
          'currentBaseAssetNumber': null,
        },
      },
    );
  });

  testWidgets(
    'ready-plan subject review requires an explicit reason and confirmation',
    (tester) async {
      String? result;
      final plan = MaintenancePlan.fromMap(planMap(), 'plan-furnace-7');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMaintenancePlanSubjectReview(
                    context,
                    plan: plan,
                    subject: subject,
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Current cover revision: 5'), findsOneWidget);
      expect(find.textContaining('State: Under repair'), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.text('Record subject review'));
      await tester.pumpAndSettle();
      expect(find.text('Explain why this plan still applies.'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(
        find.byType(TextFormField),
        'Same cover, removed for cleaning.',
      );
      await tester.tap(find.text('Record subject review'));
      await tester.pumpAndSettle();
      expect(result, 'Same cover, removed for cleaning.');
    },
  );

  test('decodes exact governed asset maintenance plan', () {
    final plan = MaintenancePlan.fromMap(planMap(), 'plan-furnace-7');

    expect(plan.assetIdentityKey, 'class-furnace:furnace-7');
    expect(plan.assetInstanceName, 'Furnace 07');
    expect(plan.assetInstanceVersion, 4);
    expect(plan.status, MaintenancePlanStatus.ready);
  });

  test('legacy or partial plan identity fails closed', () {
    final legacy = planMap()..['schemaVersion'] = 1;
    final partial = planMap()..['assetInstanceId'] = null;

    for (final malformed in [legacy, partial]) {
      expect(
        () => MaintenancePlan.fromMap(malformed, 'plan-furnace-7'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test(
    'decodes a serial-based Inner Cover plan without a fake asset number',
    () {
      final serialPlan = planMap()
        ..['assetIdentityKey'] = 'class-inner-cover:inner-cover-gr26'
        ..['assetTypeKey'] = 'innerCover'
        ..['assetNumber'] = null
        ..['assetClassId'] = 'class-inner-cover'
        ..['assetInstanceId'] = 'inner-cover-gr26'
        ..['assetInstanceName'] = 'Inner Cover GR26'
        ..['maintenanceClass'] = <String, dynamic>{
          ...Map<String, dynamic>.from(planMap()['maintenanceClass'] as Map),
          'code': 'INNER_COVER_CLEANING',
          'title': 'Inner Cover Cleaning',
          'assetTypeKeys': <String>['innerCover'],
        };

      final plan = MaintenancePlan.fromMap(serialPlan, 'plan-furnace-7');

      expect(plan.assetNumber, isNull);
      expect(plan.isSerialInnerCover, isTrue);
    },
  );

  test('null asset number fails closed for non-Inner-Cover plans', () {
    final malformed = planMap()..['assetNumber'] = null;

    expect(
      () => MaintenancePlan.fromMap(malformed, 'plan-furnace-7'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('decodes an immutable historical maintenance completion event', () {
    final event = MaintenanceCompletionEvent.fromMap(
      completionEventMap(),
      'event-history-1',
    );

    expect(event.isHistorical, isTrue);
    expect(event.assetDisplayName, 'Furnace 07');
    expect(event.maintenanceClass.title, 'Furnace Mid Maintenance');
    expect(event.completedByName, 'Mechanical maintenance team');
  });

  test('completion history fails closed on partial asset identity', () {
    final malformed = completionEventMap()..['assetInstanceId'] = null;

    expect(
      () => MaintenanceCompletionEvent.fromMap(malformed, 'event-history-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
