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
