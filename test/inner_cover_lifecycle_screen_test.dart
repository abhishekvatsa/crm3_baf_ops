import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/furnace_stuckup_provider.dart';
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

  test('retired covers return only through fresh inspection', () {
    final states = allowedInnerCoverStateChanges(
      InnerCoverLifecycleState.retiredForSalvage,
    );

    expect(states.first, InnerCoverLifecycleState.awaitingInspection);
    expect(states, isNot(contains(InnerCoverLifecycleState.available)));
    expect(
      allowedInnerCoverStateChanges(
        InnerCoverLifecycleState.partiallyDismantled,
      ),
      isNot(contains(InnerCoverLifecycleState.awaitingInspection)),
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
      incorporatedOn: DateTime.utc(2022, 11, 18, 12),
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
      sourceType: InnerCoverSourceType.fabricated,
      originClassification:
          InnerCoverOriginClassification.documentedFabrication,
      receivedOrCompletedOn: DateTime.utc(2025, 12, 5, 12),
      incorporatedOn: DateTime.utc(2025, 12, 13, 12),
    );
    final longSerial = _profile(
      id: 'cover-long-serial',
      serial: 'GR${'9' * 150}',
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
            (ref) => Stream.value([installed, longSerial, available]),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream.value([assignment]),
          ),
          furnaceStuckupCasesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          assetConditionDeclarationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base 201'), findsOneWidget);
    expect(
      find.text('Inner Cover GR26\nIncorporated 18 Nov 2022'),
      findsOneWidget,
    );
    expect(find.text('1 installed'), findsOneWidget);
    expect(find.text('2 available'), findsOneWidget);
    expect(find.byTooltip('Register Inner Cover'), findsNothing);

    await tester.tap(find.text('Pool'));
    await tester.pumpAndSettle();
    expect(find.text('GR30'), findsOneWidget);
    expect(find.text(longSerial.serialNumber), findsOneWidget);
    expect(find.textContaining('Available'), findsWidgets);
    expect(find.textContaining('Incorporated 13 Dec 2025'), findsOneWidget);
    await tester.tap(find.text('GR30'));
    await tester.pumpAndSettle();
    expect(find.text('Fabrication completed on'), findsOneWidget);
    expect(find.text('05 Dec 2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'known cover and vacant Base can be found without scrolling long lists',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 9, 5);
      final assetClass = _baseClass(now);
      final bases = [_base(101, now), _base(102, now), _base(223, now)];
      final installed = _profile(
        id: 'cover-gr4',
        serial: 'GR4',
        state: InnerCoverLifecycleState.installed,
        now: now,
        baseId: bases.first.id,
        baseNumber: 101,
        baseName: 'Base 101',
        linkageId: 'link-gr4',
      );
      final available = _profile(
        id: 'cover-n16',
        serial: 'N16',
        state: InnerCoverLifecycleState.available,
        now: now,
      );
      final attention = _profile(
        id: 'cover-gr22',
        serial: 'GR22',
        state: InnerCoverLifecycleState.awaitingInspection,
        now: now,
      );
      final staleInstalledProfile = _profile(
        id: 'cover-stale',
        serial: 'G97',
        state: InnerCoverLifecycleState.installed,
        now: now,
        baseId: 'retired-base-record',
        baseNumber: 999,
        baseName: 'Retired Base record',
        linkageId: 'stale-link',
      );
      final assignment = BaseInnerCoverAssignment(
        baseAssetInstanceId: bases.first.id,
        baseAssetClassId: assetClass.id,
        baseAssetNumber: 101,
        baseAssetName: 'Base 101',
        innerCoverId: installed.id,
        innerCoverSerialNumber: installed.serialNumber,
        linkageId: 'link-gr4',
        linkedAt: now,
        version: 1,
        updatedAt: now,
        lastMutationId: 'link-mutation',
      );
      final declaration = AssetConditionDeclarationRecord(
        id: 'inner_cover_bulged_${available.id}',
        assetId: available.id,
        assetSerialNumber: available.serialNumber,
        evidenceCount: 2,
        firstConfirmedAt: now.subtract(const Duration(days: 4)),
        latestEvidenceAt: now.subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
            ),
            assetClassesProvider.overrideWith(
              (ref) => Stream.value([assetClass]),
            ),
            allAssetInstancesProvider.overrideWith(
              (ref) => Stream.value(bases),
            ),
            innerCoverProfilesProvider.overrideWith(
              (ref) => Stream.value([
                installed,
                available,
                attention,
                staleInstalledProfile,
              ]),
            ),
            innerCoverAssignmentsProvider.overrideWith(
              (ref) => Stream.value([assignment]),
            ),
            furnaceStuckupCasesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            assetConditionDeclarationsProvider.overrideWith(
              (ref) => Stream.value([declaration]),
            ),
            innerCoverHistoryProvider.overrideWith(
              (ref, innerCoverId) => Stream.value(const []),
            ),
            baseInnerCoverHistoryProvider.overrideWith(
              (ref, baseId) => Stream.value(const []),
            ),
            innerCoverFabricationProvider.overrideWith(
              (ref, innerCoverId) => Stream.value(null),
            ),
          ],
          child: const MaterialApp(home: InnerCoverLifecycleScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 Bases'), findsOneWidget);
      expect(find.text('1 installed'), findsOneWidget);
      expect(find.text('1 available'), findsOneWidget);
      expect(find.text('1 need attention'), findsOneWidget);
      expect(find.text('2 Bases with no Inner Covers'), findsOneWidget);
      expect(find.text('Vacant 2'), findsOneWidget);

      await tester.tap(find.text('2 Bases with no Inner Covers'));
      await tester.pumpAndSettle();
      expect(find.text('Base 101'), findsNothing);
      expect(find.text('Base 102'), findsOneWidget);
      expect(find.text('Base 223'), findsOneWidget);

      await tester.tap(find.text('1 installed'));
      await tester.pumpAndSettle();
      expect(find.text('Base 101'), findsOneWidget);
      expect(find.text('Base 102'), findsNothing);

      await tester.tap(find.text('3 Bases'));
      await tester.pumpAndSettle();
      expect(find.text('Base 101'), findsOneWidget);
      expect(find.text('Base 102'), findsOneWidget);
      expect(find.text('Base 223'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Search Base number or Inner Cover serial',
        ),
        '223',
      );
      await tester.pumpAndSettle();
      expect(find.text('Base 102'), findsNothing);
      expect(find.text('Base 223'), findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: find.text('Base 223'),
          matching: find.byType(ListTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inner Cover assignment history'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('Inner Cover assignment history')),
      ).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 available'));
      await tester.pumpAndSettle();
      expect(find.text('N16'), findsOneWidget);
      expect(find.text('GR22'), findsNothing);
      expect(find.textContaining('Confirmed bulge record'), findsOneWidget);

      await tester.tap(find.text('1 need attention'));
      await tester.pumpAndSettle();
      expect(find.text('N16'), findsNothing);
      expect(find.text('GR22'), findsOneWidget);

      await tester.tap(find.text('1 available'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Search serial, Base or lifecycle state',
        ),
        'N16',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(of: find.text('N16'), matching: find.byType(ListTile)),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Assign to Base'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Assign to Base'));
      await tester.pumpAndSettle();
      expect(find.text('Vacant 2'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Find Base number'),
        '223',
      );
      await tester.pumpAndSettle();
      expect(find.text('Base 223'), findsOneWidget);
      expect(find.text('Base 101'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy retired cover collects condition before reinspection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 9, 5);
    final retired = _profile(
      id: 'cover-old',
      serial: 'G60',
      state: InnerCoverLifecycleState.retiredForSalvage,
      now: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([_baseClass(now)]),
          ),
          allAssetInstancesProvider.overrideWith((ref) => Stream.value([])),
          innerCoverProfilesProvider.overrideWith(
            (ref) => Stream.value([retired]),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream.value(const <BaseInnerCoverAssignment>[]),
          ),
          furnaceStuckupCasesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          assetConditionDeclarationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          innerCoverHistoryProvider.overrideWith(
            (ref, innerCoverId) => Stream.value(const []),
          ),
          innerCoverFabricationProvider.overrideWith(
            (ref, innerCoverId) => Stream.value(null),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('0 available'));
    await tester.pumpAndSettle();
    expect(find.text('G60'), findsNothing);
    final availableChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Available 0'),
    );
    expect(availableChip.selected, isTrue);

    await tester.tap(find.text('All 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('G60'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Return for inspection'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return retired cover to inspection'), findsOneWidget);
    expect(find.text('Condition recorded at retirement'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin can delink an installed cover directly from its Base', (
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
            (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([assetClass]),
          ),
          allAssetInstancesProvider.overrideWith((ref) => Stream.value([base])),
          innerCoverProfilesProvider.overrideWith(
            (ref) => Stream.value([installed]),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream.value([assignment]),
          ),
          furnaceStuckupCasesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          assetConditionDeclarationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delink Inner Cover from Base'), findsOneWidget);
    await tester.tap(find.byTooltip('Delink Inner Cover from Base'));
    await tester.pumpAndSettle();

    expect(find.text('Remove from Base'), findsOneWidget);
    expect(find.text('Awaiting inspection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin registration explains invalid required fields', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
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
          furnaceStuckupCasesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          assetConditionDeclarationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Register Inner Cover'));
    await tester.pumpAndSettle();
    expect(find.text('Register Inner Cover'), findsOneWidget);
    expect(find.text('Identity and route'), findsOneWidget);
    expect(find.text('Plant timeline'), findsOneWidget);
    expect(find.text('Purchase record'), findsOneWidget);
    expect(find.text('Registration record'), findsOneWidget);
    expect(find.text('Received on'), findsOneWidget);
    expect(find.text('Date incorporated'), findsOneWidget);
    expect(find.text('Not recorded'), findsNWidgets(2));

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    final registerButton = find.widgetWithText(FilledButton, 'Register');
    final logicalViewHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final logicalKeyboardInset =
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(registerButton).dy,
      lessThanOrEqualTo(logicalViewHeight - logicalKeyboardInset),
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchased · documented'));
    await tester.pumpAndSettle();
    expect(find.text('New · owner-declared'), findsOneWidget);
    await tester.tap(find.text('New · owner-declared'));
    await tester.pumpAndSettle();
    expect(find.text('Owner-declared provenance'), findsOneWidget);
    expect(find.text('Known receipt or completion date'), findsOneWidget);
    expect(find.text('Fabrication sections'), findsNothing);

    await tester.tap(find.text('New · owner-declared'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fabricated · documented').last);
    await tester.pumpAndSettle();
    expect(find.text('Fabrication identity'), findsOneWidget);
    expect(find.text('Fabrication sections'), findsOneWidget);
    expect(find.text('Lower / water-jacket assembly'), findsOneWidget);

    await tester.tap(find.text('Fabricated · documented'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fabricated · owner-declared').last);
    await tester.pumpAndSettle();
    expect(find.text('Owner-declared fabrication'), findsOneWidget);
    expect(find.text('Fabrication sections'), findsOneWidget);

    await tester.tap(find.text('Fabricated · owner-declared'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing · origin undocumented').last);
    await tester.pumpAndSettle();
    expect(find.text('Known legacy provenance'), findsOneWidget);
    expect(find.text('Fabrication sections'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Enter an Inner Cover serial number.'), findsOneWidget);
    expect(find.text('Explain the registration.'), findsOneWidget);
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
          furnaceStuckupCasesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          assetConditionDeclarationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: InnerCoverLifecycleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Register Inner Cover'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchased · documented'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fabricated · documented').last);
    await tester.pumpAndSettle();
    expect(find.text('Fabrication completed on'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Inner Cover serial number'),
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
  InnerCoverSourceType sourceType = InnerCoverSourceType.purchased,
  InnerCoverOriginClassification originClassification =
      InnerCoverOriginClassification.documentedPurchase,
  DateTime? receivedOrCompletedOn,
  DateTime? incorporatedOn,
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
  sourceType: sourceType,
  originClassification: originClassification,
  lifecycleState: state,
  traceabilityGrade: InnerCoverTraceabilityGrade.t3,
  receivedOrCompletedOn: receivedOrCompletedOn,
  incorporatedOn: incorporatedOn,
  currentBaseAssetInstanceId: baseId,
  currentBaseAssetNumber: baseNumber,
  currentBaseAssetName: baseName,
  currentLinkageId: linkageId,
  version: 2,
  createdAt: now,
  updatedAt: now,
  lastMutationId: 'profile-mutation',
);

AssetClassRecord _baseClass(DateTime now) => AssetClassRecord(
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

AssetInstanceRecord _base(int number, DateTime now) => AssetInstanceRecord(
  id: 'base-$number',
  assetClassId: 'base-class',
  assetClassCode: 'BASE',
  assetClassName: 'Base',
  assetNumber: number,
  name: 'Base $number',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: 1,
  createdAt: now,
  updatedAt: now,
  lastMutationId: 'asset-$number',
);

AppUser _actor(AppRole role) => AppUser(
  uid: 'actor-1',
  name: 'Actor One',
  email: 'actor@example.com',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
