import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';

AssetHierarchyNode node({
  required String id,
  String? parent,
  List<String> ancestors = const <String>[],
  int sortOrder = 0,
}) => AssetHierarchyNode(
  id: id,
  assetClassId: 'class-1',
  parentNodeId: parent,
  nodeType: AssetHierarchyNodeType.component,
  name: id,
  contactArrangement: ElectricalContactArrangement.notStated,
  ownershipStatus: AssetOwnershipStatus.unassigned,
  sortOrder: sortOrder,
  ancestorNodeIds: ancestors,
  hierarchyPath: <String>[id],
  activeChildCount: 0,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin-1',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin-1',
  lastMutationId: 'mutation-1',
);

void main() {
  test('asset class draft normalizes code and rejects malformed identity', () {
    final valid =
        const AssetClassDraft(
          code: ' furnace-main ',
          name: ' Furnace ',
          majorArea: ' BAF Shop ',
        ).normalized();
    expect(valid.code, 'FURNACE-MAIN');
    expect(valid.name, 'Furnace');
    expect(valid.validate(), isEmpty);

    expect(
      const AssetClassDraft(
        code: 'furnace main',
        name: '',
        majorArea: '',
      ).validate(),
      hasLength(3),
    );
  });

  test(
    'normal state and electrical contact arrangement remain independent',
    () {
      const draft = AssetHierarchyNodeDraft(
        nodeType: AssetHierarchyNodeType.component,
        name: 'Isolation valve limit switch',
        operatingType: 'Pneumatic valve; electrical sensing',
        normalState: 'Valve normally closed',
        failState: 'Fail closed',
        contactArrangement: ElectricalContactArrangement.normallyOpen,
      );
      expect(draft.normalState, 'Valve normally closed');
      expect(
        draft.contactArrangement,
        ElectricalContactArrangement.normallyOpen,
      );
      expect(draft.validate(), isEmpty);
    },
  );

  test('strict decoder rejects unsupported schema and missing child count', () {
    final valid = <String, dynamic>{
      'schemaVersion': 1,
      'nodeId': 'node-1',
      'assetClassId': 'class-1',
      'parentNodeId': null,
      'nodeType': 'component',
      'name': 'Burner',
      'componentTag': null,
      'shortDescription': null,
      'longDescription': null,
      'discipline': 'Mechanical',
      'operatingType': 'Passive',
      'normalState': null,
      'failState': null,
      'contactArrangement': 'notApplicable',
      'manufacturer': null,
      'model': null,
      'applicability': null,
      'sourceReference': null,
      'ownershipStatus': 'unassigned',
      'ownerDiscipline': null,
      'accountableRoleKeys': <String>[],
      'sortOrder': 10,
      'ancestorNodeIds': <String>[],
      'hierarchyPath': <String>['Burner'],
      'activeChildCount': 0,
      'status': 'active',
      'version': 1,
      'createdAt': '2026-08-13T00:00:00.000Z',
      'createdByUid': 'admin-1',
      'createdByName': null,
      'updatedAt': '2026-08-13T00:00:00.000Z',
      'updatedByUid': 'admin-1',
      'updatedByName': null,
      'lastMutationId': 'mutation-1',
    };
    expect(AssetHierarchyNode.fromMap(valid, 'node-1').name, 'Burner');

    expect(
      () =>
          AssetHierarchyNode.fromMap({...valid, 'schemaVersion': 2}, 'node-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    final missingCount = {...valid}..remove('activeChildCount');
    expect(
      () => AssetHierarchyNode.fromMap(missingCount, 'node-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('tree orders siblings and reports missing parents and cycles', () {
    final tree = AssetHierarchyTree.build(<AssetHierarchyNode>[
      node(id: 'root'),
      node(
        id: 'second',
        parent: 'root',
        ancestors: const ['root'],
        sortOrder: 20,
      ),
      node(
        id: 'first',
        parent: 'root',
        ancestors: const ['root'],
        sortOrder: 10,
      ),
      node(id: 'orphan', parent: 'missing'),
      node(id: 'cycle-a', parent: 'cycle-b'),
      node(id: 'cycle-b', parent: 'cycle-a'),
    ]);

    expect(tree.childrenOf('root').map((item) => item.id), ['first', 'second']);
    expect(
      tree.integrityErrors.any((error) => error.contains('missing parent')),
      isTrue,
    );
    expect(
      tree.integrityErrors.any((error) => error.contains('Cycle detected')),
      isTrue,
    );
  });

  test(
    'installed component reference round-trips complete physical identity',
    () {
      final component = InstalledComponentRecord(
        id: 'component-1',
        assetInstanceId: 'asset-1',
        assetInstanceVersionAtMutation: 3,
        assetNumber: 7,
        assetInstanceName: 'Furnace 7',
        assetClassId: 'class-1',
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        definitionNodeId: 'node-1',
        definitionNodeVersion: 4,
        definitionName: 'Pressure transmitter',
        hierarchyPath: const ['Pressure system', 'Pressure transmitter'],
        componentTag: 'PT-701',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Instrumentation',
        accountableRoleKeys: const ['seniorInstrumentation'],
        status: AssetHierarchyStatus.active,
        version: 2,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        lastMutationId: 'mutation-1',
      );

      final decoded = AssetHierarchyReference.decode(
        component.toReference().encode(),
      );
      expect(decoded.scope, AssetHierarchyReferenceScope.installedComponent);
      expect(decoded.assetInstanceId, 'asset-1');
      expect(decoded.assetNumber, 7);
      expect(decoded.componentInstanceId, 'component-1');
      expect(decoded.componentTag, 'PT-701');
    },
  );

  test(
    'installed reference fails closed when physical identity is incomplete',
    () {
      expect(
        () => AssetHierarchyReference.fromMap({
          'schemaVersion': 2,
          'scope': 'installedComponent',
          'assetClassId': 'class-1',
          'assetClassCode': 'FURNACE',
          'assetClassName': 'Furnace',
          'nodeId': 'node-1',
          'nodeVersion': 1,
          'nodeName': 'Pressure transmitter',
          'componentTag': 'PT-101',
          'hierarchyPath': <String>['Pressure transmitter'],
          'ownershipStatus': 'unassigned',
          'ownerDiscipline': null,
          'accountableRoleKeys': <String>[],
        }),
        throwsA(isA<PersistedDataFormatException>()),
      );
    },
  );

  test('physical Base reference freezes the linked Inner Cover identity', () {
    final reference = AssetHierarchyReference(
      scope: AssetHierarchyReferenceScope.physicalAsset,
      assetClassId: 'base-class',
      assetClassCode: 'BASE',
      assetClassName: 'Base',
      nodeId: 'base-201',
      nodeVersion: 4,
      nodeName: 'Base 201',
      assetInstanceId: 'base-201',
      assetInstanceVersion: 4,
      assetNumber: 201,
      assetInstanceName: 'Base 201',
      hierarchyPath: const ['Base', 'Base 201'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'Operations',
      accountableRoleKeys: const ['operations'],
      innerCoverAssociation: InnerCoverEventReference(
        baseAssetInstanceId: 'base-201',
        baseAssetNumber: 201,
        positionState: InnerCoverPositionState.linked,
        innerCoverId: 'cover-gr26',
        innerCoverSerialNumber: 'GR26',
        linkageId: 'link-1',
        assignmentVersion: 3,
        linkedAt: DateTime.utc(2026, 8, 1),
        eventAt: DateTime.utc(2026, 8, 15, 10),
        confirmedAt: DateTime.utc(2026, 8, 15, 10, 1),
        confirmedByUid: 'ops-1',
        confirmedByName: 'Operations One',
      ),
    );

    final encoded = reference.toMap();
    expect(encoded['schemaVersion'], 3);
    final decoded = AssetHierarchyReference.decode(reference.encode());
    expect(decoded.scope, AssetHierarchyReferenceScope.physicalAsset);
    expect(decoded.innerCoverAssociation?.innerCoverSerialNumber, 'GR26');
    expect(
      decoded.innerCoverAssociation?.positionState,
      InnerCoverPositionState.linked,
    );
  });

  test(
    'Base reference records a confirmed absence without inventing a serial',
    () {
      final association = InnerCoverEventReference(
        baseAssetInstanceId: 'base-201',
        baseAssetNumber: 201,
        positionState: InnerCoverPositionState.noneLinked,
        eventAt: DateTime.utc(2026, 8, 15, 10),
        confirmedAt: DateTime.utc(2026, 8, 15, 10, 1),
        confirmedByUid: 'ops-1',
        confirmedByName: 'Operations One',
      );
      final decoded = InnerCoverEventReference.fromMap(association.toMap());
      expect(decoded.positionState, InnerCoverPositionState.noneLinked);
      expect(decoded.innerCoverId, isNull);

      expect(
        () => InnerCoverEventReference.fromMap({
          ...association.toMap(),
          'innerCoverSerialNumber': 'GR26',
        }),
        throwsA(isA<PersistedDataFormatException>()),
      );
    },
  );

  test('Base event confirmation cannot predate the reported event', () {
    final association = InnerCoverEventReference(
      baseAssetInstanceId: 'base-201',
      baseAssetNumber: 201,
      positionState: InnerCoverPositionState.noneLinked,
      eventAt: DateTime.utc(2026, 8, 15, 10),
      confirmedAt: DateTime.utc(2026, 8, 15, 9, 59),
      confirmedByUid: 'ops-1',
      confirmedByName: 'Operations One',
    );

    expect(
      () => InnerCoverEventReference.fromMap(association.toMap()),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('ownership states are internally consistent and operationally gated', () {
    expect(
      const InstalledComponentDraft(
        definitionNodeId: 'node-1',
        ownershipStatus: AssetOwnershipStatus.unassigned,
        ownerDiscipline: 'Instrumentation',
      ).validate(),
      contains(
        'Unassigned ownership cannot carry an owner discipline or accountable roles.',
      ),
    );
    expect(
      const InstalledComponentDraft(
        definitionNodeId: 'node-1',
        ownershipStatus: AssetOwnershipStatus.provisional,
      ).validate(),
      contains(
        'Provisional ownership requires an owner discipline or accountable role.',
      ),
    );
    expect(
      () =>
          const AssetHierarchyReference(
            scope: AssetHierarchyReferenceScope.installedComponent,
            assetClassId: 'class-1',
            assetClassCode: 'FURNACE',
            assetClassName: 'Furnace',
            nodeId: 'node-1',
            nodeVersion: 1,
            nodeName: 'Pressure transmitter',
            assetInstanceId: 'asset-1',
            assetInstanceVersion: 1,
            assetNumber: 1,
            assetInstanceName: 'Furnace 1',
            componentInstanceId: 'component-1',
            componentInstanceVersion: 1,
            hierarchyPath: <String>['Pressure transmitter'],
            ownershipStatus: AssetOwnershipStatus.provisional,
            ownerDiscipline: 'Instrumentation',
          ).encode(),
      throwsStateError,
    );
  });

  test('installed tag claims bind canonical tag, document hash and owner', () {
    const normalizedTag = 'PT101';
    final claimId = sha256.convert(utf8.encode(normalizedTag)).toString();
    final valid = <String, dynamic>{
      'schemaVersion': 2,
      'ownerType': 'installed_component',
      'normalizedTag': normalizedTag,
      'displayTag': 'PT-101',
      'componentInstanceId': 'component-1',
      'definitionNodeId': 'node-1',
      'definitionName': 'Pressure transmitter',
      'assetInstanceId': 'asset-1',
      'assetInstanceName': 'Furnace 1',
      'assetNumber': 1,
      'assetClassId': 'class-1',
      'assetClassName': 'Furnace',
      'hierarchyPath': <String>['Pressure system', 'Pressure transmitter'],
      'ownershipStatus': 'confirmed',
      'ownerDiscipline': 'Instrumentation',
      'accountableRoleKeys': <String>['seniorInstrumentation'],
      'claimedAt': '2026-08-13T00:00:00.000Z',
      'claimedByUid': 'admin-1',
      'lastMutationId': 'mutation-1',
    };

    expect(
      AssetTagClaimRecord.fromMap(valid, claimId).componentInstanceId,
      'component-1',
    );
    expect(
      () => AssetTagClaimRecord.fromMap(valid, 'wrong-claim-id'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => AssetTagClaimRecord.fromMap({
        ...valid,
        'displayTag': 'PT-102',
      }, claimId),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => AssetTagClaimRecord.fromMap({
        ...valid,
        'ownershipStatus': 'provisional',
      }, claimId),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
