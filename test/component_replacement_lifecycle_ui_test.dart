import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_asset_hierarchy_tab.dart';
import 'package:crm3_baf_ops/features/admin/providers/admin_stream_providers.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'component replacement and lifecycle history remain usable on phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 8, 16, 1, 30);
      final assetClass = AssetClassRecord(
        id: 'furnace-class',
        code: 'FURNACE',
        name: 'Furnace',
        majorArea: 'BAF shop',
        legacyAssetTypeKey: 'furnace',
        status: AssetHierarchyStatus.active,
        version: 1,
        createdAt: now,
        createdByUid: 'admin-1',
        updatedAt: now,
        updatedByUid: 'admin-1',
        lastMutationId: 'class-mutation',
      );
      final definition = AssetHierarchyNode(
        id: 'burner-block',
        assetClassId: assetClass.id,
        nodeType: AssetHierarchyNodeType.component,
        name: 'Burner block',
        contactArrangement: ElectricalContactArrangement.notApplicable,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Instrumentation',
        accountableRoleKeys: const ['seniorInstrumentation'],
        sortOrder: 10,
        ancestorNodeIds: const [],
        hierarchyPath: const ['Combustion system', 'Burner block'],
        activeChildCount: 0,
        status: AssetHierarchyStatus.active,
        version: 1,
        createdAt: now,
        createdByUid: 'admin-1',
        updatedAt: now,
        updatedByUid: 'admin-1',
        lastMutationId: 'node-mutation',
      );
      final asset = AssetInstanceRecord(
        id: 'furnace-1',
        assetClassId: assetClass.id,
        assetClassCode: assetClass.code,
        assetClassName: assetClass.name,
        assetNumber: 1,
        name: 'Furnace 1',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Operations',
        accountableRoleKeys: const ['operations'],
        status: AssetHierarchyStatus.active,
        activeComponentCount: 1,
        version: 2,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'asset-mutation',
      );
      final component = InstalledComponentRecord(
        id: 'component-1',
        assetInstanceId: asset.id,
        assetInstanceVersionAtMutation: 1,
        assetNumber: asset.assetNumber,
        assetInstanceName: asset.name,
        assetClassId: assetClass.id,
        assetClassCode: assetClass.code,
        assetClassName: assetClass.name,
        definitionNodeId: definition.id,
        definitionNodeVersion: definition.version,
        definitionName: definition.name,
        hierarchyPath: definition.hierarchyPath,
        componentTag: 'FR-01-B01-BLOCK',
        manufacturer: 'Example Works',
        model: 'BB-1',
        serialNumber: 'OLD-001',
        installedOn: now.subtract(const Duration(days: 300)),
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Instrumentation',
        accountableRoleKeys: const ['seniorInstrumentation'],
        status: AssetHierarchyStatus.active,
        version: 1,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'component-mutation',
      );
      final resolvedIssue =
          MaintenanceRecord()
            ..firestoreId = 'issue-pt-1'
            ..version = 4
            ..isDeleted = false
            ..assetType = AssetType.furnace
            ..assetNumber = asset.assetNumber
            ..assetHierarchyRefJson =
                AssetHierarchyReference(
                  scope: AssetHierarchyReferenceScope.installedComponent,
                  assetClassId: asset.assetClassId,
                  assetClassCode: asset.assetClassCode,
                  assetClassName: asset.assetClassName,
                  nodeId: definition.id,
                  nodeVersion: definition.version,
                  nodeName: definition.name,
                  assetInstanceId: asset.id,
                  assetInstanceVersion: asset.version,
                  assetNumber: asset.assetNumber,
                  assetInstanceName: asset.name,
                  componentInstanceId: component.id,
                  componentInstanceVersion: component.version,
                  componentTag: component.componentTag,
                  hierarchyPath: definition.hierarchyPath,
                  ownershipStatus: AssetOwnershipStatus.confirmed,
                  ownerDiscipline: 'Instrumentation',
                  accountableRoleKeys: const ['seniorInstrumentation'],
                ).encode()
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Pressure transmitter failed calibration'
            ..routedTo = RoutedTo.instrumentation
            ..status = TicketStatus.resolved
            ..isResolved = true
            ..closedByUid = 'admin-1'
            ..closedByName = 'Admin One'
            ..startDate = now.subtract(const Duration(hours: 4))
            ..endDate = now.subtract(const Duration(hours: 1))
            ..createdAt = now.subtract(const Duration(hours: 4))
            ..updatedAt = now.subtract(const Duration(hours: 1));
      final audit = InstalledComponentLifecycleAudit(
        id: 'audit-1',
        entityId: component.id,
        action: 'create',
        reason: 'Install the original burner block.',
        afterJson: '{"status":"active"}',
        performedByName: 'Admin One',
        performedAt: now,
        requestId: 'request-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminTicketsStreamProvider.overrideWith(
              (ref) => Stream.value(<MaintenanceRecord>[resolvedIssue]),
            ),
            adminExecutionsStreamProvider.overrideWith(
              (ref) => Stream.value(const <JobExecution>[]),
            ),
            assetClassesProvider.overrideWith(
              (ref) => Stream.value([assetClass]),
            ),
            assetHierarchyNodesProvider(
              assetClass.id,
            ).overrideWith((ref) => Stream.value([definition])),
            assetInstancesProvider(
              assetClass.id,
            ).overrideWith((ref) => Stream.value([asset])),
            installedComponentsProvider(
              asset.id,
            ).overrideWith((ref) => Stream.value([component])),
            installedComponentHistoryProvider(
              asset.id,
            ).overrideWith((ref) => Stream.value([audit])),
          ],
          child: MaterialApp(
            home: Scaffold(body: AssetHierarchyAdminTab(actor: _admin(now))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Physical assets'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Component actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace component'));
      await tester.pumpAndSettle();

      expect(find.text('Replace installed component'), findsOneWidget);
      expect(find.text('Replacement installed on'), findsOneWidget);
      expect(find.text('Completed work evidence'), findsOneWidget);
      expect(find.text('Manual Admin confirmation'), findsOneWidget);
      await tester.tap(find.text('Manual Admin confirmation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Resolved issue · Pressure transmitter'),
        findsOneWidget,
      );
      await tester.tap(
        find.textContaining('Resolved issue · Pressure transmitter'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Replace'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Component actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lifecycle history'));
      await tester.pumpAndSettle();

      expect(find.text('Component lifecycle history'), findsOneWidget);
      expect(find.text('Installed'), findsOneWidget);
      expect(
        find.textContaining('Install the original burner block.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

AppUser _admin(DateTime now) => AppUser(
  uid: 'admin-1',
  name: 'Admin One',
  email: 'admin@example.com',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: now,
);
