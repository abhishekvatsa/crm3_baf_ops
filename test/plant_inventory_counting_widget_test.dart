import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'plant_asset_overview_test.dart' as f;

void main() {
  testWidgets(
    'Home and board show serial inventory and unknown identities without a fake empty class',
    (tester) async {
      final cls = f.assetClass(
        id: 'covers',
        code: 'COVER',
        name: 'Inner Covers',
        legacyKey: 'innerCover',
      );
      final orphan = f.asset(
        id: 'orphan',
        assetClass: f.assetClass(
          id: 'missing-class',
          code: 'BASE',
          name: 'Base',
        ),
        number: 99,
      );
      final now = DateTime.utc(2026);
      final profile = InnerCoverProfile(
        id: 'IC-1',
        assetClassId: cls.id,
        assetClassCode: cls.code,
        assetClassName: cls.name,
        serialNumber: 'IC-1',
        normalizedSerialNumber: 'IC1',
        sourceType: InnerCoverSourceType.legacyExisting,
        lifecycleState: InnerCoverLifecycleState.installed,
        traceabilityGrade: InnerCoverTraceabilityGrade.t0,
        version: 1,
        createdAt: now,
        updatedAt: now,
        lastMutationId: 'cover',
      );
      final overview = physicalPlantInventory(
        overview: PlantAssetOverview(
          classes: [],
          assets: [
            PlantAssetState(
              asset: orphan,
              operationalCondition: null,
              availability: null,
              workflowStatus: null,
              evidenceWarnings: ['Class unavailable'],
              permitsManualChange: false,
            ),
            PlantAssetState(
              asset: f.asset(id: 'old-position', assetClass: cls, number: 1),
              operationalCondition: null,
              availability: null,
              workflowStatus: null,
            ),
          ],
          evidenceWarnings: ['Class unavailable'],
        ),
        classes: [cls],
        profiles: [profile],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlantOverviewPanel(
                overview: AsyncData(overview),
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsNothing);
      expect(find.text('2 recorded'), findsOneWidget);
      expect(
        find.text('1 verified available · 1 condition unverified'),
        findsOneWidget,
      );
      expect(
        find.text('Plant condition — evidence incomplete'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Inner Cover IC-1: Installed'),
        findsOneWidget,
      );
      expect(
        find.text('All registered assets are in the available state.'),
        findsOneWidget,
      ); // Cover class only, with known evidence.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(
                AppUser(
                  uid: 'ops',
                  name: 'Ops',
                  email: 'ops@example.invalid',
                  roles: [AppRole.operations],
                  isApproved: true,
                  createdAt: now,
                ),
              ),
            ),
            plantAssetOverviewProvider.overrideWith(
              (ref) => AsyncData(overview),
            ),
            plantConditionTicketsProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: const MaterialApp(home: AssetConditionBoard()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 recorded assets'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plant-unclassified-orphan')),
        250,
      );
      expect(find.text('Base 99'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plant-inner-cover-IC-1')),
        200,
      );
      expect(find.text('Inner Cover IC-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
