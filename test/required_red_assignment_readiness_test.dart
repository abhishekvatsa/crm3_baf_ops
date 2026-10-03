import 'dart:async';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/governed_planned_work_asset_selection.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/governed_planned_work_asset_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/required_red_journey.dart'
    show selectRequiredRedParentAsset;

final _class = AssetClassRecord(
  id: 'seed-class-annealing-furnace',
  code: 'FURNACE',
  name: 'Furnace',
  status: AssetHierarchyStatus.active,
  majorArea: 'BAF',
  legacyAssetTypeKey: 'furnace',
  version: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  createdByUid: 'admin-1',
  updatedAt: DateTime.utc(2026, 8, 1),
  updatedByUid: 'admin-1',
  lastMutationId: 'mutation-1',
);
final _asset = AssetInstanceRecord(
  id: 'seed-asset-furnace-01',
  assetClassId: _class.id,
  assetClassCode: _class.code,
  assetClassName: _class.name,
  assetNumber: 1,
  name: 'Furnace 01',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  accountableRoleKeys: const ['admin'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
  lastMutationId: 'mutation-1',
);

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  testWidgets('RED asset selection follows a replaced loading catalogue once', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    final selected = <String>[];
    int? selectionsBeforeReady;
    final timer = Timer(const Duration(milliseconds: 1700), () {
      selectionsBeforeReady = selected.length;
      ready.value = true;
    });
    addTearDown(timer.cancel);
    await tester.pumpWidget(_catalogue(ready, selected));
    final initialList = tester.element(find.byType(ListView));
    await selectRequiredRedParentAsset(tester, maxReadinessPumps: 50);
    await tester.pumpAndSettle();
    expect(
      identical(initialList, tester.element(find.byType(ListView))),
      isFalse,
    );
    expect(selectionsBeforeReady, 0);
    expect(selected, ['seed-asset-furnace-01']);
    expect(tester.takeException(), isNull);
  });

  for (final blocked in ['loading', 'disabled', 'missing exact asset']) {
    testWidgets('RED readiness fails bounded without selecting: $blocked', (
      tester,
    ) async {
      final ready = ValueNotifier(blocked != 'loading');
      addTearDown(ready.dispose);
      final selected = <String>[];
      await tester.pumpWidget(
        _catalogue(
          ready,
          selected,
          disabled: blocked == 'disabled',
          missingAsset: blocked == 'missing exact asset',
        ),
      );
      Object? failure;
      try {
        await selectRequiredRedParentAsset(tester, maxReadinessPumps: 25);
      } catch (error) {
        failure = error;
      }
      expect(
        failure,
        isA<TestFailure>().having(
          (error) => error.message,
          'message',
          contains('exact governed asset identity'),
        ),
      );
      expect(selected, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _catalogue(
  ValueNotifier<bool> ready,
  List<String> selected, {
  bool disabled = false,
  bool missingAsset = false,
}) => MaterialApp(
  home: Scaffold(
    body: ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (context, loaded, _) => ListView(
        key: ValueKey('catalogue-$loaded'),
        children: [
          const SizedBox(
            height: 900,
            child: Text('Published package catalogue'),
          ),
          GovernedPlannedWorkAssetSelector(
            assetType: AssetType.furnace,
            classesValue: AsyncData([_class]),
            route: resolveGovernedPlannedWorkAssetRoute(
              assetType: AssetType.furnace,
              templateReference: null,
              allClasses: [_class],
            ),
            assetsValue: loaded ? AsyncData([_asset]) : const AsyncLoading(),
            innerCoverAssignmentsValue: null,
            linkedInnerCoversByBase: const {},
            eligibleAssets: missingAsset ? [] : [_asset],
            selectedAssetInstanceId: null,
            onAssetChanged: disabled
                ? null
                : (asset) => selected.add(asset!.id),
          ),
          const SizedBox(height: 500),
        ],
      ),
    ),
  ),
);
