import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/governed_planned_work_asset_selection.dart';
import 'package:flutter_test/flutter_test.dart';

AssetClassRecord _class({
  required String id,
  required String name,
  String? legacyKey,
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetClassRecord(
  id: id,
  code: id.toUpperCase(),
  name: name,
  status: status,
  majorArea: 'BAF',
  legacyAssetTypeKey: legacyKey,
  version: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  createdByUid: 'admin-1',
  updatedAt: DateTime.utc(2026, 8, 1),
  updatedByUid: 'admin-1',
  lastMutationId: 'mutation-1',
);

AssetInstanceRecord _asset({
  required String id,
  required AssetClassRecord assetClass,
  required int number,
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetInstanceRecord(
  id: id,
  assetClassId: assetClass.id,
  assetClassCode: assetClass.code,
  assetClassName: assetClass.name,
  assetNumber: number,
  name: '${assetClass.name} $number',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  accountableRoleKeys: const ['admin'],
  status: status,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
  lastMutationId: 'mutation-1',
);

AssetHierarchyReference _definition(AssetClassRecord assetClass) =>
    AssetHierarchyReference(
      assetClassId: assetClass.id,
      assetClassCode: assetClass.code,
      assetClassName: assetClass.name,
      nodeId: 'root',
      nodeVersion: 1,
      nodeName: 'Whole asset',
      hierarchyPath: const ['Whole asset'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      accountableRoleKeys: const ['admin'],
    );

void main() {
  group('governed planned-work asset selection', () {
    test('uses the exact published class for a legacy asset type', () {
      final furnace = _class(
        id: 'furnace',
        name: 'Furnace',
        legacyKey: 'furnace',
      );
      final route = resolveGovernedPlannedWorkAssetRoute(
        assetType: AssetType.furnace,
        templateReference: _definition(furnace),
        allClasses: [furnace],
      );

      expect(route.isAvailable, isTrue);
      expect(route.physicalAssetClass?.id, furnace.id);
    });

    test('fails closed on an ambiguous unscoped legacy class', () {
      final first = _class(
        id: 'furnace-a',
        name: 'Furnace A',
        legacyKey: 'furnace',
      );
      final second = _class(
        id: 'furnace-b',
        name: 'Furnace B',
        legacyKey: 'furnace',
      );

      final route = resolveGovernedPlannedWorkAssetRoute(
        assetType: AssetType.furnace,
        templateReference: null,
        allClasses: [first, second],
      );

      expect(route.isAvailable, isFalse);
      expect(route.blockingReason, contains('More than one'));
    });

    test(
      'fails closed on duplicate legacy mappings despite an exact template',
      () {
        final first = _class(
          id: 'furnace-a',
          name: 'Furnace A',
          legacyKey: 'furnace',
        );
        final second = _class(
          id: 'furnace-b',
          name: 'Furnace B',
          legacyKey: 'furnace',
        );

        final route = resolveGovernedPlannedWorkAssetRoute(
          assetType: AssetType.furnace,
          templateReference: _definition(first),
          allClasses: [first, second],
        );

        expect(route.isAvailable, isFalse);
        expect(route.blockingReason, contains('Reconcile'));
      },
    );

    test('routes Inner Cover planned work through the unique Base class', () {
      final innerCover = _class(
        id: 'inner-cover',
        name: 'Inner Cover',
        legacyKey: 'innerCover',
      );
      final base = _class(id: 'base', name: 'Base', legacyKey: 'base');

      final route = resolveGovernedPlannedWorkAssetRoute(
        assetType: AssetType.innerCover,
        templateReference: _definition(innerCover),
        allClasses: [innerCover, base],
      );

      expect(route.isAvailable, isTrue);
      expect(route.innerCoverByBase, isTrue);
      expect(route.physicalAssetClass?.id, base.id);
    });

    test('requires a published class for governed custom work', () {
      final custom = _class(id: 'car', name: 'Transfer Car');

      final route = resolveGovernedPlannedWorkAssetRoute(
        assetType: AssetType.governedCustom,
        templateReference: null,
        allClasses: [custom],
      );

      expect(route.isAvailable, isFalse);
      expect(route.blockingReason, contains('no published asset-class'));
    });

    test('limits an instance-scoped template to its frozen asset', () {
      final custom = _class(id: 'car', name: 'Transfer Car');
      final selected = _asset(id: 'car-3', assetClass: custom, number: 3);
      final other = _asset(id: 'car-4', assetClass: custom, number: 4);
      final reference = selected.toReference();

      final route = resolveGovernedPlannedWorkAssetRoute(
        assetType: AssetType.governedCustom,
        templateReference: reference,
        allClasses: [custom],
      );
      final eligible = eligiblePlannedWorkAssets(
        route: route,
        assets: [other, selected],
      );

      expect(route.fixedAssetInstanceId, selected.id);
      expect(eligible.map((item) => item.id), [selected.id]);
    });

    test('filters inactive assets and sorts by governed number', () {
      final base = _class(id: 'base', name: 'Base', legacyKey: 'base');
      final route = resolveGovernedPlannedWorkAssetRoute(
        assetType: AssetType.base,
        templateReference: _definition(base),
        allClasses: [base],
      );

      final eligible = eligiblePlannedWorkAssets(
        route: route,
        assets: [
          _asset(id: 'base-202', assetClass: base, number: 202),
          _asset(
            id: 'base-201-retired',
            assetClass: base,
            number: 201,
            status: AssetHierarchyStatus.retired,
          ),
          _asset(id: 'base-101', assetClass: base, number: 101),
        ],
      );

      expect(eligible.map((item) => item.assetNumber), [101, 202]);
    });
  });
}
