import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_registry_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'approved operations can inspect asset and component lineage on phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.utc(2026, 8, 16, 4, 30);
      final asset = AssetInstanceRecord(
        id: 'furnace-12',
        assetClassId: 'furnace-class',
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        assetNumber: 12,
        name: 'Furnace 12',
        plantTag: 'FR-12',
        location: 'BAF bay 2',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Operations',
        accountableRoleKeys: const ['operations'],
        status: AssetHierarchyStatus.active,
        activeComponentCount: 1,
        version: 4,
        createdAt: now.subtract(const Duration(days: 900)),
        updatedAt: now,
        lastMutationId: 'asset-mutation',
      );
      final condition = AssetOperationalConditionRecord(
        assetInstanceId: asset.id,
        assetClassId: asset.assetClassId,
        assetClassCode: asset.assetClassCode,
        assetClassName: asset.assetClassName,
        assetNumber: asset.assetNumber,
        assetName: asset.name,
        condition: AssetOperationalCondition.down,
        active: true,
        causes: const [AssetConditionCause.breakdown],
        reason: 'Burner block replacement is in progress.',
        linkedIssueIds: const ['ticket-12'],
        declaredAt: now.subtract(const Duration(hours: 3)),
        declaredByUid: 'operations-1',
        declaredByName: 'Operations One',
        restoredAt: null,
        restoredByUid: null,
        restoredByName: null,
        previousCondition: AssetOperationalCondition.available,
        version: 1,
        updatedAt: now,
        updatedByUid: 'operations-1',
        updatedByName: 'Operations One',
        lastMutationId: 'condition-mutation',
      );
      final retired = _component(
        id: 'burner-block-old',
        asset: asset,
        lineageId: 'burner-block-lineage',
        tag: 'FR-12-B01-BLOCK-OLD',
        serial: 'BB-OLD-12',
        installedOn: now.subtract(const Duration(days: 420)),
        status: AssetHierarchyStatus.retired,
        replacedBy: 'burner-block-current',
        createdAt: now.subtract(const Duration(days: 420)),
      );
      final current = _component(
        id: 'burner-block-current',
        asset: asset,
        lineageId: 'burner-block-lineage',
        tag: 'FR-12-B01-BLOCK',
        serial: 'BB-NEW-12',
        installedOn: now.subtract(const Duration(days: 7)),
        status: AssetHierarchyStatus.active,
        replaces: retired.id,
        createdAt: now.subtract(const Duration(days: 7)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_operationsUser(now)),
            ),
            allAssetInstancesProvider.overrideWith(
              (ref) => Stream.value([asset]),
            ),
            assetOperationalConditionsProvider.overrideWith(
              (ref) => Stream.value([condition]),
            ),
            installedComponentsProvider(
              asset.id,
            ).overrideWith((ref) => Stream.value([current, retired])),
          ],
          child: const MaterialApp(home: AssetRegistryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asset registry'), findsOneWidget);
      expect(find.text('Furnace 12'), findsOneWidget);
      expect(find.text('Down'), findsOneWidget);
      expect(find.textContaining('1 active components'), findsOneWidget);
      expect(find.text('Replace component'), findsNothing);
      expect(find.text('Retire'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Furnace 12'));
      await tester.pumpAndSettle();

      expect(find.text('Installed components'), findsOneWidget);
      expect(find.text('Burner block'), findsWidgets);
      expect(find.text('FR-12-B01-BLOCK'), findsOneWidget);
      expect(find.text('Replacement lineage (2)'), findsWidgets);
      expect(find.byTooltip('Component actions'), findsNothing);
      expect(tester.takeException(), isNull);

      final lineageAction = find.text('Replacement lineage (2)').first;
      await tester.ensureVisible(lineageAction);
      await tester.pumpAndSettle();
      await tester.tap(lineageAction);
      await tester.pumpAndSettle();

      expect(find.text('Burner block replacement lineage'), findsOneWidget);
      expect(find.text('FR-12-B01-BLOCK-OLD'), findsWidgets);
      expect(find.text('FR-12-B01-BLOCK'), findsWidgets);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Replaced'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unapproved users cannot open the asset registry', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 16);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(
                uid: 'pending-1',
                name: 'Pending User',
                email: 'pending@example.com',
                roles: const [AppRole.operations],
                isApproved: false,
                createdAt: now,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AssetRegistryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved access is required.'), findsOneWidget);
    expect(find.text('Asset registry'), findsNothing);
  });
}

InstalledComponentRecord _component({
  required String id,
  required AssetInstanceRecord asset,
  required String lineageId,
  required String tag,
  required String serial,
  required DateTime installedOn,
  required AssetHierarchyStatus status,
  required DateTime createdAt,
  String? replaces,
  String? replacedBy,
}) => InstalledComponentRecord(
  id: id,
  componentLineageId: lineageId,
  replacesComponentInstanceId: replaces,
  replacedByComponentInstanceId: replacedBy,
  assetInstanceId: asset.id,
  assetInstanceVersionAtMutation: asset.version,
  assetNumber: asset.assetNumber,
  assetInstanceName: asset.name,
  assetClassId: asset.assetClassId,
  assetClassCode: asset.assetClassCode,
  assetClassName: asset.assetClassName,
  definitionNodeId: 'burner-block-definition',
  definitionNodeVersion: 2,
  definitionName: 'Burner block',
  hierarchyPath: const ['Combustion system', 'Burner block'],
  componentTag: tag,
  manufacturer: 'BAF Components Ltd',
  model: 'BB-8',
  serialNumber: serial,
  installedOn: installedOn,
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Instrumentation',
  accountableRoleKeys: const ['seniorInstrumentation'],
  status: status,
  version: 1,
  createdAt: createdAt,
  updatedAt: DateTime.utc(2026, 8, 16, 4, 30),
  lastMutationId: 'component-$id',
);

AppUser _operationsUser(DateTime now) => AppUser(
  uid: 'operations-1',
  name: 'Operations One',
  email: 'operations@example.com',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: now,
);
