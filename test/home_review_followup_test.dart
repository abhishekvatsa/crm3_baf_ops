import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'plant_asset_overview_test.dart' as f;

void main() {
  final cls = f.assetClass(
    id: 'bases',
    code: 'BASE',
    name: 'Bases',
    legacyKey: 'base',
  );
  for (final withNumberedDown in [false, true]) {
    testWidgets(
      'Pulse includes retained unfit cover with numbered Down=$withNumberedDown',
      (tester) async {
        final now = DateTime.utc(2026, 10, 3);
        final cover = PlantInnerCoverState(
          profile: InnerCoverProfile(
            id: 'retained-cover',
            assetClassId: cls.id,
            assetClassCode: cls.code,
            assetClassName: cls.name,
            serialNumber: 'IC-RETAINED',
            normalizedSerialNumber: 'ICRETAINED',
            sourceType: InnerCoverSourceType.legacyExisting,
            lifecycleState: InnerCoverLifecycleState.rejected,
            traceabilityGrade: InnerCoverTraceabilityGrade.t0,
            version: 1,
            createdAt: now,
            updatedAt: now,
            lastMutationId: 'fixture',
          ),
        );
        final asset = f.asset(id: 'base-101', assetClass: cls, number: 101);
        final numbered = withNumberedDown
            ? [
                PlantAssetState(
                  asset: asset,
                  operationalCondition: f.condition(
                    asset: asset,
                    condition: AssetOperationalCondition.down,
                  ),
                  availability: null,
                  workflowStatus: f.workflow(
                    key: 'base',
                    number: 101,
                    assetClassId: cls.id,
                    assetInstanceId: asset.id,
                  ),
                ),
              ]
            : <PlantAssetState>[];
        final summary = PlantAssetClassSummary(
          assetClass: cls,
          assets: numbered,
          innerCovers: [cover],
        );
        final overview = PlantAssetOverview(
          classes: [summary],
          assets: numbered,
          innerCovers: [cover],
        );
        var opened = '';
        void noop() {}
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeManagementPulsePanel(
                  plantOverview: AsyncData(overview),
                  dataUnavailable: false,
                  onOpenReports: noop,
                  onPlantCondition: noop,
                  onOpenClass: (id) => opened = id,
                  onIssues: noop,
                  onWork: noop,
                  onControl: noop,
                  onQualityMonitoring: noop,
                  onRetry: noop,
                  onMaintenanceRhythm: noop,
                  onInspectionProgrammes: noop,
                  ticketCount: 0,
                  executionCount: 0,
                  directiveCount: 0,
                  workflowAttentionCount: 0,
                  openOperationalEventCount: 0,
                  openQualityWarningCount: 0,
                  activeQualityMonitoringCount: 0,
                  overdueMaintenanceCount: 0,
                  activeInspectionFindingCount: 0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final signal = find.text(
          'Bases: ${withNumberedDown ? 2 : 1} down or unfit. Review this class.',
        );
        expect(signal, findsOneWidget);
        expect(find.textContaining('Bases: 0 down or unfit'), findsNothing);
        await tester.ensureVisible(signal);
        await tester.tap(signal);
        expect(opened, 'bases');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final filter in [
    AssetConditionFilter.all,
    AssetConditionFilter.available,
    AssetConditionFilter.down,
  ]) {
    testWidgets('incomplete zero-count class remains selectable under $filter', (
      tester,
    ) async {
      final overview = PlantAssetOverview(
        classes: [
          PlantAssetClassSummary(
            assetClass: cls,
            assets: const [],
            inventoryComplete: false,
          ),
        ],
        assets: const [],
        physicalInventoryComplete: false,
      );
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
                  createdAt: DateTime.utc(2026),
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
          child: MaterialApp(
            home: AssetConditionBoard(
              initialAssetClassId: cls.id,
              initialFilter: filter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('plant-asset-class-bases'));
      await tester.scrollUntilVisible(choice, 200);
      expect(tester.widget<ChoiceChip>(choice).selected, isTrue);
      final incomplete = find.byKey(
        const ValueKey('plant-class-incomplete-bases'),
      );
      await tester.scrollUntilVisible(incomplete, 200);
      expect(
        find.text(
          'Inventory incomplete. The records shown cannot establish the full class position. Refresh before making decisions.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('No assets match the selected condition and asset class.'),
        findsNothing,
      );
      expect(
        find.text('No active physical assets are registered.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
