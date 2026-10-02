import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as f;

final _coverClass = f.assetClass(
  id: 'covers',
  code: 'INNER_COVER',
  name: 'Inner Covers',
  legacyKey: 'innerCover',
);

InnerCoverProfile _coverProfile(
  String id,
  InnerCoverLifecycleState lifecycle, {
  AssetClassRecord? assetClass,
}) => InnerCoverProfile(
  id: id,
  assetClassId: (assetClass ?? _coverClass).id,
  assetClassCode: (assetClass ?? _coverClass).code,
  assetClassName: (assetClass ?? _coverClass).name,
  serialNumber: id,
  normalizedSerialNumber: id,
  sourceType: InnerCoverSourceType.legacyExisting,
  lifecycleState: lifecycle,
  traceabilityGrade: InnerCoverTraceabilityGrade.t0,
  version: 1,
  createdAt: DateTime.utc(2026, 10, 2),
  updatedAt: DateTime.utc(2026, 10, 2),
  lastMutationId: 'fixture-$id',
);

PlantAssetOverview _mixedStock({required bool evidenceConfirmed}) {
  final spare = _coverProfile('SPARE-1', InnerCoverLifecycleState.available);
  final installed = _coverProfile(
    'INSTALLED-1',
    InnerCoverLifecycleState.installed,
  );
  final stock = InnerCoverStockSummary(
    inventoryConfirmed: true,
    linkageConfirmed: true,
    bulgeEvidenceConfirmed: evidenceConfirmed,
    dependencyEvidenceConfirmed: evidenceConfirmed,
    rows: [
      InnerCoverStockRow(
        profile: spare,
        disposition: InnerCoverStockDisposition.excluded,
        reviewReasons: const ['Active issue: unavailable'],
        evidenceUnverified: !evidenceConfirmed,
        activeConfirmedBulging: false,
        pendingBulgeAssessment: false,
        bulgeHistory: false,
        inconclusiveBulgeAssessment: false,
        activeIssueRestriction: true,
      ),
      InnerCoverStockRow(
        profile: installed,
        disposition: InnerCoverStockDisposition.installed,
        reviewReasons: const [
          'Confirmed bulging',
          'Active maintenance',
          'Current assessment needed',
        ],
        evidenceUnverified: !evidenceConfirmed,
        activeConfirmedBulging: true,
        pendingBulgeAssessment: false,
        bulgeHistory: false,
        inconclusiveBulgeAssessment: false,
        activeMaintenanceRestriction: true,
        needsCurrentAssessment: true,
      ),
    ],
  );
  final covers = [
    for (final row in stock.rows)
      PlantInnerCoverState(profile: row.profile, stockCondition: row),
  ];
  return PlantAssetOverview(
    classes: [
      PlantAssetClassSummary(
        assetClass: _coverClass,
        assets: const [],
        innerCovers: covers,
      ),
    ],
    assets: const [],
    innerCovers: covers,
    innerCoverStock: stock,
  );
}

