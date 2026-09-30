import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/domain/base_cover_reconciliation.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'plant_asset_overview_test.dart' as f;

final _baseClass = f.assetClass(
  id: 'bases',
  code: 'BASE',
  name: 'Base',
  legacyKey: 'base',
);
final _base = f.asset(id: 'base-103', assetClass: _baseClass, number: 103);
DecodedSnapshotBatch<T> _batch<T>(
  List<T> records, {
  bool cached = false,
  bool pending = false,
  bool rejected = false,
}) => DecodedSnapshotBatch(
  records: records,
  rejectedDocumentIds: rejected ? ['bad-row'] : [],
  isFromCache: cached,
  hasPendingWrites: pending,
);

BaseCoverReconciliation _summary({
  bool cached = false,
  bool pending = false,
  bool rejected = false,
  bool down = false,
  bool conditionVerified = true,
  bool active = true,
  bool orphanProfile = false,
}) {
  final register = buildBaseInnerCoverRegister(
    classes: _batch([_baseClass]),
    assets: _batch([_base]),
    assignments: _batch<BaseInnerCoverAssignment>(
      [],
      cached: cached,
      pending: pending,
      rejected: rejected,
    ),
    covers: _batch<InnerCoverProfile>(
      orphanProfile
          ? [
              InnerCoverProfile(
                id: 'cover-1',
                assetClassId: 'covers',
                assetClassCode: 'IC',
                assetClassName: 'Inner Cover',
                serialNumber: 'G66',
                normalizedSerialNumber: 'G66',
                sourceType: InnerCoverSourceType.legacyExisting,
                lifecycleState: InnerCoverLifecycleState.installed,
                traceabilityGrade: InnerCoverTraceabilityGrade.t0,
                currentBaseAssetInstanceId: _base.id,
                currentBaseAssetNumber: 103,
                currentLinkageId: 'link-1',
                version: 1,
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
                lastMutationId: 'fixture',
              ),
            ]
          : [],
    ),
    linkages: _batch<InnerCoverLinkage>([]),
  );
  return reconcileBaseCoverRegister(
    register: register,
    activeBaseIds: active ? {_base.id} : {},
    verifiedConditionBaseIds: conditionVerified ? {_base.id} : {},
    downBaseIds: down ? {_base.id} : {},
  );
}

PlantAssetOverview _overview(BaseCoverReconciliation summary) =>
    PlantAssetOverview(
      classes: [PlantAssetClassSummary(assetClass: _baseClass, assets: [])],
      assets: [
        PlantAssetState(
          asset: _base,
          operationalCondition: null,
          availability: null,
          workflowStatus: null,
        ),
      ],
      baseCoverReconciliation: summary,
    );

ProviderContainer _provider({
  String? unqualifiedSource,
  bool rejected = false,
  bool down = false,
  bool retiredClass = false,
  Stream<DecodedSnapshotBatch<BaseInnerCoverAssignment>>? assignments,
  Stream<DecodedSnapshotBatch<InnerCoverLinkage>>? links,
  Stream<PlantEvidenceBatch<InnerCoverProfile>>? covers,
}) {
  PlantEvidenceBatch<T> evidence<T>(String source, List<T> rows) =>
      PlantEvidenceBatch(
        rows: rows,
        rejected: source == unqualifiedSource && rejected
            ? {'bad-row': 'unreadable'}
            : {},
        fromServer: source != unqualifiedSource || rejected,
        observedAt: DateTime.utc(2026),
      );
  final cls = retiredClass
      ? AssetClassRecord(
          id: _baseClass.id,
          code: _baseClass.code,
          name: _baseClass.name,
          majorArea: _baseClass.majorArea,
          legacyAssetTypeKey: 'base',
          status: AssetHierarchyStatus.retired,
          version: 2,
          createdAt: _baseClass.createdAt,
          createdByUid: 'fixture',
          updatedAt: _baseClass.updatedAt,
          updatedByUid: 'fixture',
          lastMutationId: 'retired',
        )
      : _baseClass;
  final container = ProviderContainer(
    overrides: [
      plantClassEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence('classes', [cls])),
      ),
      plantAssetEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence('assets', [_base])),
      ),
      plantManualEvidenceProvider.overrideWith(
        (ref) => Stream.value(
          evidence(
            'conditions',
            down
                ? [
                    f.condition(
                      asset: _base,
                      condition: AssetOperationalCondition.down,
                    ),
                  ]
                : [],
          ),
        ),
      ),
      plantWorkflowEvidenceProvider.overrideWith(
        (ref) => Stream.value(
          evidence('workflow', [f.workflow(key: 'base', number: 103)]),
        ),
      ),
      plantAvailabilityEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence('availability', [])),
      ),
      plantTicketEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence('tickets', [])),
      ),
      plantInnerCoverEvidenceProvider.overrideWith(
        (ref) =>
            covers ?? Stream.value(evidence<InnerCoverProfile>('covers', [])),
      ),
      plantCoverAssignmentEvidenceProvider.overrideWith(
        (ref) =>
            assignments ??
            Stream.value(
              _batch<BaseInnerCoverAssignment>(
                [],
                cached: unqualifiedSource == 'assignments' && !rejected,
                rejected: unqualifiedSource == 'assignments' && rejected,
              ),
            ),
      ),
      plantActiveCoverLinkEvidenceProvider.overrideWith(
        (ref) =>
            links ??
            Stream.value(
              _batch<InnerCoverLinkage>(
                [],
                cached: unqualifiedSource == 'links' && !rejected,
                rejected: unqualifiedSource == 'links' && rejected,
              ),
            ),
      ),
      plantConditionTicketsProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  final subscription = container.listen(plantAssetOverviewProvider, (_, _) {});
  addTearDown(() {
    subscription.close();
    container.dispose();
  });
  return container;
}

