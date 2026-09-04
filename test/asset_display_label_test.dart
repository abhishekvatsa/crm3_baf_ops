import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:flutter_test/flutter_test.dart';

AssetInstanceRecord _asset(
  int number,
  String name, {
  String className = 'Furnace',
}) => AssetInstanceRecord(
  id: 'asset-$number',
  assetClassId: 'class',
  assetClassCode: 'FURNACE',
  assetClassName: className,
  assetNumber: number,
  name: name,
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  lastMutationId: 'original',
);

void main() {
  for (var number = 1; number <= 26; number++) {
    test('Furnace $number has one label without changing stored identity', () {
      final name = 'Furnace ${number.toString().padLeft(2, '0')}';
      final asset = _asset(number, name);
      expect(asset.displayLabel, name);
      expect(asset.assetNumber, number);
      expect(asset.name, name);
      expect(asset.version, 1);
      expect(asset.draft.name, name);
    });
  }
  test('meaningful aliases and mismatched identities remain visible', () {
    expect(_asset(3, 'North bay').displayLabel, 'Furnace 3 - North bay');
    expect(_asset(3, 'Furnace 13').displayLabel, 'Furnace 3 - Furnace 13');
    expect(
      _asset(3, 'Furnace 03 backup').displayLabel,
      'Furnace 3 - Furnace 03 backup',
    );
    expect(_asset(3, ' ').displayLabel, 'Furnace 3');
    expect(_asset(3, ' furnace  003 ').displayLabel, 'furnace  003');
  });
  test('other classes and literal punctuation are supported', () {
    expect(_asset(101, 'Base 101', className: 'Base').displayLabel, 'Base 101');
    expect(
      _asset(1, 'Forced Cooler 01', className: 'Forced Cooler').displayLabel,
      'Forced Cooler 01',
    );
    expect(
      _asset(2, 'Crane (A) 02', className: 'Crane (A)').displayLabel,
      'Crane (A) 02',
    );
  });
}