Future<void> _pump(
  WidgetTester tester,
  PlantAssetOverview overview, {
  required VoidCallback onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlantOverviewPanel(
            overview: AsyncData(overview),
            onOpen: onOpen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final evidenceConfirmed in [true, false]) {
    testWidgets(
      'collapsed mixed IC concerns count unique covers with evidenceConfirmed=$evidenceConfirmed',
      (tester) async {
        final overview = _mixedStock(evidenceConfirmed: evidenceConfirmed);
        await _pump(tester, overview, onOpen: () {});
        final toggle = find.byKey(
          const ValueKey('plant-inner-cover-toggle-covers'),
        );
        final labels = tester
            .widgetList<Text>(
              find.descendant(of: toggle, matching: find.byType(Text)),
            )
            .map((text) => text.data ?? '')
            .join(' ');

        // The installed cover has three concerns, but is one review identity.
        // The excluded spare remains a different review identity.
        expect(overview.innerCoverStock!.review, hasLength(2));
        expect(labels, contains('2 to review'));
        expect(labels, isNot(contains('4 to review')));
        if (evidenceConfirmed) {
          expect(labels, contains('1 excluded'));
          expect(labels, isNot(contains('Evidence unverified')));
        } else {
          expect(labels, contains('Evidence unverified'));
          expect(labels, isNot(contains('1 excluded')));
        }
        expect(
          find.byKey(const ValueKey('plant-inner-cover-details-covers')),
          findsNothing,
        );
        expect(find.textContaining('SPARE-1'), findsNothing);
        expect(find.textContaining('INSTALLED-1'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'standalone IC maintenance remains a Pulse restriction and opens cover review',
    (tester) async {
      final cover = PlantInnerCoverState(
        profile: _coverProfile(
          'REPAIR-1',
          InnerCoverLifecycleState.underRepair,
        ),
      );
      final overview = PlantAssetOverview(
        classes: [
          PlantAssetClassSummary(
            assetClass: _coverClass,
            assets: const [],
            innerCovers: [cover],
          ),
        ],
        assets: const [],
        innerCovers: [cover],
      );
      var plantOpened = 0;
      void otherRoute() => fail('Cover restriction opened an unrelated route');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeManagementPulsePanel(
                plantOverview: AsyncData(overview),
                dataUnavailable: false,
                onOpenReports: otherRoute,
                onPlantCondition: () => plantOpened++,
                onIssues: otherRoute,
                onWork: otherRoute,
                onControl: otherRoute,
                onQualityMonitoring: otherRoute,
                onRetry: otherRoute,
                onMaintenanceRhythm: otherRoute,
                onInspectionProgrammes: otherRoute,
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
      expect(overview.hasCompleteEvidence, isTrue);
      expect(cover.isUnderMaintenance, isTrue);
      expect(cover.isUnfit, isFalse);
      final restriction = find.textContaining(
        'outside the available state. Review cover condition.',
      );
      expect(restriction, findsOneWidget);
      expect(find.text('No exception in these summary queues.'), findsNothing);
      await tester.ensureVisible(restriction);
      await tester.tap(restriction);
      expect(plantOpened, 1);
      expect(
        cover.profile.lifecycleState,
        InnerCoverLifecycleState.underRepair,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanding an incomplete empty class does not assert an empty register',
    (tester) async {
      final cls = f.assetClass(
        id: 'bases',
        code: 'BASE',
        name: 'Base',
        legacyKey: 'base',
      );
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
      var opened = 0;
      await _pump(tester, overview, onOpen: () => opened++);

      expect(find.text('0 recorded'), findsOneWidget);
      expect(find.text('0 registered'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plant-class-row-bases')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Inventory incomplete. These records cannot establish the full class position.',
        ),
        findsOneWidget,
      );
      expect(find.text('No registered equipment in this class.'), findsNothing);
      expect(
        find.text('No recorded restrictions in this class.'),
        findsNothing,
      );
      expect(opened, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a missing class does not hide a known physical Down restriction',
    (tester) async {
      final cls = f.assetClass(
        id: 'furnaces',
        code: 'FURNACE',
        name: 'Furnace',
        legacyKey: 'furnace',
      );
      final asset = f.asset(id: 'orphan-furnace', assetClass: cls, number: 8);
      final overview = qualifiedPlantAssetOverview(
        classes: [],
        assets: [asset],
        conditions: [
          f.condition(asset: asset, condition: AssetOperationalCondition.down),
        ],
        workflow: [],
        availability: [],
        tickets: [],
        populationWarnings: [],
        manualSourcesCurrent: true,
      );
      var opened = 0;
      await _pump(tester, overview, onOpen: () => opened++);

      final warning = find.byKey(
        const ValueKey('plant-home-unclassified-orphan-furnace'),
      );
      expect(warning, findsOneWidget);
      final text = tester
          .widget<Text>(
            find.descendant(of: warning, matching: find.byType(Text)).first,
          )
          .data!;
      expect(text, contains('Furnace 8'));
      expect(text, contains('class unverified'));
      expect(text, contains('Down'));
      expect(overview.down, 1);
      expect(overview.available, 0);
      await tester.tap(warning);
      expect(opened, 1);
      expect(overview.down, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final lifecycle in [
    InnerCoverLifecycleState.underRepair,
    InnerCoverLifecycleState.installed,
  ]) {
    testWidgets(
      'class detail explains retained cover counts for $lifecycle in a non-cover class',
      (tester) async {
        final cls = f.assetClass(
          id: 'bases',
          code: 'BASE',
          name: 'Bases',
          legacyKey: 'base',
        );
        final overview = physicalPlantInventory(
          overview: const PlantAssetOverview(classes: [], assets: []),
          classes: [cls],
          profiles: [
            _coverProfile('MISCLASSIFIED-1', lifecycle, assetClass: cls),
          ],
        );
        final summary = overview.classes.single;
        final cover = summary.innerCovers.single;
        final restricted = lifecycle == InnerCoverLifecycleState.underRepair;
        expect(summary.total, 1);
        expect(summary.available, 0);
        expect(summary.unavailable, restricted ? 1 : 0);
        expect(summary.unverifiedAvailability, restricted ? 0 : 1);
        expect(
          cover.evidenceWarnings,
          contains('Inner Cover class is missing, retired or unverified.'),
        );
        var opened = 0;
        await _pump(tester, overview, onOpen: () => opened++);
        expect(find.text('Inner Covers: 1 class unverified'), findsOneWidget);
        expect(find.textContaining('MISCLASSIFIED-1:'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('plant-class-row-bases')));
        await tester.pumpAndSettle();
        final detail = find.byKey(const ValueKey('plant-class-details-bases'));
        final texts = tester
            .widgetList<Text>(
              find.descendant(of: detail, matching: find.byType(Text)),
            )
            .map((text) => text.data ?? '')
            .join(' ');
        expect(
          texts,
          contains('Inner Cover MISCLASSIFIED-1: ${cover.conditionSummary}'),
        );
        expect(texts, contains(lifecycle.label));
        expect(
          texts,
          contains('Inner Cover class is missing, retired or unverified.'),
        );
        expect(
          texts,
          isNot(contains('No recorded restrictions in this class.')),
        );
        expect(
          texts,
          isNot(contains('No registered equipment in this class.')),
        );
        // A retained serial belongs in its counted class detail, while the
        // separate class-unverified review link must remain available.
        expect(find.text('Inner Covers: 1 class unverified'), findsOneWidget);
        final open = find.byKey(const ValueKey('plant-class-open-bases'));
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        await tester.tap(open);
        expect(opened, 1);
        expect(summary.total, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'orphan serial covers retain a separate review link without double counting known classes',
    (tester) async {
      final cls = f.assetClass(
        id: 'covers',
        code: 'INNER_COVER',
        name: 'Inner Covers',
        legacyKey: 'innerCover',
      );
      InnerCoverProfile profile(String id, String classId) => InnerCoverProfile(
        id: id,
        assetClassId: classId,
        assetClassCode: cls.code,
        assetClassName: cls.name,
        serialNumber: id,
        normalizedSerialNumber: id,
        sourceType: InnerCoverSourceType.legacyExisting,
        lifecycleState: InnerCoverLifecycleState.installed,
        traceabilityGrade: InnerCoverTraceabilityGrade.t0,
        version: 1,
        createdAt: DateTime.utc(2026, 10, 2),
        updatedAt: DateTime.utc(2026, 10, 2),
        lastMutationId: 'fixture-$id',
      );
      final overview = physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [cls],
        profiles: [profile('IC-1', cls.id), profile('IC-2', 'missing-class')],
      );
      var opened = 0;
      await _pump(tester, overview, onOpen: () => opened++);

      final warning = find.byKey(
        const ValueKey('plant-home-unclassified-covers'),
      );
      expect(warning, findsOneWidget);
      expect(find.text('Inner Covers: 1 class unverified'), findsOneWidget);
      expect(find.text('Inner Covers: 2 class unverified'), findsNothing);
      expect(
        find.byKey(const ValueKey('plant-inner-cover-toggle-covers')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plant-inner-cover-details-covers')),
        findsNothing,
      );
      expect(overview.innerCovers, hasLength(2));
      await tester.tap(warning);
      expect(opened, 1);
      expect(overview.innerCovers, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
