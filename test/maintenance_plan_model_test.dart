import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
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
      final serialPlan =
          planMap()
            ..['assetIdentityKey'] = 'class-inner-cover:inner-cover-gr26'
            ..['assetTypeKey'] = 'innerCover'
            ..['assetNumber'] = null
            ..['assetClassId'] = 'class-inner-cover'
            ..['assetInstanceId'] = 'inner-cover-gr26'
            ..['assetInstanceName'] = 'Inner Cover GR26'
            ..['maintenanceClass'] = <String, dynamic>{
              ...Map<String, dynamic>.from(
                planMap()['maintenanceClass'] as Map,
              ),
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
