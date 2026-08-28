import 'dart:convert';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> activeCondition({
  String documentId = 'asset-1',
  String condition = 'down',
}) => <String, dynamic>{
  'schemaVersion': 1,
  'assetInstanceId': documentId,
  'assetClassId': 'class-1',
  'assetClassCode': 'FURNACE',
  'assetClassName': 'Furnace',
  'assetNumber': 1,
  'assetName': 'Furnace 1',
  'condition': condition,
  'active': true,
  'causeKeys': <String>['breakdown'],
  'reason': 'Drive fault prevents safe operation.',
  'linkedIssueIds': <String>['issue-1'],
  'declaredAt': DateTime.utc(2026, 8, 14),
  'declaredByUid': 'ops-1',
  'declaredByName': 'Operations One',
  'restoredAt': null,
  'restoredByUid': null,
  'restoredByName': null,
  'previousCondition': 'available',
  'version': 1,
  'updatedAt': DateTime.utc(2026, 8, 14),
  'updatedByUid': 'ops-1',
  'updatedByName': 'Operations One',
  'lastMutationId': 'mutation-1',
};

Map<String, dynamic> activeConditionV2() => <String, dynamic>{
  ...activeCondition(),
  'schemaVersion': 2,
  'basis': 'pendingMaintenance',
  'componentHierarchyRefJson': jsonEncode(<String, dynamic>{
    'schemaVersion': 4,
    'scope': 'componentDefinitionOnAsset',
    'assetClassId': 'class-1',
    'assetClassCode': 'FURNACE',
    'assetClassName': 'Furnace',
    'nodeId': 'burner-system',
    'nodeVersion': 3,
    'nodeName': 'Burner system',
    'assetInstanceId': 'asset-1',
    'assetInstanceVersion': 2,
    'assetNumber': 1,
    'assetInstanceName': 'Furnace 1',
    'componentInstanceId': null,
    'componentInstanceVersion': null,
    'componentTag': null,
    'hierarchyPath': <String>['Combustion system', 'Burner system'],
    'ownershipStatus': 'confirmed',
    'ownerDiscipline': 'I&A',
    'accountableRoleKeys': <String>['seniorInstrumentation'],
    'innerCoverAssociation': null,
  }),
};

void main() {
  test('strict condition decoder retains complete active evidence', () {
    final record = AssetOperationalConditionRecord.fromMap(
      activeCondition(),
      'asset-1',
    );
    expect(record.condition, AssetOperationalCondition.down);
    expect(record.active, isTrue);
    expect(record.causes, [AssetConditionCause.breakdown]);
    expect(record.linkedIssueIds, ['issue-1']);
    expect(record.declaredByName, 'Operations One');
  });

  test('missing or contradictory authority fields fail closed', () {
    for (final malformed in <Map<String, dynamic>>[
      {...activeCondition()}..remove('active'),
      {...activeCondition(), 'active': false},
      {...activeCondition(), 'causeKeys': <String>[]},
      {...activeCondition()}..remove('linkedIssueIds'),
      {...activeCondition(), 'declaredByUid': null},
      {...activeCondition(), 'restoredAt': DateTime.utc(2026, 8, 14)},
      {...activeCondition(), 'assetNumber': 0},
    ]) {
      expect(
        () => AssetOperationalConditionRecord.fromMap(malformed, 'asset-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('schema two retains availability basis and exact component', () {
    final record = AssetOperationalConditionRecord.fromMap(
      activeConditionV2(),
      'asset-1',
    );
    expect(record.basis, AssetConditionBasis.pendingMaintenance);
    expect(record.componentReference?.nodeId, 'burner-system');
    expect(record.componentReference?.assetInstanceId, 'asset-1');

    for (final malformed in <Map<String, dynamic>>[
      {...activeConditionV2()}..remove('basis'),
      {...activeConditionV2(), 'componentHierarchyRefJson': null},
      {...activeConditionV2(), 'basis': 'innerCoverUnavailable'},
    ]) {
      expect(
        () => AssetOperationalConditionRecord.fromMap(malformed, 'asset-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }

    final innerCover = <String, dynamic>{
      ...activeConditionV2(),
      'basis': 'innerCoverUnavailable',
      'componentHierarchyRefJson': null,
    };
    expect(
      AssetOperationalConditionRecord.fromMap(innerCover, 'asset-1').basis,
      AssetConditionBasis.innerCoverUnavailable,
    );
  });

  test('restored condition requires complete restoration authority', () {
    final restored = <String, dynamic>{
      ...activeCondition(condition: 'available'),
      'active': false,
      'causeKeys': <String>[],
      'linkedIssueIds': <String>[],
      'restoredAt': DateTime.utc(2026, 8, 14, 13),
      'restoredByUid': 'shift-1',
      'restoredByName': 'Shift Supervisor',
      'previousCondition': 'down',
      'version': 2,
    };
    final record = AssetOperationalConditionRecord.fromMap(restored, 'asset-1');
    expect(record.condition, AssetOperationalCondition.available);
    expect(record.active, isFalse);
    expect(record.restoredByUid, 'shift-1');

    for (final malformed in <Map<String, dynamic>>[
      {...restored, 'restoredByName': null},
      {...restored}..remove('causeKeys'),
      {...restored}..remove('linkedIssueIds'),
    ]) {
      expect(
        () => AssetOperationalConditionRecord.fromMap(malformed, 'asset-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });
}
