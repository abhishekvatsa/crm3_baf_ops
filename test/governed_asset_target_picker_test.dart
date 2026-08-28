import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/governed_asset_target_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27);
  final asset = AssetInstanceRecord(
    id: 'furnace-12',
    assetClassId: 'furnace-class',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 12,
    name: 'Furnace 12',
    serviceState: AssetServiceState.inService,
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Operations',
    accountableRoleKeys: const <String>['operations'],
    status: AssetHierarchyStatus.active,
    activeComponentCount: 8,
    version: 4,
    createdAt: now,
    updatedAt: now,
    lastMutationId: 'asset-mutation-4',
  );

  test('binds an arbitrary-depth component definition to the exact asset', () {
    final node = _node(
      now: now,
      id: 'uv-detector',
      hierarchyPath: const <String>[
        'Combustion system',
        'Burner 4',
        'Flame supervision',
        'UV detector',
      ],
      ancestors: const <String>[
        'combustion-system',
        'burner-4',
        'flame-supervision',
      ],
      nodeType: AssetHierarchyNodeType.subcomponent,
    );

    final reference = componentDefinitionReferenceForAsset(
      asset: asset,
      node: node,
    );

    expect(
      reference.scope,
      AssetHierarchyReferenceScope.componentDefinitionOnAsset,
    );
    expect(reference.assetInstanceId, asset.id);
    expect(reference.assetInstanceVersion, asset.version);
    expect(reference.assetNumber, 12);
    expect(reference.nodeId, node.id);
    expect(reference.nodeVersion, node.version);
    expect(reference.hierarchyPath, node.hierarchyPath);
    expect(reference.ownerDiscipline, 'I&A');
  });

  test(
    'supports a separate definition class for Inner Cover work on a Base',
    () {
      final node = _node(
        now: now,
        id: 'inner-cover-shell',
        assetClassId: 'inner-cover-class',
        hierarchyPath: const <String>['Shell assembly', 'Corrugated shell'],
        ancestors: const <String>['shell-assembly'],
      );

      final reference = componentDefinitionReferenceForAsset(
        asset: asset,
        node: node,
        definitionAssetClassId: 'inner-cover-class',
      );

      expect(reference.assetClassId, asset.assetClassId);
      expect(reference.assetInstanceId, asset.id);
      expect(reference.nodeId, 'inner-cover-shell');
    },
  );

  test(
    'rejects inactive assets and inactive or cross-class hierarchy nodes',
    () {
      final activeNode = _node(
        now: now,
        id: 'burner-block',
        hierarchyPath: const <String>['Burner assembly', 'Burner block'],
        ancestors: const <String>['burner-assembly'],
      );
      final retiredAsset = _assetWithStatus(
        asset,
        AssetHierarchyStatus.retired,
      );
      final retiredNode = _node(
        now: now,
        id: 'retired-block',
        hierarchyPath: const <String>['Burner assembly', 'Retired block'],
        ancestors: const <String>['burner-assembly'],
        status: AssetHierarchyStatus.retired,
      );
      final otherClassNode = _node(
        now: now,
        id: 'base-fan',
        assetClassId: 'base-class',
        hierarchyPath: const <String>['Cooling system', 'Base fan'],
        ancestors: const <String>['cooling-system'],
      );

      expect(
        () => componentDefinitionReferenceForAsset(
          asset: retiredAsset,
          node: activeNode,
        ),
        throwsStateError,
      );
      expect(
        () => componentDefinitionReferenceForAsset(
          asset: asset,
          node: retiredNode,
        ),
        throwsStateError,
      );
      expect(
        () => componentDefinitionReferenceForAsset(
          asset: asset,
          node: otherClassNode,
        ),
        throwsStateError,
      );
    },
  );

  test('rejects grouping and assembly nodes as final work targets', () {
    for (final nodeType in <AssetHierarchyNodeType>[
      AssetHierarchyNodeType.grouping,
      AssetHierarchyNodeType.assembly,
    ]) {
      final node = _node(
        now: now,
        id: nodeType.name,
        hierarchyPath: <String>[nodeType.name],
        nodeType: nodeType,
      );
      expect(
        () => componentDefinitionReferenceForAsset(asset: asset, node: node),
        throwsStateError,
      );
    }
  });
}

AssetHierarchyNode _node({
  required DateTime now,
  required String id,
  required List<String> hierarchyPath,
  String assetClassId = 'furnace-class',
  List<String> ancestors = const <String>[],
  AssetHierarchyNodeType nodeType = AssetHierarchyNodeType.component,
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetHierarchyNode(
  id: id,
  assetClassId: assetClassId,
  parentNodeId: ancestors.isEmpty ? null : ancestors.last,
  nodeType: nodeType,
  name: hierarchyPath.last,
  discipline: 'Instrumentation',
  operatingType: 'Electrical sensing',
  contactArrangement: ElectricalContactArrangement.notStated,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'I&A',
  accountableRoleKeys: const <String>['seniorInstrumentation'],
  sortOrder: 10,
  ancestorNodeIds: ancestors,
  hierarchyPath: hierarchyPath,
  activeChildCount: 0,
  status: status,
  version: 3,
  createdAt: now,
  createdByUid: 'admin-1',
  updatedAt: now,
  updatedByUid: 'admin-1',
  lastMutationId: 'node-mutation-3',
);

AssetInstanceRecord _assetWithStatus(
  AssetInstanceRecord source,
  AssetHierarchyStatus status,
) => AssetInstanceRecord(
  id: source.id,
  assetClassId: source.assetClassId,
  assetClassCode: source.assetClassCode,
  assetClassName: source.assetClassName,
  assetNumber: source.assetNumber,
  name: source.name,
  plantTag: source.plantTag,
  location: source.location,
  manufacturer: source.manufacturer,
  model: source.model,
  serialNumber: source.serialNumber,
  commissionedOn: source.commissionedOn,
  serviceState: source.serviceState,
  ownershipStatus: source.ownershipStatus,
  ownerDiscipline: source.ownerDiscipline,
  accountableRoleKeys: source.accountableRoleKeys,
  status: status,
  activeComponentCount: source.activeComponentCount,
  version: source.version,
  createdAt: source.createdAt,
  updatedAt: source.updatedAt,
  lastMutationId: source.lastMutationId,
);
