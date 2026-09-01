import 'dart:async';

import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_asset_hierarchy_tab.dart';
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart';
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
    'asset hierarchy header scrolls and compact actions stay legible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 8, 28, 14);
      final assetClass = _assetClass(now);
      final nodes = List<AssetHierarchyNode>.generate(
        18,
        (index) => _hierarchyNode(index + 1, assetClass.id, now),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminTicketsStreamProvider.overrideWith(
              (ref) => Stream.value(const <MaintenanceRecord>[]),
            ),
            adminExecutionsStreamProvider.overrideWith(
              (ref) => Stream.value(const <JobExecution>[]),
            ),
            assetClassesProvider.overrideWith(
              (ref) => Stream.value(<AssetClassRecord>[assetClass]),
            ),
            assetHierarchyNodesProvider(
              assetClass.id,
            ).overrideWith((ref) => Stream.value(nodes)),
            assetInstancesProvider(assetClass.id).overrideWith(
              (ref) => Stream.value(const <AssetInstanceRecord>[]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 390,
                  height: 560,
                  child: AssetHierarchyAdminTab(
                    actor: _admin(now),
                    compactHeader: const SizedBox(
                      key: ValueKey('test-asset-hierarchy-sync-header'),
                      height: 52,
                      child: Center(child: Text('Sync status')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toolbar = find.byKey(
        const ValueKey('asset-hierarchy-mobile-toolbar'),
      );
      final hierarchyList = find.byKey(
        const ValueKey('asset-hierarchy-definition-list'),
      );
      expect(toolbar, findsOneWidget);
      expect(hierarchyList, findsOneWidget);
      expect(tester.getSize(toolbar).height, lessThanOrEqualTo(56));
      expect(tester.getSize(hierarchyList).height, greaterThanOrEqualTo(140));
      final retiredButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('asset-hierarchy-retired-toggle')),
      );
      final addButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('asset-hierarchy-add-class')),
      );
      expect(
        retiredButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
        Colors.white,
      );
      expect(
        addButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
        Colors.white,
      );

      final compactHeader = find.byKey(
        const ValueKey('test-asset-hierarchy-sync-header'),
      );
      expect(compactHeader.hitTestable(), findsOneWidget);
      await tester.drag(hierarchyList, const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(compactHeader.hitTestable(), findsNothing);
      expect(toolbar.hitTestable(), findsNothing);
      expect(find.text('Definition').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact hierarchy search survives a selected-class switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 28, 14, 15);
    final furnace = _assetClass(now);
    final base = _baseAssetClass(now);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetClassesProvider.overrideWith(
            (ref) => Stream.value(<AssetClassRecord>[furnace, base]),
          ),
          assetHierarchyNodesProvider(
            furnace.id,
          ).overrideWith((ref) => Stream.value(const <AssetHierarchyNode>[])),
          assetHierarchyNodesProvider(
            base.id,
          ).overrideWith((ref) => Stream.value(const <AssetHierarchyNode>[])),
          assetInstancesProvider(
            furnace.id,
          ).overrideWith((ref) => Stream.value(const <AssetInstanceRecord>[])),
          assetInstancesProvider(
            base.id,
          ).overrideWith((ref) => Stream.value(const <AssetInstanceRecord>[])),
        ],
        child: MaterialApp(
          home: Scaffold(body: AssetHierarchyAdminTab(actor: _admin(now))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, '');
    expect(search, findsOneWidget);
    await tester.enterText(search, 'base');
    await tester.pumpAndSettle();

    final reboundSearch = find.byType(TextField);
    expect(reboundSearch, findsOneWidget);
    expect(tester.widget<TextField>(reboundSearch).controller?.text, 'base');
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('asset-hierarchy-class-selector')),
          )
          .initialValue,
      base.id,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact hierarchy retains sync controls while loading', (
    tester,
  ) async {
    final classes = StreamController<List<AssetClassRecord>>();
    addTearDown(classes.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetClassesProvider.overrideWith((ref) => classes.stream)],
        child: MaterialApp(
          home: Scaffold(
            body: AssetHierarchyAdminTab(
              actor: _admin(DateTime.utc(2026, 8, 28, 14, 20)),
              compactHeader: const SizedBox(
                key: ValueKey('loading-asset-hierarchy-sync-header'),
                height: 52,
                child: Center(child: Text('Sync status')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find
          .byKey(const ValueKey('loading-asset-hierarchy-sync-header'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Loading asset hierarchy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact hierarchy retains sync controls on load failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetClassesProvider.overrideWith(
            (ref) => Stream<List<AssetClassRecord>>.error(
              StateError('controlled read failure'),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AssetHierarchyAdminTab(
              actor: _admin(DateTime.utc(2026, 8, 28, 14, 25)),
              compactHeader: const SizedBox(
                key: ValueKey('error-asset-hierarchy-sync-header'),
                height: 52,
                child: Center(child: Text('Sync status')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find
          .byKey(const ValueKey('error-asset-hierarchy-sync-header'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.textContaining('controlled read failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin ticket descriptions stay bounded and readable on phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 28, 14, 30);
    final ticket = _longTicket(now);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminTicketsStreamProvider.overrideWith(
            (ref) => Stream.value(<MaintenanceRecord>[ticket]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TicketsBrowser())),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('admin-ticket-ticket-long-copy'));
    final preview = find.byKey(
      const ValueKey('admin-ticket-description-preview'),
    );
    expect(ticket.description.length, lessThanOrEqualTo(120));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, lessThanOrEqualTo(220));
    expect(preview, findsOneWidget);
    final previewText = tester.widget<Text>(preview);
    expect(previewText.maxLines, 2);
    expect(previewText.overflow, TextOverflow.ellipsis);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.edit))
          .onPressed,
      isNull,
    );
    expect(
      find.byTooltip('Repair saved evidence before correction'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin-ticket-description-view')),
    );
    await tester.pumpAndSettle();

    final fullDescription = find.byKey(
      const ValueKey('admin-ticket-full-description'),
    );
    expect(fullDescription, findsOneWidget);
    expect(
      tester.widget<SelectableText>(fullDescription).data,
      ticket.description,
    );
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AssetClassRecord _assetClass(DateTime now) => AssetClassRecord(
  id: 'furnace-class',
  code: 'FURNACE',
  name: 'Furnace',
  majorArea: 'BAF shop',
  legacyAssetTypeKey: 'furnace',
  shortDescription:
      'Furnace hierarchy with enough detail to exercise the compact layout.',
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: now,
  createdByUid: 'admin-1',
  updatedAt: now,
  updatedByUid: 'admin-1',
  lastMutationId: 'class-mutation',
);

AssetClassRecord _baseAssetClass(DateTime now) => AssetClassRecord(
  id: 'base-class',
  code: 'BASE',
  name: 'Base',
  majorArea: 'BAF shop',
  legacyAssetTypeKey: 'base',
  shortDescription: 'Base hierarchy used to verify compact search continuity.',
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: now,
  createdByUid: 'admin-1',
  updatedAt: now,
  updatedByUid: 'admin-1',
  lastMutationId: 'base-class-mutation',
);

AssetHierarchyNode _hierarchyNode(
  int index,
  String assetClassId,
  DateTime now,
) => AssetHierarchyNode(
  id: 'component-$index',
  assetClassId: assetClassId,
  nodeType: AssetHierarchyNodeType.component,
  name: 'Component $index',
  shortDescription:
      'Component description retained in the scrollable hierarchy tree.',
  contactArrangement: ElectricalContactArrangement.notApplicable,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: const <String>['seniorMechanical'],
  sortOrder: index,
  ancestorNodeIds: const <String>[],
  hierarchyPath: <String>['Component $index'],
  activeChildCount: 0,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: now,
  createdByUid: 'admin-1',
  updatedAt: now,
  updatedByUid: 'admin-1',
  lastMutationId: 'node-mutation-$index',
);

MaintenanceRecord _longTicket(DateTime now) =>
    MaintenanceRecord()
      ..firestoreId = 'ticket-long-copy'
      ..version = 1
      ..assetType = AssetType.furnace
      ..assetNumber = 12
      ..maintenanceType = MaintenanceType.breakdown
      ..description =
          'UV detector replacement completed after inspection; verify the flame '
          'signal and restore the burner before release.'
      ..routedTo = RoutedTo.mechanical
      ..status = TicketStatus.open
      ..loggedByUid = 'operator-1'
      ..loggedByName = 'Operations User With A Deliberately Long Display Name'
      ..startDate = now
      ..createdAt = now
      ..updatedAt = now
      ..actionsJson = '{not-json'
      ..isSynced = true;

AppUser _admin(DateTime now) => AppUser(
  uid: 'admin-1',
  name: 'Admin One',
  email: 'admin@example.com',
  roles: const <AppRole>[AppRole.admin],
  isApproved: true,
  createdAt: now,
);
