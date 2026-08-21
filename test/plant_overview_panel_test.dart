import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home panel shows total, available, maintenance and unavailable',
    (tester) async {
      final now = DateTime.utc(2026, 8, 14);
      final assetClass = AssetClassRecord(
        id: 'furnace-class',
        code: 'FURNACE',
        name: 'Furnace',
        majorArea: 'BAF Shop',
        legacyAssetTypeKey: 'furnace',
        status: AssetHierarchyStatus.active,
        version: 1,
        createdAt: now,
        createdByUid: 'admin',
        updatedAt: now,
        updatedByUid: 'admin',
        lastMutationId: 'class-mutation',
      );
      AssetInstanceRecord asset(String id, int number) => AssetInstanceRecord(
        id: id,
        assetClassId: assetClass.id,
        assetClassCode: assetClass.code,
        assetClassName: assetClass.name,
        assetNumber: number,
        name: 'Furnace $number',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Operations',
        accountableRoleKeys: const ['operations'],
        status: AssetHierarchyStatus.active,
        activeComponentCount: 0,
        version: 1,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'asset-mutation-$number',
      );
      final first = asset('furnace-1', 1);
      final second = asset('furnace-2', 2);
      final status =
          EquipmentStatusRecord()
            ..assetTypeKey = 'furnace'
            ..assetNumber = 1
            ..openMaintenanceCount = 1;
      final condition = AssetOperationalConditionRecord(
        assetInstanceId: first.id,
        assetClassId: first.assetClassId,
        assetClassCode: first.assetClassCode,
        assetClassName: first.assetClassName,
        assetNumber: first.assetNumber,
        assetName: first.name,
        condition: AssetOperationalCondition.down,
        active: true,
        causes: const [AssetConditionCause.breakdown],
        reason: 'Drive fault prevents safe operation.',
        linkedIssueIds: const [],
        declaredAt: now,
        declaredByUid: 'ops',
        declaredByName: 'Operations',
        restoredAt: null,
        restoredByUid: null,
        restoredByName: null,
        previousCondition: AssetOperationalCondition.available,
        version: 1,
        updatedAt: now,
        updatedByUid: 'ops',
        updatedByName: 'Operations',
        lastMutationId: 'condition-mutation',
      );
      final overview = PlantAssetOverview.build(
        assetClasses: [assetClass],
        assetInstances: [first, second],
        operationalConditions: [condition],
        workflowStatuses: [status],
      );
      var opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlantOverviewPanel(
              overview: AsyncData(overview),
              onOpen: () => opened = true,
            ),
          ),
        ),
      );

      expect(find.text('2 registered'), findsNothing);
      expect(find.text('1 available'), findsOneWidget);
      expect(find.text('1 maintenance'), findsOneWidget);
      expect(find.text('0 stuck-up'), findsOneWidget);
      expect(find.text('1 down'), findsOneWidget);
      expect(
        find.text(
          'Furnace: 2 total, 1 maintenance, 0 stuck-up, 1 unavailable',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Plant condition'));
      expect(opened, isTrue);
    },
  );

  testWidgets(
    'Home panel exposes verified-data failure instead of zero counts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlantOverviewPanel(
              overview: AsyncError(StateError('malformed'), StackTrace.empty),
              onOpen: () {},
            ),
          ),
        ),
      );
      expect(
        find.text(
          'Plant condition data needs attention. Open the board for details.',
        ),
        findsOneWidget,
      );
    },
  );
}
