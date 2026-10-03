import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as f;

final _base = f.assetClass(
  id: 'bases',
  code: 'BASE',
  name: 'Bases',
  legacyKey: 'base',
);
final _furnace = f.assetClass(
  id: 'furnaces',
  code: 'FURNACE',
  name: 'Furnaces',
  legacyKey: 'furnace',
);
final _cooler = f.assetClass(
  id: 'coolers',
  code: 'FORCED_COOLER',
  name: 'Forced Coolers',
  legacyKey: 'forceCooler',
);

void _expectPartition(
  PlantAssetClassSummary summary,
  int available,
  int unavailable,
  int unverified,
) {
  expect(summary.available, available);
  expect(summary.unavailable, unavailable);
  expect(summary.unverifiedAvailability, unverified);
  expect(
    summary.available + summary.unavailable + summary.unverifiedAvailability,
    summary.total,
  );
}

void main() {
  test(
    'one unavailable Base remains distinct from fully available other classes',
    () {
      final assets = [
        for (var n = 1; n <= 36; n++)
          f.asset(id: 'base-$n', assetClass: _base, number: n),
        for (var n = 1; n <= 12; n++)
          f.asset(id: 'furnace-$n', assetClass: _furnace, number: n),
        for (var n = 1; n <= 10; n++)
          f.asset(id: 'cooler-$n', assetClass: _cooler, number: n),
      ];
      final overview = PlantAssetOverview.build(
        assetClasses: [_base, _furnace, _cooler],
        assetInstances: assets,
        operationalConditions: [
          f.condition(
            asset: assets.first,
            condition: AssetOperationalCondition.down,
          ),
        ],
        workflowStatuses: [
          for (final asset in assets)
            f.workflow(
              key: asset.assetClassId == _base.id
                  ? 'base'
                  : asset.assetClassId == _furnace.id
                  ? 'furnace'
                  : 'forceCooler',
              number: asset.assetNumber,
            ),
        ],
      );
      final classes = {
        for (final summary in overview.classes) summary.assetClass.id: summary,
      };
      _expectPartition(classes[_base.id]!, 35, 1, 0);
      _expectPartition(classes[_furnace.id]!, 12, 0, 0);
      _expectPartition(classes[_cooler.id]!, 10, 0, 0);
      expect(classes[_base.id]!.availabilityRate, 35 / 36);
    },
  );

  test('overlapping restrictions count once and survive missing workflow', () {
    final down = f.asset(id: 'down', assetClass: _furnace, number: 1);
    final unknown = f.asset(id: 'unknown', assetClass: _furnace, number: 2);
    final overlap = f.asset(id: 'overlap', assetClass: _furnace, number: 3);
    final summary = PlantAssetOverview.build(
      assetClasses: [_furnace],
      assetInstances: [down, unknown, overlap],
      operationalConditions: [
        f.condition(asset: down, condition: AssetOperationalCondition.down),
        f.condition(asset: overlap, condition: AssetOperationalCondition.down),
      ],
      availabilityProjections: [f.blocked(asset: overlap)],
      workflowStatuses: [
        f.workflow(key: 'furnace', number: 3, maintenance: 1, red: 1),
      ],
    ).classes.single;
    _expectPartition(summary, 0, 2, 1);
    expect(summary.down, 2);
    expect(summary.underMaintenance, 1);
    expect(summary.temporarilyBlocked, 1);
    expect(summary.unverifiedWorkflowEvidence, 2);
    expect(summary.availabilityRate, isNull);
  });

  test(
    'manual, issue, stuck-up and workflow restrictions each exclude an asset',
    () {
      final rows = [
        for (var n = 1; n <= 7; n++)
          f.asset(id: 'furnace-$n', assetClass: _furnace, number: n),
      ];
      final summary = PlantAssetOverview.build(
        assetClasses: [_furnace],
        assetInstances: rows,
        operationalConditions: [
          f.condition(
            asset: rows[0],
            condition: AssetOperationalCondition.down,
          ),
          f.condition(
            asset: rows[1],
            condition: AssetOperationalCondition.unfit,
          ),
        ],
        workflowStatuses: [
          for (final row in rows)
            f.workflow(
              key: 'furnace',
              number: row.assetNumber,
              maintenance: row.assetNumber == 6 ? 1 : 0,
              red: row.assetNumber == 7 ? 1 : 0,
            ),
        ],
        availabilityProjections: [f.blocked(asset: rows[2])],
        maintenanceTickets: [
          f.issueCondition(
            id: 'issue-unavailable',
            asset: rows[3],
            effect: MaintenanceIssuePlantConditionEffect.unavailable,
          ),
          f.issueCondition(
            id: 'issue-unfit',
            asset: rows[4],
            effect: MaintenanceIssuePlantConditionEffect.unfit,
          ),
        ],
      ).classes.single;
      _expectPartition(summary, 0, 7, 0);
      for (final row in summary.assets) {
        expect(
          row.hasKnownAvailabilityRestriction,
          isTrue,
          reason: row.asset.id,
        );
        expect(row.isAvailable, isFalse, reason: row.asset.id);
      }
    },
  );

  test(
    'Inner Cover evidence incompleteness does not contaminate physical class denominator',
    () {
      final coverClass = f.assetClass(
        id: 'covers',
        code: 'INNER_COVER',
        name: 'Inner Covers',
        legacyKey: 'innerCover',
      );
      final row = f.asset(id: 'furnace-1', assetClass: _furnace, number: 1);
      final source = PlantAssetOverview.build(
        assetClasses: [_furnace, coverClass],
        assetInstances: [row],
        operationalConditions: [],
        workflowStatuses: [f.workflow(key: 'furnace', number: 1)],
      );
      final result = physicalPlantInventory(
        overview: source,
        classes: [_furnace, coverClass],
        profiles: [
          InnerCoverProfile(
            id: 'IC-1',
            assetClassId: coverClass.id,
            assetClassCode: coverClass.code,
            assetClassName: coverClass.name,
            serialNumber: 'IC-1',
            normalizedSerialNumber: 'IC-1',
            sourceType: InnerCoverSourceType.legacyExisting,
            lifecycleState: InnerCoverLifecycleState.installed,
            traceabilityGrade: InnerCoverTraceabilityGrade.t0,
            version: 1,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            lastMutationId: 'fixture',
          ),
        ],
        coverPopulationWarnings: [
          'An unreadable profile may be missing from inventory.',
        ],
      );
      final classes = {
        for (final summary in result.classes) summary.assetClass.id: summary,
      };
      expect(result.physicalInventoryComplete, isTrue);
      expect(classes[_furnace.id]!.inventoryComplete, isTrue);
      expect(classes[_furnace.id]!.availabilityRate, 1);
      expect(classes[coverClass.id]!.inventoryComplete, isFalse);
      expect(classes[coverClass.id]!.availabilityRate, isNull);
    },
  );

  test('standby and out of service are unavailable without implying Down', () {
    final summary = PlantAssetOverview.build(
      assetClasses: [_base],
      assetInstances: [
        f.asset(
          id: 'standby',
          assetClass: _base,
          number: 1,
          serviceState: AssetServiceState.standby,
        ),
        f.asset(
          id: 'out',
          assetClass: _base,
          number: 2,
          serviceState: AssetServiceState.outOfService,
        ),
      ],
      operationalConditions: [],
      workflowStatuses: [],
    ).classes.single;
    _expectPartition(summary, 0, 2, 0);
    expect(summary.down, 0);
    expect(summary.unverifiedWorkflowEvidence, 2);
  });

  test('known linked-cover assessment prevents use without physical Down', () {
    final row = f.asset(id: 'base-1', assetClass: _base, number: 1);
    final state = PlantAssetState(
      asset: row,
      operationalCondition: null,
      availability: null,
      workflowStatus: f.workflow(key: 'base', number: 1),
      linkedInnerCoverDependency: InnerCoverDependencyState(
        coverId: 'cover-1',
        serialNumber: 'IC-1',
        complete: true,
        warnings: [],
        reasons: const [
          InnerCoverDependencyReason(
            key: 'assessment',
            sourceId: 'case-1',
            kind: InnerCoverDependencyKind.assessment,
            coverId: 'cover-1',
            serialNumber: 'IC-1',
            eventHostAssetId: 'base-1',
            eventHostClassId: 'bases',
            eventHostNumber: 1,
            eventLinkageId: 'link-1',
            awaitingServerConfirmation: false,
          ),
        ],
      ),
    );
    final summary = PlantAssetClassSummary(assetClass: _base, assets: [state]);
    _expectPartition(summary, 0, 1, 0);
    expect(summary.availabilityRate, isNull);
    expect(summary.down, 0);
    expect(summary.unfit, 0);
    expect(state.linkedInnerCoverDependency!.needsCurrentAssessment, isTrue);
  });

  test('empty complete and incomplete registers both avoid a percentage', () {
    final empty = PlantAssetClassSummary(assetClass: _furnace, assets: []);
    final incomplete = PlantAssetClassSummary(
      assetClass: _furnace,
      assets: [],
      inventoryComplete: false,
    );
    _expectPartition(empty, 0, 0, 0);
    _expectPartition(incomplete, 0, 0, 0);
    expect(empty.inventoryComplete, isTrue);
    expect(incomplete.inventoryComplete, isFalse);
    expect(empty.availabilityRate, isNull);
    expect(incomplete.availabilityRate, isNull);
  });

  test(
    'unknown class retains its registered asset and incomplete denominator',
    () {
      final result = qualifiedPlantAssetOverview(
        classes: [],
        assets: [f.asset(id: 'orphan', assetClass: _furnace, number: 1)],
        conditions: [],
        workflow: [],
        availability: [],
        tickets: [],
        populationWarnings: [],
        manualSourcesCurrent: true,
      );
      expect(result.total, 1);
      expect(result.unclassifiedAssets.single.asset.id, 'orphan');
      expect(result.physicalInventoryComplete, isFalse);
      expect(result.available, 0);
    },
  );

  test(
    'inventory incompleteness survives physical and dependency transforms',
    () {
      final input = qualifiedPlantAssetOverview(
        classes: [_furnace],
        assets: [f.asset(id: 'furnace-1', assetClass: _furnace, number: 1)],
        conditions: [],
        workflow: [f.workflow(key: 'furnace', number: 1)],
        availability: [],
        tickets: [],
        populationWarnings: [],
        manualSourcesCurrent: true,
        physicalInventoryComplete: false,
      );
      final physical = physicalPlantInventory(
        overview: input,
        classes: [_furnace],
        profiles: [],
      );
      final result = applyInnerCoverDependencies(
        overview: physical,
        register: const BaseInnerCoverRegister(
          rows: [],
          notes: [],
          populationConfirmed: true,
          evidenceConfirmed: true,
        ),
        dependencies: InnerCoverDependencies(
          byCoverId: {},
          evidenceWarnings: [],
          complete: true,
        ),
      );
      for (final overview in [input, physical, result]) {
        expect(overview.physicalInventoryComplete, isFalse);
        expect(overview.hasCompleteEvidence, isFalse);
        final summary = overview.classes.single;
        _expectPartition(summary, 1, 0, 0);
        expect(summary.inventoryComplete, isFalse);
        expect(summary.availabilityRate, isNull);
      }
    },
  );

  test(
    'retired physical records do not enter the active class denominator',
    () {
      final active = f.asset(id: 'active', assetClass: _furnace, number: 1);
      final retired = AssetInstanceRecord(
        id: 'retired',
        assetClassId: _furnace.id,
        assetClassCode: _furnace.code,
        assetClassName: _furnace.name,
        assetNumber: 2,
        name: 'Retired Furnace',
        serviceState: AssetServiceState.inService,
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Operations',
        accountableRoleKeys: const ['operations'],
        status: AssetHierarchyStatus.retired,
        activeComponentCount: 0,
        version: 1,
        createdAt: active.createdAt,
        updatedAt: active.updatedAt,
        lastMutationId: 'retired',
      );
      final summary = PlantAssetOverview.build(
        assetClasses: [_furnace],
        assetInstances: [active, retired],
        operationalConditions: [],
        workflowStatuses: [
          f.workflow(key: 'furnace', number: 1),
          f.workflow(key: 'furnace', number: 2),
        ],
      ).classes.single;
      _expectPartition(summary, 1, 0, 0);
    },
  );
}
