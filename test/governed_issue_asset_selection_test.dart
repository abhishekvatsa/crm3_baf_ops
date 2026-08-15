import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/governed_issue_asset_selection.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 15);

AssetClassRecord _assetClass({
  required String id,
  required String code,
  required String name,
  String? legacyAssetTypeKey,
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) {
  return AssetClassRecord(
    id: id,
    code: code,
    name: name,
    majorArea: 'BAF',
    legacyAssetTypeKey: legacyAssetTypeKey,
    status: status,
    version: 3,
    createdAt: _now,
    createdByUid: 'admin-1',
    updatedAt: _now,
    updatedByUid: 'admin-1',
    lastMutationId: 'mutation-$id',
  );
}

AssetInstanceRecord _asset({
  required String id,
  required AssetClassRecord assetClass,
  required int number,
  String? name,
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
  AssetServiceState serviceState = AssetServiceState.inService,
}) {
  return AssetInstanceRecord(
    id: id,
    assetClassId: assetClass.id,
    assetClassCode: assetClass.code,
    assetClassName: assetClass.name,
    assetNumber: number,
    name: name ?? '${assetClass.name} $number',
    serviceState: serviceState,
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Mechanical',
    accountableRoleKeys: const ['seniorMechanical'],
    status: status,
    activeComponentCount: 4,
    version: 7,
    createdAt: _now,
    updatedAt: _now,
    lastMutationId: 'mutation-$id',
  );
}

void main() {
  group('governed issue asset selection', () {
    test('offers active classes in deterministic display order', () {
      final result = activeIssueAssetClasses([
        _assetClass(id: 'z', code: 'ZZ', name: 'Transfer Car'),
        _assetClass(id: 'b', code: 'B2', name: 'Base'),
        _assetClass(id: 'a', code: 'B1', name: 'base'),
        _assetClass(
          id: 'retired',
          code: 'FC',
          name: 'Forced Cooler',
          status: AssetHierarchyStatus.retired,
        ),
      ]);

      expect(result.map((item) => item.id), ['a', 'b', 'z']);
    });

    test('routes a custom class to its own physical assets', () {
      final utility = _assetClass(
        id: 'utility',
        code: 'UTILITY',
        name: 'Utilities',
      );

      final route = resolveGovernedIssueAssetRoute(
        issueClass: utility,
        allClasses: [utility],
      );

      expect(route.isAvailable, isTrue);
      expect(route.assetType, AssetType.governedCustom);
      expect(route.physicalAssetClass, same(utility));
      expect(route.innerCoverByBase, isFalse);
    });

    test(
      'routes Inner Cover reporting through the single active Base class',
      () {
        final innerCover = _assetClass(
          id: 'inner-cover',
          code: 'IC',
          name: 'Inner Cover',
          legacyAssetTypeKey: 'innerCover',
        );
        final base = _assetClass(
          id: 'base',
          code: 'BASE',
          name: 'Base',
          legacyAssetTypeKey: 'base',
        );

        final route = resolveGovernedIssueAssetRoute(
          issueClass: innerCover,
          allClasses: [innerCover, base],
        );

        expect(route.isAvailable, isTrue);
        expect(route.assetType, AssetType.innerCover);
        expect(route.physicalAssetClass, same(base));
        expect(route.innerCoverByBase, isTrue);
      },
    );

    test('blocks Inner Cover reporting when Base authority is ambiguous', () {
      final innerCover = _assetClass(
        id: 'inner-cover',
        code: 'IC',
        name: 'Inner Cover',
        legacyAssetTypeKey: 'innerCover',
      );
      final baseA = _assetClass(
        id: 'base-a',
        code: 'BASE_A',
        name: 'Base A',
        legacyAssetTypeKey: 'base',
      );
      final baseB = _assetClass(
        id: 'base-b',
        code: 'BASE_B',
        name: 'Base B',
        legacyAssetTypeKey: 'base',
      );

      final absent = resolveGovernedIssueAssetRoute(
        issueClass: innerCover,
        allClasses: [innerCover],
      );
      final duplicate = resolveGovernedIssueAssetRoute(
        issueClass: innerCover,
        allClasses: [innerCover, baseA, baseB],
      );

      expect(absent.isAvailable, isFalse);
      expect(absent.blockingReason, contains('No active governed Base'));
      expect(duplicate.isAvailable, isFalse);
      expect(duplicate.blockingReason, contains('More than one active'));
    });

    test(
      'keeps active matching assets and orders them by number then name',
      () {
        final furnace = _assetClass(
          id: 'furnace',
          code: 'FURNACE',
          name: 'Furnace',
          legacyAssetTypeKey: 'furnace',
        );
        final other = _assetClass(id: 'other', code: 'OTHER', name: 'Other');
        final route = resolveGovernedIssueAssetRoute(
          issueClass: furnace,
          allClasses: [furnace, other],
        );

        final result = eligibleIssueAssets(
          route: route,
          assets: [
            _asset(id: 'f2b', assetClass: furnace, number: 2, name: 'Zulu'),
            _asset(id: 'f1', assetClass: furnace, number: 1),
            _asset(id: 'f2a', assetClass: furnace, number: 2, name: 'Alpha'),
            _asset(
              id: 'retired',
              assetClass: furnace,
              number: 3,
              status: AssetHierarchyStatus.retired,
            ),
            _asset(id: 'other', assetClass: other, number: 1),
          ],
        );

        expect(result.map((item) => item.id), ['f1', 'f2a', 'f2b']);
      },
    );

    test('freezes the exact governed physical asset identity', () {
      final base = _assetClass(
        id: 'base',
        code: 'BASE',
        name: 'Base',
        legacyAssetTypeKey: 'base',
      );
      final asset = _asset(
        id: 'base-201',
        assetClass: base,
        number: 201,
        serviceState: AssetServiceState.outOfService,
      );

      final reference = asset.toReference();

      expect(reference.scope, AssetHierarchyReferenceScope.physicalAsset);
      expect(reference.assetClassId, 'base');
      expect(reference.assetInstanceId, 'base-201');
      expect(reference.assetInstanceVersion, 7);
      expect(reference.assetNumber, 201);
      expect(reference.hierarchyPath, ['Base', 'Base 201']);
      expect(reference.ownerDiscipline, 'Mechanical');
      expect(reference.accountableRoleKeys, ['seniorMechanical']);
    });
  });
}
