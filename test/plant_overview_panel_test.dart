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
      final third = asset('furnace-3', 3);
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
      final unfitCondition = AssetOperationalConditionRecord(
        assetInstanceId: third.id,
        assetClassId: third.assetClassId,
        assetClassCode: third.assetClassCode,
        assetClassName: third.assetClassName,
        assetNumber: third.assetNumber,
        assetName: third.name,
        condition: AssetOperationalCondition.unfit,
        active: true,
        causes: const [AssetConditionCause.safety],
        reason: 'Inspection found the asset unfit for operation.',
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
        lastMutationId: 'unfit-condition-mutation',
      );
      final overview = PlantAssetOverview.build(
        assetClasses: [assetClass],
        assetInstances: [first, second, third],
        operationalConditions: [condition, unfitCondition],
        workflowStatuses: [status],
      );
      var opened = false;
      AssetConditionFilter? selectedFilter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlantOverviewPanel(
              overview: AsyncData(overview),
              onOpen: () => opened = true,
              onOpenFiltered: (filter) => selectedFilter = filter,
            ),
          ),
        ),
      );

      expect(find.text('2 registered'), findsNothing);
      expect(find.text('1 available'), findsOneWidget);
      expect(find.text('1 maintenance'), findsOneWidget);
      expect(find.text('0 stuck-up'), findsOneWidget);
      expect(find.text('1 down'), findsOneWidget);
      expect(find.text('1 unfit'), findsOneWidget);
      expect(find.text('Furnace'), findsOneWidget);
      expect(find.text('3 registered'), findsOneWidget);
      expect(find.text('Maintenance 1: Furnace 1'), findsOneWidget);
      expect(find.text('Down 1: Furnace 1'), findsOneWidget);
      expect(find.text('Unfit 1: Furnace 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plant-condition-down')));
      expect(selectedFilter, AssetConditionFilter.down);
      expect(opened, isFalse);
      await tester.tap(find.text('Plant condition'));
      expect(opened, isTrue);
    },
  );

  testWidgets('Home panel retains every registered asset class', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 14);
    final classes = <AssetClassRecord>[
      _assetClass(id: 'base', code: 'BASE', name: 'Base', now: now),
      _assetClass(
        id: 'cooler',
        code: 'COOLER',
        name: 'Forced cooler',
        now: now,
      ),
      _assetClass(id: 'furnace', code: 'FURNACE', name: 'Furnace', now: now),
    ];
    final assets =
        classes
            .map(
              (assetClass) => AssetInstanceRecord(
                id: '${assetClass.id}-1',
                assetClassId: assetClass.id,
                assetClassCode: assetClass.code,
                assetClassName: assetClass.name,
                assetNumber: 1,
                name: '${assetClass.name} 1',
                serviceState: AssetServiceState.inService,
                ownershipStatus: AssetOwnershipStatus.confirmed,
                ownerDiscipline: 'Operations',
                accountableRoleKeys: const ['operations'],
                status: AssetHierarchyStatus.active,
                activeComponentCount: 0,
                version: 1,
                createdAt: now,
                updatedAt: now,
                lastMutationId: '${assetClass.id}-asset',
              ),
            )
            .toList();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlantOverviewPanel(
            overview: AsyncData(
              PlantAssetOverview.build(
                assetClasses: classes,
                assetInstances: assets,
                operationalConditions: const [],
                workflowStatuses: const [],
              ),
            ),
            onOpen: () {},
          ),
        ),
      ),
    );

    expect(find.text('Base'), findsOneWidget);
    expect(find.text('Forced cooler'), findsOneWidget);
    expect(find.text('Furnace'), findsOneWidget);
    expect(
      find.text('All registered assets are in the available state.'),
      findsNWidgets(3),
    );
  });

  testWidgets('Home panel wraps named condition details on compact phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 8, 30);
    final assetClass = _assetClass(
      id: 'furnace',
      code: 'FURNACE',
      name: 'Furnace',
      now: now,
    );
    final assets = List.generate(
      4,
      (index) => AssetInstanceRecord(
        id: 'furnace-${index + 1}',
        assetClassId: assetClass.id,
        assetClassCode: assetClass.code,
        assetClassName: assetClass.name,
        assetNumber: index + 1,
        name: 'Annealing unit',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Operations',
        accountableRoleKeys: const ['operations'],
        status: AssetHierarchyStatus.active,
        activeComponentCount: 0,
        version: 1,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'asset-${index + 1}',
      ),
    );
    final conditions = assets
        .map(
          (asset) => AssetOperationalConditionRecord(
            assetInstanceId: asset.id,
            assetClassId: asset.assetClassId,
            assetClassCode: asset.assetClassCode,
            assetClassName: asset.assetClassName,
            assetNumber: asset.assetNumber,
            assetName: asset.name,
            condition: AssetOperationalCondition.down,
            active: true,
            causes: const [AssetConditionCause.breakdown],
            reason: 'Unavailable for maintenance.',
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
            lastMutationId: 'condition-${asset.assetNumber}',
          ),
        )
        .toList(growable: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlantOverviewPanel(
              overview: AsyncData(
                PlantAssetOverview.build(
                  assetClasses: [assetClass],
                  assetInstances: assets,
                  operationalConditions: conditions,
                  workflowStatuses: const [],
                ),
              ),
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Down 4: Furnace 1 - Annealing unit, '
        'Furnace 2 - Annealing unit, '
        'Furnace 3 - Annealing unit, '
        'Furnace 4 - Annealing unit',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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

AssetClassRecord _assetClass({
  required String id,
  required String code,
  required String name,
  required DateTime now,
}) => AssetClassRecord(
  id: id,
  code: code,
  name: name,
  majorArea: 'BAF Shop',
  legacyAssetTypeKey: null,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: now,
  createdByUid: 'admin',
  updatedAt: now,
  updatedByUid: 'admin',
  lastMutationId: '$id-mutation',
);
