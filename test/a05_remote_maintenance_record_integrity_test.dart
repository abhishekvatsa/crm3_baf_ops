import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 remote maintenance record integrity', () {
    test('complete current record decodes without manufactured state', () {
      final record = readRemoteMaintenanceRecord(
        _validRecord(),
        documentId: 'ticket-1',
      );

      expect(record.firestoreId, 'ticket-1');
      expect(record.assetType, AssetType.base);
      expect(record.assetNumber, 101);
      expect(record.status, TicketStatus.open);
      expect(record.workflowQueueState, 'independent');
      expect(record.actionsJson, '[]');
      expect(record.resolutionHistoryJson, '[]');
    });

    test('required business fields never receive defaults', () {
      final mutations = <String, Object?>{
        'version': null,
        'assetType': 'unknown',
        'assetNumber': '101',
        'maintenanceType': null,
        'description': '',
        'routedTo': 'unknown',
        'status': null,
        'isResolved': null,
        'isCritical': 0,
        'loggedByUid': '',
        'isDeleted': null,
      };

      for (final entry in mutations.entries) {
        final data = _validRecord()..[entry.key] = entry.value;
        expect(
          () => readRemoteMaintenanceRecord(data, documentId: 'ticket-1'),
          throwsA(isA<PersistedDataFormatException>()),
          reason: entry.key,
        );
      }
    });

    test('document identity and lifecycle contradictions fail closed', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['firestoreId'] = 'another-ticket',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['status'] = 'resolved'
            ..['isResolved'] = false,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['deletedAt'] = '2026-08-12T10:05:00Z',
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('partial or contradictory workflow projection fails closed', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()..['workflowDeferred'] = false,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      final linked =
          _validRecord()..addAll(<String, dynamic>{
            'workflowDeferred': false,
            'workflowQueueState': 'actionable',
            'workflowAggregateId': 'workflow-1',
            'workflowComplianceId': 'compliance-1',
            'workflowOriginLaneKey': 'operations',
            'workflowTargetLaneKey': 'mechanical',
            'workflowConditionTypeKey': 'manual',
            'workflowUpdatedAt': '2026-08-12T10:05:00Z',
          });
      expect(
        readRemoteMaintenanceRecord(
          linked,
          documentId: 'ticket-1',
        ).workflowAggregateId,
        'workflow-1',
      );

      expect(
        () => readRemoteMaintenanceRecord(
          Map<String, dynamic>.from(linked)..['workflowDeferred'] = true,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('malformed present optional values are not treated as absent', () {
      for (final entry
          in <String, Object?>{
            'component': 12,
            'hierarchyPath': 'base/101',
            'teamsInvolved': <Object>['operations', 7],
            'downtimeHours': double.nan,
            'chargeNoAtEvent': '42',
          }.entries) {
        expect(
          () => readRemoteMaintenanceRecord(
            _validRecord()..[entry.key] = entry.value,
            documentId: 'ticket-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
          reason: entry.key,
        );
      }
    });

    test('exact governed identity admits universal asset numbers', () {
      final record = readRemoteMaintenanceRecord(
        _validRecord()
          ..['assetType'] = 'furnace'
          ..['assetNumber'] = 27
          ..['assetHierarchyRefJson'] = _governedAssetReference(27),
        documentId: 'ticket-1',
      );

      expect(record.assetType, AssetType.furnace);
      expect(record.assetNumber, 27);
      expect(record.assetHierarchyReference?.assetInstanceId, 'furnace-27');
    });

    test(
      'exact installed component identity admits universal asset numbers',
      () {
        final record = readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 28
            ..['assetHierarchyRefJson'] = _governedAssetReference(
              28,
              scope: AssetHierarchyReferenceScope.installedComponent,
            ),
          documentId: 'ticket-1',
        );

        expect(record.assetNumber, 28);
        expect(
          record.assetHierarchyReference?.scope,
          AssetHierarchyReferenceScope.installedComponent,
        );
        expect(
          record.assetHierarchyReference?.componentInstanceId,
          'component-28',
        );
      },
    );

    test('legacy or mismatched identity cannot bypass asset number rules', () {
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 27,
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 27
            ..['assetHierarchyRefJson'] = _governedAssetReference(28),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => readRemoteMaintenanceRecord(
          _validRecord()
            ..['assetType'] = 'furnace'
            ..['assetNumber'] = 10000
            ..['assetHierarchyRefJson'] = _governedAssetReference(10000),
          documentId: 'ticket-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  });
}

String _governedAssetReference(
  int number, {
  AssetHierarchyReferenceScope scope =
      AssetHierarchyReferenceScope.physicalAsset,
}) {
  return AssetHierarchyReference(
    scope: scope,
    assetClassId: 'furnace-class',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    nodeId: 'furnace-$number',
    nodeVersion: 4,
    nodeName: 'Furnace $number',
    assetInstanceId: 'furnace-$number',
    assetInstanceVersion: 4,
    assetNumber: number,
    assetInstanceName: 'Furnace $number',
    componentInstanceId:
        scope == AssetHierarchyReferenceScope.installedComponent
            ? 'component-$number'
            : null,
    componentInstanceVersion:
        scope == AssetHierarchyReferenceScope.installedComponent ? 2 : null,
    componentTag:
        scope == AssetHierarchyReferenceScope.installedComponent
            ? 'PT-$number'
            : null,
    hierarchyPath: <String>['Furnace', 'Furnace $number'],
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Mechanical',
    accountableRoleKeys: const <String>['seniorMechanical'],
  ).encode();
}

Map<String, dynamic> _validRecord() => <String, dynamic>{
  'firestoreId': 'ticket-1',
  'version': 3,
  'assetType': 'base',
  'assetNumber': 101,
  'maintenanceType': 'breakdown',
  'description': 'Inspect furnace base alignment',
  'routedTo': 'mechanical',
  'status': 'open',
  'isResolved': false,
  'isCritical': false,
  'loggedByUid': 'actor-1',
  'startDate': '2026-08-12T10:00:00Z',
  'createdAt': '2026-08-12T10:00:00Z',
  'updatedAt': '2026-08-12T10:10:00Z',
  'actionsJson': '[]',
  'resolutionHistoryJson': '[]',
  'isDeleted': false,
};
