import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/reports/domain/operations_report_asset_inventory.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'plant_asset_overview_test.dart' as f;

void main() {
  final cls = f.assetClass(
    id: 'furnaces',
    code: 'FURNACE',
    name: 'Furnaces',
    legacyKey: 'furnace',
  );
  final good = f.asset(id: 'good', assetClass: cls, number: 1);
  final missing = f.asset(id: 'missing', assetClass: cls, number: 2);
  final coverClass = f.assetClass(
    id: 'covers',
    code: 'INNER_COVER',
    name: 'Inner Covers',
    legacyKey: 'innerCover',
  );
  InnerCoverProfile cover(
    String id,
    InnerCoverLifecycleState state, {
    String? serial,
  }) => InnerCoverProfile(
    id: id,
    assetClassId: coverClass.id,
    assetClassCode: coverClass.code,
    assetClassName: coverClass.name,
    serialNumber: serial ?? id,
    normalizedSerialNumber: serial ?? id,
    sourceType: InnerCoverSourceType.legacyExisting,
    lifecycleState: state,
    traceabilityGrade: InnerCoverTraceabilityGrade.t0,
    version: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    lastMutationId: id,
  );
  PlantAssetState state(AssetInstanceRecord a) => PlantAssetState(
    asset: a,
    operationalCondition: null,
    availability: null,
    workflowStatus: f.workflow(key: 'furnace', number: a.assetNumber),
  );
  test(
    'Home and reports count serial covers once and retain salvage stock',
    () {
      final placeholder = f.asset(
        id: 'position-1',
        assetClass: coverClass,
        number: 1,
      );
      final states = [state(good), state(placeholder)];
      final profiles = [
        cover('IC-1', InnerCoverLifecycleState.installed),
        cover('IC-2', InnerCoverLifecycleState.underRepair),
        cover('IC-3', InnerCoverLifecycleState.retiredForSalvage),
        cover('IC-4', InnerCoverLifecycleState.disposed),
        cover('IC-5', InnerCoverLifecycleState.fullyConsumedAsDonor),
      ];
      final plant = physicalPlantInventory(
        overview: PlantAssetOverview(classes: [], assets: states),
        classes: [cls, coverClass],
        profiles: profiles,
      );
      final report = buildOperationsReportAssetInventory(
        assetClasses: [cls, coverClass],
        assetStates: states,
        innerCoverProfiles: profiles,
        selectedAssetClassId: null,
        selectedAssetInstanceId: null,
      );
      expect(plant.total, 4);
      expect(plant.assets.single.asset.id, good.id);
      expect(plant.available, 2);
      expect(plant.underMaintenance, 1);
      expect(plant.unfit, 1);
      expect(report.total, plant.total);
      expect(report.available, plant.available);
      expect(report.underMaintenance, plant.underMaintenance);
      expect(report.unfit, plant.unfit);
    },
  );
  test('report inventory enforces exact class and identity scope itself', () {
    final rows = [state(good), state(missing)];
    final report = buildOperationsReportAssetInventory(
      assetClasses: [cls, coverClass],
      assetStates: rows,
      innerCoverProfiles: [cover('IC-1', InnerCoverLifecycleState.installed)],
      selectedAssetClassId: cls.id,
      selectedAssetInstanceId: good.id,
    );
    expect(report.total, 1);
    expect(report.numberedAssetStates.single.asset.id, good.id);
    final serial = buildOperationsReportAssetInventory(
      assetClasses: [cls, coverClass],
      assetStates: rows,
      innerCoverProfiles: [cover('IC-1', InnerCoverLifecycleState.installed)],
      selectedAssetClassId: coverClass.id,
      selectedAssetInstanceId: 'IC-1',
      selectedSubjectKind: OperationsReportSubjectKind.innerCover,
    );
    expect(serial.total, 1);
    expect(serial.numberedAssetStates, isEmpty);
  });
  test(
    'report adapter retains qualified missing profiles and never refreshes away their warnings',
    () {
      final retained = PlantInnerCoverState(
        profile: cover('IC-1', InnerCoverLifecycleState.installed),
        evidenceWarnings: ['Previously observed profile missing'],
      );
      final report = buildOperationsReportAssetInventory(
        assetClasses: [coverClass],
        assetStates: [],
        innerCoverProfiles: [],
        qualifiedCoverStates: [retained],
        selectedAssetClassId: null,
        selectedAssetInstanceId: null,
      );
      expect(report.total, 1);
      expect(report.available, 0);
      expect(report.unknown, 1);
      expect(
        report.population.innerCovers.single.evidenceWarnings,
        retained.evidenceWarnings,
      );
      final emptyQualified = buildOperationsReportAssetInventory(
        assetClasses: [coverClass],
        assetStates: [],
        innerCoverProfiles: [retained.profile],
        qualifiedCoverStates: [],
        selectedAssetClassId: null,
        selectedAssetInstanceId: null,
      );
      expect(emptyQualified.total, 0);
    },
  );
  test(
    'orphan cover remains inventory with unknown condition, never silently zero',
    () {
      final plant = physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [],
        profiles: [cover('IC-1', InnerCoverLifecycleState.installed)],
      );
      expect(plant.total, 1);
      expect(plant.available, 0);
      expect(plant.unverifiedWorkflowEvidence, 1);
      expect(plant.availabilityRate, isNull);
    },
  );
  test(
    'duplicate serial identities are explicitly uncertain and never available',
    () {
      final plant = physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [coverClass],
        profiles: [
          cover('a', InnerCoverLifecycleState.installed, serial: 'IC1'),
          cover('b', InnerCoverLifecycleState.installed, serial: 'IC1'),
        ],
      );
      expect(plant.total, 2);
      expect(plant.available, 0);
      expect(plant.evidenceWarnings, hasLength(1));
      expect(plant.availabilityRate, isNull);
    },
  );
  test(
    'profile-specific damage does not contaminate another serial identity',
    () {
      final plant = physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [coverClass],
        profiles: [
          cover('a', InnerCoverLifecycleState.installed),
          cover('b', InnerCoverLifecycleState.installed),
        ],
        rejectedProfiles: {'a'},
      );
      expect(plant.total, 2);
      expect(plant.available, 1);
      expect(plant.availabilityRate, isNull);
    },
  );
  test(
    'unavailable profile feed preserves last known stock without confirming availability',
    () {
      final plant = physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [coverClass],
        profiles: [cover('a', InnerCoverLifecycleState.installed)],
        coverSourceWarnings: ['Server unavailable'],
      );
      expect(plant.total, 1);
      expect(plant.available, 0);
      expect(plant.hasCompleteEvidence, isFalse);
    },
  );
  test(
    'missing workflow affects its asset, independently of register order',
    () {
      for (final rows in [
        [good, missing],
        [missing, good],
      ]) {
        final result = qualifiedPlantAssetOverview(
          classes: [cls],
          assets: rows,
          conditions: [],
          workflow: [f.workflow(key: 'furnace', number: 1)],
          availability: [],
          tickets: [],
          populationWarnings: [],
          manualSourcesCurrent: true,
        );
        expect(result.total, 2);
        expect(result.available, 1);
        expect(
          result.assets
              .singleWhere((a) => a.asset.id == good.id)
              .evidenceWarnings,
          isEmpty,
        );
        expect(result.evidenceWarnings, isNotEmpty);
      }
    },
  );
  test('known asset with absent class remains counted and unknown', () {
    final result = qualifiedPlantAssetOverview(
      classes: [],
      assets: [good],
      conditions: [],
      workflow: [],
      availability: [],
      tickets: [],
      populationWarnings: [],
      manualSourcesCurrent: true,
    );
    expect(result.total, 1);
    expect(result.available, 0);
    expect(result.assets.single.permitsManualChange, isFalse);
    expect(result.evidenceWarnings, isNotEmpty);
  });
  test('legacy workflow is not borrowed across duplicate class mappings', () {
    final otherClass = f.assetClass(
      id: 'other',
      code: 'OTHER',
      name: 'Other furnace',
      legacyKey: 'furnace',
    );
    final other = f.asset(id: 'other-1', assetClass: otherClass, number: 1);
    final result = qualifiedPlantAssetOverview(
      classes: [cls, otherClass],
      assets: [good, other],
      conditions: [],
      workflow: [f.workflow(key: 'furnace', number: 1)],
      availability: [],
      tickets: [],
      populationWarnings: [],
      manualSourcesCurrent: true,
    );
    expect(result.total, 2);
    expect(result.available, 0);
    expect(result.unverifiedWorkflowEvidence, 2);
  });
  test(
    'exact workflow identifies one asset despite same legacy tuple elsewhere',
    () {
      final otherClass = f.assetClass(
        id: 'other',
        code: 'OTHER',
        name: 'Other furnace',
        legacyKey: 'furnace',
      );
      final other = f.asset(id: 'other-1', assetClass: otherClass, number: 1);
      final result = qualifiedPlantAssetOverview(
        classes: [cls, otherClass],
        assets: [other, good],
        conditions: [],
        workflow: [
          f.workflow(
            key: 'furnace',
            number: 1,
            assetClassId: cls.id,
            assetInstanceId: good.id,
          ),
        ],
        availability: [],
        tickets: [],
        populationWarnings: [],
        manualSourcesCurrent: true,
      );
      expect(result.available, 1);
      expect(
        result.assets.singleWhere((a) => a.asset.id == other.id).workflowStatus,
        isNull,
      );
    },
  );
  test('a bad workflow does not erase a verified manual Down declaration', () {
    final result = qualifiedPlantAssetOverview(
      classes: [cls],
      assets: [good],
      conditions: [
        f.condition(asset: good, condition: AssetOperationalCondition.down),
      ],
      workflow: [
        f.workflow(
          key: 'furnace',
          number: 99,
          assetClassId: cls.id,
          assetInstanceId: good.id,
        ),
      ],
      availability: [],
      tickets: [],
      populationWarnings: [],
      manualSourcesCurrent: true,
    );
    expect(result.down, 1);
    expect(result.available, 0);
  });
  test(
    'standby and out-of-service are physical inventory, not availability',
    () {
      final rows = [
        good,
        f.asset(
          id: 'standby',
          assetClass: cls,
          number: 2,
          serviceState: AssetServiceState.standby,
        ),
        f.asset(
          id: 'out',
          assetClass: cls,
          number: 3,
          serviceState: AssetServiceState.outOfService,
        ),
      ];
      final result = qualifiedPlantAssetOverview(
        classes: [cls],
        assets: rows,
        conditions: [],
        workflow: [
          for (final row in rows)
            f.workflow(key: 'furnace', number: row.assetNumber),
        ],
        availability: [],
        tickets: [],
        populationWarnings: [],
        manualSourcesCurrent: true,
      );
      expect(result.total, 3);
      expect(result.available, 1);
      expect(result.standby, 1);
      expect(result.outOfService, 1);
    },
  );
}
