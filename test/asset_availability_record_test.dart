import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_availability_record.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _projection({
  String state = 'temporarilyBlocked',
  String? activeConstraintId = 'case-1_furnace-1',
  String? reasonType = 'furnaceStuckup',
  String? linkedCaseId = 'case-1',
  String? linkedTicketId = 'ticket-1',
  String? since = '2026-08-20T08:00:00Z',
}) => <String, dynamic>{
  'schemaVersion': 1,
  'assetType': 'furnace',
  'assetClassId': 'furnace-class',
  'assetInstanceId': 'furnace-1',
  'assetNumber': 1,
  'availabilityState': state,
  'activeConstraintId': activeConstraintId,
  'reasonType': reasonType,
  'linkedCaseId': linkedCaseId,
  'linkedTicketId': linkedTicketId,
  'since': since,
  'updatedAt': '2026-08-20T08:01:00Z',
  'updatedByUid': 'operations-1',
  'updatedByName': 'Operations One',
  'version': 1,
};

void main() {
  test('accepts complete blocked and clear availability projections', () {
    final blocked = AssetAvailabilityRecord.fromMap(_projection(), 'furnace-1');
    final clear = AssetAvailabilityRecord.fromMap(
      _projection(
        state: 'clear',
        activeConstraintId: null,
        reasonType: null,
        linkedCaseId: null,
        linkedTicketId: null,
        since: null,
      ),
      'furnace-1',
    );

    expect(blocked.isTemporarilyBlocked, isTrue);
    expect(clear.isTemporarilyBlocked, isFalse);
  });

  test('partial blocked projection fails closed', () {
    expect(
      () => AssetAvailabilityRecord.fromMap(
        _projection(linkedTicketId: null),
        'furnace-1',
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('document and asset identity must agree', () {
    expect(
      () => AssetAvailabilityRecord.fromMap(_projection(), 'furnace-2'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
