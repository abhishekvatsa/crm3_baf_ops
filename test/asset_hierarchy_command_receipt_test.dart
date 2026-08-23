import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';
const _committedAt = '2026-08-23T03:00:00.000Z';

void main() {
  group('asset hierarchy mutation receipts', () {
    test('bind hierarchy receipts to the requested class identity', () {
      final receipt = AssetHierarchyMutationReceipt.fromMap(
        _baseReceipt(
          operation: 'CREATE_CLASS',
          auditPrefix: 'asset_hierarchy',
          identity: const <String, dynamic>{
            'assetClassId': 'class-1',
            'nodeId': null,
          },
        ),
        request: const <String, dynamic>{
          'requestId': _requestId,
          'operation': 'CREATE_CLASS',
          'assetClassId': 'class-1',
        },
      );

      expect(receipt.entityId, 'class-1');
      expect(receipt.version, 1);
      expect(receipt.committedAt, DateTime.parse(_committedAt));
    });

    test('bind registry replacement receipts to the new component', () {
      final receipt = AssetHierarchyMutationReceipt.fromMap(
        _baseReceipt(
          operation: 'REPLACE_COMPONENT_INSTANCE',
          auditPrefix: 'asset_registry',
          identity: const <String, dynamic>{
            'assetClassId': 'furnace-class',
            'nodeId': 'replacement-component',
          },
        ),
        request: const <String, dynamic>{
          'requestId': _requestId,
          'operation': 'REPLACE_COMPONENT_INSTANCE',
          'assetClassId': 'furnace-class',
          'componentInstanceId': 'old-component',
          'replacementComponentInstanceId': 'replacement-component',
        },
      );

      expect(receipt.entityId, 'replacement-component');
    });

    test('bind Inner Cover and secondary versions exactly', () {
      final receipt = AssetHierarchyMutationReceipt.fromMap(
        _baseReceipt(
          operation: 'SWAP_INNER_COVERS',
          auditPrefix: 'inner_cover',
          identity: const <String, dynamic>{
            'innerCoverId': 'cover-incoming',
            'secondaryVersion': 8,
          },
        ),
        request: const <String, dynamic>{
          'requestId': _requestId,
          'operation': 'SWAP_INNER_COVERS',
          'innerCoverId': 'cover-incoming',
        },
      );

      expect(receipt.entityId, 'cover-incoming');
      expect(receipt.secondaryVersion, 8);
    });

    test('bind asset-condition receipts to requested state', () {
      final receipt = AssetHierarchyMutationReceipt.fromMap(
        _baseReceipt(
          operation: 'DECLARE_ASSET_CONDITION',
          auditPrefix: 'asset_condition',
          identity: const <String, dynamic>{
            'assetClassId': 'base-class',
            'assetInstanceId': 'base-201',
            'condition': 'down',
          },
        ),
        request: const <String, dynamic>{
          'requestId': _requestId,
          'operation': 'DECLARE_ASSET_CONDITION',
          'assetClassId': 'base-class',
          'assetInstanceId': 'base-201',
          'condition': 'down',
        },
      );

      expect(receipt.entityId, 'base-201');
    });

    test('rejects mismatched, partial, or non-canonical evidence', () {
      const request = <String, dynamic>{
        'requestId': _requestId,
        'operation': 'UPDATE_NODE',
        'assetClassId': 'class-1',
        'nodeId': 'node-1',
      };
      final valid = _baseReceipt(
        operation: 'UPDATE_NODE',
        auditPrefix: 'asset_hierarchy',
        identity: const <String, dynamic>{
          'assetClassId': 'class-1',
          'nodeId': 'node-1',
        },
      );

      expect(
        () => AssetHierarchyMutationReceipt.fromMap(<String, dynamic>{
          ...valid,
          'nodeId': 'node-2',
        }, request: request),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => AssetHierarchyMutationReceipt.fromMap(
          <String, dynamic>{...valid}..remove('version'),
          request: request,
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => AssetHierarchyMutationReceipt.fromMap(<String, dynamic>{
          ...valid,
          'committedAt': '2026-08-23T08:30:00.000+05:30',
        }, request: request),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  });
}

Map<String, dynamic> _baseReceipt({
  required String operation,
  required String auditPrefix,
  required Map<String, dynamic> identity,
}) => <String, dynamic>{
  'ok': true,
  'requestId': _requestId,
  'operation': operation,
  ...identity,
  'version': 1,
  'auditId': '${auditPrefix}_$_requestId',
  'committedAt': _committedAt,
  'idempotentReplay': false,
};
