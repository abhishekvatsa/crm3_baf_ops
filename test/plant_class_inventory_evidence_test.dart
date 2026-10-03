import 'dart:async';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as f;

final _class = f.assetClass(
  id: 'furnaces',
  code: 'FURNACE',
  name: 'Furnaces',
  legacyKey: 'furnace',
);
final _asset = f.asset(id: 'furnace-1', assetClass: _class, number: 1);

PlantEvidenceBatch<T> _batch<T>(
  List<T> rows, {
  bool current = true,
  bool rejected = false,
}) => PlantEvidenceBatch(
  rows: rows,
  rejected: rejected ? {'unreadable-row': 'Unreadable record'} : {},
  fromServer: current,
  observedAt: DateTime.utc(2026, 10, 2),
);

ProviderContainer _provider({
  String? cachedSource,
  String? rejectedSource,
  bool empty = false,
  Stream<PlantEvidenceBatch<AssetClassRecord>>? classes,
  Stream<PlantEvidenceBatch<AssetInstanceRecord>>? assets,
}) {
  PlantEvidenceBatch<T> batch<T>(String source, List<T> rows) => _batch(
    rows,
    current: cachedSource != source,
    rejected: rejectedSource == source,
  );
  final container = ProviderContainer(
    overrides: [
      plantClassEvidenceProvider.overrideWith(
        (ref) => classes ?? Stream.value(batch('classes', [_class])),
      ),
      plantAssetEvidenceProvider.overrideWith(
        (ref) => assets ?? Stream.value(batch('assets', empty ? [] : [_asset])),
      ),
      plantManualEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('manual', [])),
      ),
      plantWorkflowEvidenceProvider.overrideWith(
        (ref) => Stream.value(
          batch(
            'workflow',
            empty ? [] : [f.workflow(key: 'furnace', number: 1)],
          ),
        ),
      ),
      plantAvailabilityEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('availability', [])),
      ),
      plantTicketEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('tickets', [])),
      ),
      plantInnerCoverEvidenceProvider.overrideWith(
        (ref) => Stream.value(batch('covers', [])),
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

Future<void> _settle(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

void main() {
  for (final numberedFeed in ['cached', 'rejected']) {
    for (final coverEvidence in [
      'current',
      'cached profiles',
      'cached classes',
      'rejected profiles',
      'rejected classes',
    ]) {
      test(
        '$numberedFeed numbered register does not determine $coverEvidence cover inventory',
        () {
          final coverClass = f.assetClass(
            id: 'covers',
            code: 'IC',
            name: 'Inner Covers',
            legacyKey: 'innerCover',
          );
          final numbered = qualifiedPlantAssetOverview(
            classes: [_class, coverClass],
            assets: [_asset],
            conditions: [],
            workflow: [f.workflow(key: 'furnace', number: 1)],
            availability: [],
            tickets: [],
            populationWarnings: [],
            manualSourcesCurrent: true,
            physicalInventoryComplete: numberedFeed != 'cached',
            rejectedAssets: numberedFeed == 'rejected'
                ? {'unreadable-row'}
                : {},
          );
          final overview = physicalPlantInventory(
            overview: numbered,
            classes: [_class, coverClass],
            profiles: [
              InnerCoverProfile(
                id: 'IC-CURRENT',
                assetClassId: coverClass.id,
                assetClassCode: coverClass.code,
                assetClassName: coverClass.name,
                serialNumber: 'IC-CURRENT',
                normalizedSerialNumber: 'IC-CURRENT',
                sourceType: InnerCoverSourceType.legacyExisting,
                lifecycleState: InnerCoverLifecycleState.installed,
                traceabilityGrade: InnerCoverTraceabilityGrade.t0,
                version: 1,
                createdAt: _asset.createdAt,
                updatedAt: _asset.updatedAt,
                lastMutationId: 'fixture',
              ),
            ],
            coverSourceWarnings: coverEvidence.startsWith('cached')
                ? ['Current $coverEvidence evidence is unconfirmed.']
                : [],
            coverPopulationWarnings: coverEvidence == 'rejected profiles'
                ? ['An unreadable cover may be missing from inventory.']
                : [],
            rejectedProfiles: coverEvidence == 'rejected profiles'
                ? {'unreadable-cover'}
                : {},
            rejectedClasses: coverEvidence == 'rejected classes'
                ? {'unreadable-class'}
                : {},
          );
          final physicalClass = overview.classes.singleWhere(
            (summary) => summary.assetClass.id == _class.id,
          );
          final covers = overview.classes.singleWhere(
            (summary) => summary.assetClass.id == coverClass.id,
          );
          expect(overview.physicalInventoryComplete, isFalse);
          expect(overview.hasCompleteEvidence, isFalse);
          expect(overview.availabilityRate, isNull);
          expect(physicalClass.inventoryComplete, isFalse);
          expect(physicalClass.availabilityRate, isNull);
          expect(covers.total, 1);
          expect(covers.inventoryComplete, coverEvidence == 'current');
          expect(
            covers.availabilityRate,
            coverEvidence == 'current' ? 1.0 : isNull,
          );
        },
      );
    }
  }

  for (final concern in [
    'none',
    'linkage unverified',
    'fitness assessment required',
    'confirmed bulging',
  ]) {
    test(
      'complete serial inventory preserves $concern through the dependency pipeline',
      () {
        final coverClass = f.assetClass(
          id: 'covers',
          code: 'IC',
          name: 'Inner Covers',
          legacyKey: 'innerCover',
        );
        final profile = InnerCoverProfile(
          id: 'IC-CURRENT',
          assetClassId: coverClass.id,
          assetClassCode: coverClass.code,
          assetClassName: coverClass.name,
          serialNumber: 'IC-CURRENT',
          normalizedSerialNumber: 'IC-CURRENT',
          sourceType: InnerCoverSourceType.legacyExisting,
          lifecycleState: InnerCoverLifecycleState.installed,
          traceabilityGrade: InnerCoverTraceabilityGrade.t0,
          version: 1,
          createdAt: _asset.createdAt,
          updatedAt: _asset.updatedAt,
          lastMutationId: 'fixture',
        );
        final uncertainLinkage = concern == 'linkage unverified';
        final assessment = concern == 'fitness assessment required';
        final confirmedBulging = concern == 'confirmed bulging';
        final stock = InnerCoverStockSummary(
          inventoryConfirmed: true,
          linkageConfirmed: !uncertainLinkage,
          bulgeEvidenceConfirmed: true,
          dependencyEvidenceConfirmed: true,
          rows: [
            InnerCoverStockRow(
              profile: profile,
              disposition: uncertainLinkage
                  ? InnerCoverStockDisposition.unverified
                  : InnerCoverStockDisposition.installed,
              reviewReasons: [
                if (uncertainLinkage) 'Assignment/linkage evidence unverified',
                if (confirmedBulging)
                  'Active obstruction with confirmed bulging',
              ],
              evidenceUnverified: uncertainLinkage,
              activeConfirmedBulging: confirmedBulging,
              pendingBulgeAssessment: false,
              bulgeHistory: confirmedBulging,
              inconclusiveBulgeAssessment: false,
            ),
          ],
        );
        final numbered = qualifiedPlantAssetOverview(
          classes: [coverClass],
          assets: [],
          conditions: [],
          workflow: [],
          availability: [],
          tickets: [],
          populationWarnings: [],
          manualSourcesCurrent: true,
        );
        final physical = physicalPlantInventory(
          overview: numbered,
          classes: [coverClass],
          profiles: [profile],
          innerCoverStock: stock,
        );
        final overview = applyInnerCoverDependencies(
          overview: physical,
          register: const BaseInnerCoverRegister(
            rows: [],
            notes: [],
            populationConfirmed: true,
            evidenceConfirmed: true,
          ),
          dependencies: InnerCoverDependencies(
            byCoverId: {
              profile.id: InnerCoverDependencyState(
                coverId: profile.id,
                serialNumber: profile.serialNumber,
                complete: true,
                warnings: [],
                reasons: [
                  if (assessment)
                    InnerCoverDependencyReason(
                      key: 'released-case-assessment',
                      sourceId: 'case-1',
                      kind: InnerCoverDependencyKind.assessment,
                      coverId: profile.id,
                      serialNumber: profile.serialNumber,
                      eventHostAssetId: 'original-base',
                      eventHostClassId: 'bases',
                      eventHostNumber: 1,
                      eventLinkageId: 'original-link',
                      awaitingServerConfirmation: false,
                    ),
                ],
              ),
            },
            evidenceWarnings: [],
            complete: true,
          ),
        );
        final covers = overview.classes.single;
        final cover = covers.innerCovers.single;
        final unverified = uncertainLinkage || assessment;
        expect(overview.physicalInventoryComplete, isTrue);
        expect(covers.inventoryComplete, isTrue);
        expect(covers.total, 1);
        expect(covers.available, concern == 'none' ? 1 : 0);
        // A known assessment hold prevents use even though fitness remains
        // unverified; uncertainty without a recorded hold stays separate.
        expect(covers.unavailable, confirmedBulging || assessment ? 1 : 0);
        expect(covers.unverifiedAvailability, uncertainLinkage ? 1 : 0);
        expect(
          covers.available + covers.unavailable + covers.unverifiedAvailability,
          covers.total,
        );
        expect(covers.down, 0);
        expect(cover.hasAssessmentRestriction, assessment);
        expect(cover.isAvailable, concern == 'none');
        expect(cover.isUnfit, confirmedBulging);
        expect(cover.hasUnverifiedEvidence, unverified);
        expect(cover.dependency!.needsCurrentAssessment, assessment);
        expect(
          overview.innerCoverStock!.rows.single.needsCurrentAssessment,
          assessment,
        );
        expect(overview.hasCompleteEvidence, !unverified);
        expect(
          covers.availabilityRate,
          unverified ? isNull : (confirmedBulging ? 0.0 : 1.0),
        );
        expect(
          overview.availabilityRate,
          unverified ? isNull : (confirmedBulging ? 0.0 : 1.0),
        );
        if (uncertainLinkage) {
          expect(cover.conditionSummary, contains('evidence unverified'));
          expect(overview.innerCoverStock!.linkageConfirmed, isFalse);
        }
        if (assessment) {
          expect(cover.conditionSummary, contains('Assessment needed'));
        }
        if (confirmedBulging) {
          expect(cover.conditionSummary, contains('Confirmed bulging'));
        }
      },
    );
  }

  test(
    'complete server registers enable only their class denominator',
    () async {
      final container = _provider();
      await _settle(container);
      final overview = container.read(plantAssetOverviewProvider).requireValue;
      expect(overview.physicalInventoryComplete, isTrue);
      expect(overview.classes.single.inventoryComplete, isTrue);
      expect(overview.classes.single.availabilityRate, 1);
    },
  );

  for (final source in ['classes', 'assets']) {
    for (final mode in ['cached', 'rejected']) {
      test(
        '$mode $source retain recorded count without certifying total',
        () async {
          final container = _provider(
            cachedSource: mode == 'cached' ? source : null,
            rejectedSource: mode == 'rejected' ? source : null,
          );
          await _settle(container);
          final overview = container
              .read(plantAssetOverviewProvider)
              .requireValue;
          expect(overview.total, 1);
          expect(overview.physicalInventoryComplete, isFalse);
          expect(overview.classes.single.inventoryComplete, isFalse);
          expect(overview.classes.single.availabilityRate, isNull);
        },
      );
    }
  }

  test(
    'unverified condition evidence does not falsely change inventory coverage',
    () async {
      final container = _provider(cachedSource: 'workflow');
      await _settle(container);
      final overview = container.read(plantAssetOverviewProvider).requireValue;
      final summary = overview.classes.single;
      expect(overview.physicalInventoryComplete, isTrue);
      expect(summary.inventoryComplete, isTrue);
      expect(summary.available, 0);
      expect(summary.unavailable, 0);
      expect(summary.unverifiedAvailability, 1);
      expect(summary.availabilityRate, isNull);
    },
  );

  test(
    'confirmed empty registry is distinct from cached empty registry',
    () async {
      final current = _provider(empty: true);
      final cached = _provider(empty: true, cachedSource: 'assets');
      await _settle(current);
      await _settle(cached);
      expect(
        current
            .read(plantAssetOverviewProvider)
            .requireValue
            .physicalInventoryComplete,
        isTrue,
      );
      expect(
        cached
            .read(plantAssetOverviewProvider)
            .requireValue
            .physicalInventoryComplete,
        isFalse,
      );
      expect(
        current
            .read(plantAssetOverviewProvider)
            .requireValue
            .classes
            .single
            .availabilityRate,
        isNull,
      );
      expect(
        cached
            .read(plantAssetOverviewProvider)
            .requireValue
            .classes
            .single
            .availabilityRate,
        isNull,
      );
    },
  );

  test(
    'unresolved registry stream remains loading rather than zero assets',
    () async {
      final source =
          StreamController<PlantEvidenceBatch<AssetInstanceRecord>>();
      addTearDown(source.close);
      final container = _provider(assets: source.stream);
      await _settle(container);
      expect(container.read(plantAssetOverviewProvider).isLoading, isTrue);
      source.add(_batch([_asset]));
      await _settle(container);
      expect(container.read(plantAssetOverviewProvider).requireValue.total, 1);
    },
  );

  test('registry read error is not a zero-asset success', () async {
    final container = _provider(
      assets: Stream.error(StateError('Registry unavailable')),
    );
    await _settle(container);
    expect(container.read(plantAssetOverviewProvider).hasError, isTrue);
  });
}
