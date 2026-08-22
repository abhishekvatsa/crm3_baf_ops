import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspection states require acceptance before availability', () {
    expect(
      allowedInnerCoverStateChanges(
        InnerCoverLifecycleState.awaitingInspection,
      ),
      isNot(contains(InnerCoverLifecycleState.available)),
    );
    expect(
      allowedInnerCoverStateChanges(InnerCoverLifecycleState.underInspection),
      isNot(contains(InnerCoverLifecycleState.available)),
    );
  });

  testWidgets('Base-first board shows installed serial and separate pool', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 15);
    final assetClass = AssetClassRecord(
      id: 'base-class',
      code: 'BASE',
      name: 'Base',
      majorArea: 'BAF shop',
      legacyAssetTypeKey: 'base',
      status: AssetHierarchyStatus.active,
      version: 1,
      createdAt: now,
      createdByUid: 'admin-1',
      updatedAt: now,
      updatedByUid: 'admin-1',
      lastMutationId: 'class-mutation',
    );
    final base = AssetInstanceRecord(
      id: 'base-201',
      assetClassId: 'base-class',
      assetClassCode: 'BASE',
      assetClassName: 'Base',
      assetNumber: 201,
      name: 'Base 201',
      serviceState: AssetServiceState.inService,
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'Operations',
      accountableRoleKeys: const ['operations'],
      status: AssetHierarchyStatus.active,
      activeComponentCount: 0,
      version: 1,
      createdAt: now,
      updatedAt: now,
      lastMutationId: 'asset-mutation',
    );
    final installed = _profile(
      id: 'cover-26',
      serial: 'GR26',
      state: InnerCoverLifecycleState.installed,
      now: now,
      baseId: base.id,
      baseNumber: 201,
      baseName: 'Base 201',
      linkageId: 'link-26',
    );
    final available = _profile(
      id: 'cover-30',
      serial: 'GR30',
      state: InnerCoverLifecycleState.available,
      now: now,
    );
    final assignment = BaseInnerCoverAssignment(
      baseAssetInstanceId: base.id,
      baseAssetClassId: assetClass.id,
      baseAssetNumber: 201,
      baseAssetName: 'Base 201',
      innerCoverId: installed.id,
      innerCoverSerialNumber: installed.serialNumber,
      linkageId: 'link-26',
      linkedAt: now,
      version: 1,
      updatedAt: now,
      lastMutationId: 'link-mutation',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([assetClass]),
          ),
          allAssetInstancesProvider.overrideWith((ref) => Stream.value([base])),
          innerCoverProfilesProvider.overrideWith(
            (ref) => Stream.value([installed, available]),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream.value([assignment]),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base 201'), findsOneWidget);
    expect(find.text('Inner Cover GR26'), findsOneWidget);
    expect(find.text('1 installed'), findsOneWidget);
    expect(find.text('1 available'), findsOneWidget);
    expect(find.byTooltip('Register Inner Cover'), findsNothing);

    await tester.tap(find.text('Pool'));
    await tester.pumpAndSettle();
    expect(find.text('GR30'), findsOneWidget);
    expect(find.textContaining('Available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin registration explains invalid required fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 22);
    final innerCoverClass = AssetClassRecord(
      id: 'inner-class',
      code: 'INNER_COVER',
      name: 'Inner Cover',
      majorArea: 'BAF shop',
      legacyAssetTypeKey: 'innerCover',
      status: AssetHierarchyStatus.active,
      version: 1,
      createdAt: now,
      createdByUid: 'admin-1',
      updatedAt: now,
      updatedByUid: 'admin-1',
      lastMutationId: 'inner-class-mutation',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([innerCoverClass]),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value(const <AssetInstanceRecord>[]),
          ),
          innerCoverProfilesProvider.overrideWith(
            (ref) => Stream.value(const <InnerCoverProfile>[]),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream.value(const <BaseInnerCoverAssignment>[]),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Register Inner Cover'));
    await tester.pumpAndSettle();
    expect(find.text('Register Inner Cover'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Enter an Inner Cover serial number.'), findsOneWidget);
    expect(
      find.text('Explain the registration in at least 8 characters.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('correcting fabrication text clears stale section error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 22);
    final innerCoverClass = AssetClassRecord(
      id: 'inner-class',
      code: 'INNER_COVER',
      name: 'Inner Cover',
      majorArea: 'BAF shop',
      legacyAssetTypeKey: 'innerCover',
      status: AssetHierarchyStatus.active,
      version: 1,
      createdAt: now,
      createdByUid: 'admin-1',
      updatedAt: now,
      updatedByUid: 'admin-1',
      lastMutationId: 'inner-class-mutation',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([innerCoverClass]),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value(const <AssetInstanceRecord>[]),
          ),
          innerCoverProfilesProvider.overrideWith(
            (ref) => Stream.value(const <InnerCoverProfile>[]),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream.value(const <BaseInnerCoverAssignment>[]),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Register Inner Cover'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchased'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fabricated').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Serial number'),
      'GR44',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Registration reason'),
      'Pilot registration',
    );
    final firstCuts = find.widgetWithText(TextField, 'Cuts used').first;
    await tester.enterText(firstCuts, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(
      find.textContaining('cut count must be between 1 and 100'),
      findsOneWidget,
    );
    await tester.enterText(firstCuts, '1');
    await tester.pump();
    expect(
      find.textContaining('cut count must be between 1 and 100'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

InnerCoverProfile _profile({
  required String id,
  required String serial,
  required InnerCoverLifecycleState state,
  required DateTime now,
  String? baseId,
  int? baseNumber,
  String? baseName,
  String? linkageId,
}) => InnerCoverProfile(
  id: id,
  assetClassId: 'inner-class',
  assetClassCode: 'INNER_COVER',
  assetClassName: 'Inner Cover',
  serialNumber: serial,
  normalizedSerialNumber: serial,
  sourceType: InnerCoverSourceType.purchased,
  lifecycleState: state,
  traceabilityGrade: InnerCoverTraceabilityGrade.t3,
  currentBaseAssetInstanceId: baseId,
  currentBaseAssetNumber: baseNumber,
  currentBaseAssetName: baseName,
  currentLinkageId: linkageId,
  version: 2,
  createdAt: now,
  updatedAt: now,
  lastMutationId: 'profile-mutation',
);

AppUser _actor(AppRole role) => AppUser(
  uid: 'actor-1',
  name: 'Actor One',
  email: 'actor@example.com',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
