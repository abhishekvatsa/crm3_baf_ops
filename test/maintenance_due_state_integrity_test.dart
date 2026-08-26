import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> dueState({bool includePending = true}) => {
  'schemaVersion': 1,
  'dueStateId': 'furnace-7-any',
  'assetIdentityKey': 'class-furnace:furnace-7',
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'assetClassId': 'class-furnace',
  'assetInstanceId': 'furnace-7',
  'assetDisplayName': 'Furnace 07',
  'counterKey': 'FURNACE_ANY',
  'counterLabel': 'Furnace any maintenance',
  'thresholdDays': 30,
  'lastCompletionAt': null,
  'nextDueAt': null,
  'lastCompletionEventId': null,
  'lastCompletionSourceType': null,
  'lastCompletionSourceId': null,
  'lastMaintenanceClassCode': null,
  if (includePending) 'classificationPending': true,
  'updatedAt': DateTime.utc(2026, 8, 26),
};

void main() {
  test('complete pending projection retains identity and pending state', () {
    final decoded = MaintenanceDueState.fromMap(
      dueState(),
      'furnace-7-any',
    );
    expect(decoded.assetIdentityKey, 'class-furnace:furnace-7');
    expect(decoded.counterLabel, 'Furnace any maintenance');
    expect(decoded.classificationPending, isTrue);
  });

  test('complete pre-marker projection remains a supported non-pending row', () {
    final decoded = MaintenanceDueState.fromMap(
      dueState(includePending: false),
      'furnace-7-any',
    );
    expect(decoded.classificationPending, isFalse);
  });

  test('sparse projection and impossible threshold fail closed', () {
    final sparse = dueState()..remove('assetTypeKey');
    expect(
      () => MaintenanceDueState.fromMap(sparse, 'furnace-7-any'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => MaintenanceDueState.fromMap(
        {...dueState(), 'thresholdDays': 3651},
        'furnace-7-any',
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