void main() {
  test(
    'confirmed empty record and non-Down status flag a mismatch without inferring Down',
    () {
      final summary = _summary();
      expect(summary.needsReview.map((r) => r.base.id), ['base-103']);
      expect(summary.noRecordedLinkage, 1);
      expect(_overview(summary).down, 0);
      expect(_summary(down: true).needsReview, isEmpty);
      expect(_summary(active: false).rows, isEmpty);
    },
  );

  test(
    'cached pending rejected or conflicting linkage is never confirmed empty',
    () {
      for (final summary in [
        _summary(cached: true),
        _summary(pending: true),
        _summary(rejected: true),
        _summary(orphanProfile: true),
      ]) {
        expect(summary.needsReview, isEmpty);
        expect(summary.noRecordedLinkage, 0);
        expect(summary.linkageUnverified, 1);
      }
    },
  );

  test('unknown condition cannot be treated as not Down', () {
    final summary = _summary(conditionVerified: false);
    expect(summary.noRecordedLinkage, 1);
    expect(summary.needsReview, isEmpty);
    expect(summary.conditionUnverified, 1);
  });

  test(
    'actual provider qualifies every linkage source and condition before flagging Base 103',
    () async {
      final confirmed = _provider();
      await pumpEventQueue();
      final overview = confirmed.read(plantAssetOverviewProvider).requireValue;
      expect(
        overview.baseCoverReconciliation!.needsReview.single.base.id,
        _base.id,
      );
      expect(overview.down, 0);
      for (final source in [
        'classes',
        'assets',
        'covers',
        'assignments',
        'links',
        'conditions',
      ]) {
        for (final rejected in [false, true]) {
          final container = _provider(
            unqualifiedSource: source,
            rejected: rejected,
          );
          await pumpEventQueue();
          final summary = container
              .read(plantAssetOverviewProvider)
              .requireValue
              .baseCoverReconciliation!;
          expect(
            summary.needsReview,
            isEmpty,
            reason: '$source rejected=$rejected',
          );
          if (source != 'conditions') expect(summary.noRecordedLinkage, 0);
        }
      }
    },
  );

  test(
    'actual provider excludes declared Down and retired Base classes',
    () async {
      final down = _provider(down: true);
      final retired = _provider(retiredClass: true);
      await pumpEventQueue();
      expect(down.read(plantAssetOverviewProvider).requireValue.down, 1);
      expect(
        down
            .read(plantAssetOverviewProvider)
            .requireValue
            .baseCoverReconciliation!
            .needsReview,
        isEmpty,
      );
      expect(
        retired
            .read(plantAssetOverviewProvider)
            .requireValue
            .baseCoverReconciliation!
            .rows,
        isEmpty,
      );
    },
  );

  test(
    'missing errored or pending assignment and link feeds remain unknown',
    () async {
      final containers = [
        _provider(assignments: const Stream.empty()),
        _provider(links: Stream.error(StateError('unavailable'))),
        _provider(assignments: Stream.value(_batch([], pending: true))),
        _provider(links: Stream.value(_batch([], pending: true))),
      ];
      await pumpEventQueue();
      for (final container in containers) {
        final summary = container
            .read(plantAssetOverviewProvider)
            .requireValue
            .baseCoverReconciliation!;
        expect(summary.needsReview, isEmpty);
        expect(summary.noRecordedLinkage, 0);
        expect(summary.linkageUnverified, 1);
      }
    },
  );

  test(
    'delink snapshots pass through inconsistency to confirmed no linkage without stale assignments',
    () async {
      final assignments =
          StreamController<DecodedSnapshotBatch<BaseInnerCoverAssignment>>();
      final links = StreamController<DecodedSnapshotBatch<InnerCoverLinkage>>();
      final covers = StreamController<PlantEvidenceBatch<InnerCoverProfile>>();
      addTearDown(() async {
        await assignments.close();
        await links.close();
        await covers.close();
      });
      final container = _provider(
        assignments: assignments.stream,
        links: links.stream,
        covers: covers.stream,
      );
      final at = DateTime.utc(2026);
      final cover = InnerCoverProfile(
        id: 'cover-1',
        assetClassId: 'covers',
        assetClassCode: 'IC',
        assetClassName: 'Inner Cover',
        serialNumber: 'G66',
        normalizedSerialNumber: 'G66',
        sourceType: InnerCoverSourceType.legacyExisting,
        lifecycleState: InnerCoverLifecycleState.installed,
        traceabilityGrade: InnerCoverTraceabilityGrade.t0,
        currentBaseAssetInstanceId: _base.id,
        currentBaseAssetNumber: 103,
        currentLinkageId: 'link-1',
        version: 1,
        createdAt: at,
        updatedAt: at,
        lastMutationId: 'fixture',
      );
      assignments.add(
        _batch([
          BaseInnerCoverAssignment(
            baseAssetInstanceId: _base.id,
            baseAssetClassId: _baseClass.id,
            baseAssetNumber: 103,
            baseAssetName: 'Base 103',
            innerCoverId: cover.id,
            innerCoverSerialNumber: cover.serialNumber,
            linkageId: 'link-1',
            linkedAt: at,
            version: 1,
            updatedAt: at,
            lastMutationId: 'fixture',
          ),
        ]),
      );
      links.add(
        _batch([
          InnerCoverLinkage(
            id: 'link-1',
            baseAssetInstanceId: _base.id,
            baseAssetNumber: 103,
            baseAssetName: 'Base 103',
            innerCoverId: cover.id,
            innerCoverSerialNumber: cover.serialNumber,
            installedAt: at,
            installedByUid: 'fixture',
            installedByName: 'Fixture',
            active: true,
            version: 1,
          ),
        ]),
      );
      covers.add(
        PlantEvidenceBatch(
          rows: [cover],
          rejected: {},
          fromServer: true,
          observedAt: at,
        ),
      );
      await pumpEventQueue();
      BaseCoverReconciliation summary() => container
          .read(plantAssetOverviewProvider)
          .requireValue
          .baseCoverReconciliation!;
      expect(summary().linked, 1);
      expect(summary().needsReview, isEmpty);
      assignments.add(_batch([]));
      await pumpEventQueue();
      expect(summary().linkageUnverified, 1);
      expect(summary().needsReview, isEmpty);
      links.add(_batch([]));
      covers.add(
        PlantEvidenceBatch(
          rows: [],
          rejected: {},
          fromServer: true,
          observedAt: at,
        ),
      );
      await pumpEventQueue();
      expect(summary().needsReview.single.base.id, _base.id);
      expect(summary().noRecordedLinkage, 1);
      expect(container.read(plantAssetOverviewProvider).requireValue.down, 0);
    },
  );

  testWidgets(
    'Home flags recorded Base 103 mismatch and preserves declared Down count',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlantOverviewPanel(
                overview: AsyncData(_overview(_summary())),
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No Inner Cover linked, but Base not marked Down'),
        findsOneWidget,
      );
      expect(find.textContaining('103'), findsWidgets);
      expect(_overview(_summary()).down, 0);
    },
  );

  for (final (width, scale) in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'warning stays compact and both review routes are reachable at $width / $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var outerOpens = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PlantOverviewPanel(
                    overview: AsyncData(_overview(_summary())),
                    onOpen: () => outerOpens++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Review Base 103 availability'), findsNothing);
        final warning = find.text(
          'No Inner Cover linked, but Base not marked Down',
        );
        await tester.ensureVisible(warning);
        await tester.tap(warning);
        await tester.pumpAndSettle();
        final reviewBase = find.text('Review Base 103 availability');
        await tester.ensureVisible(reviewBase);
        await tester.tap(reviewBase);
        await tester.pumpAndSettle();
        final board = tester.widget<AssetConditionBoard>(
          find.byType(AssetConditionBoard),
        );
        expect(board.initialFilter, AssetConditionFilter.all);
        expect(board.initialAssetClassId, _baseClass.id);
        Navigator.of(tester.element(find.byType(AssetConditionBoard))).pop();
        await tester.pumpAndSettle();
        final reviewLinks = find.text('Review Inner Cover links');
        await tester.ensureVisible(reviewLinks);
        await tester.tap(reviewLinks);
        await tester.pumpAndSettle();
        expect(find.byType(InnerCoverLifecycleScreen), findsOneWidget);
        expect(outerOpens, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
