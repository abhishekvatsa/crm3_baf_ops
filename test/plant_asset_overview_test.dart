import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_availability_record.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:flutter_test/flutter_test.dart';

final _time = DateTime.utc(2026, 8, 14);

AssetClassRecord assetClass({
  required String id,
  required String code,
  required String name,
  String? legacyKey,
}) => AssetClassRecord(
  id: id,
  code: code,
  name: name,
  majorArea: 'BAF Shop',
  legacyAssetTypeKey: legacyKey,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: _time,
  createdByUid: 'admin',
  updatedAt: _time,
  updatedByUid: 'admin',
  lastMutationId: 'mutation-1',
);

AssetInstanceRecord asset({
  required String id,
  required AssetClassRecord assetClass,
  required int number,
  AssetServiceState serviceState = AssetServiceState.inService,
}) => AssetInstanceRecord(
  id: id,
  assetClassId: assetClass.id,
  assetClassCode: assetClass.code,
  assetClassName: assetClass.name,
  assetNumber: number,
  name: '${assetClass.name} $number',
  serviceState: serviceState,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: 1,
  createdAt: _time,
  updatedAt: _time,
  lastMutationId: 'mutation-1',
);

AssetOperationalConditionRecord condition({
  required AssetInstanceRecord asset,
  required AssetOperationalCondition condition,
}) => AssetOperationalConditionRecord(
  assetInstanceId: asset.id,
  assetClassId: asset.assetClassId,
  assetClassCode: asset.assetClassCode,
  assetClassName: asset.assetClassName,
  assetNumber: asset.assetNumber,
  assetName: asset.name,
  condition: condition,
  active: true,
  causes: const [AssetConditionCause.breakdown],
  reason: 'Unavailable for safe operation.',
  linkedIssueIds: const [],
  declaredAt: _time,
  declaredByUid: 'ops',
  declaredByName: 'Operations',
  restoredAt: null,
  restoredByUid: null,
  restoredByName: null,
  previousCondition: AssetOperationalCondition.available,
  version: 1,
  updatedAt: _time,
  updatedByUid: 'ops',
  updatedByName: 'Operations',
  lastMutationId: 'condition-1',
);

EquipmentStatusRecord workflow({
  required String key,
  required int number,
  String? assetClassId,
  String? assetInstanceId,
  int maintenance = 0,
  int red = 0,
}) =>
    EquipmentStatusRecord()
      ..assetTypeKey = key
      ..assetNumber = number
      ..assetClassId = assetClassId
      ..assetInstanceId = assetInstanceId
      ..openMaintenanceCount = maintenance
      ..openRedCount = red;

AssetAvailabilityRecord blocked({required AssetInstanceRecord asset}) =>
    AssetAvailabilityRecord(
      assetType: asset.assetClassCode.toLowerCase(),
      assetClassId: asset.assetClassId,
      assetInstanceId: asset.id,
      assetNumber: asset.assetNumber,
      state: AssetAvailabilityState.temporarilyBlocked,
      activeConstraintId: 'case-1_${asset.id}',
      reasonType: 'furnaceStuckup',
      linkedCaseId: 'case-1',
      linkedTicketId: 'ticket-1',
      since: _time,
      updatedAt: _time,
      version: 1,
    );

void main() {
  test('preserves overlapping down and maintenance facts', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'FURNACE',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace1 = asset(id: 'furnace-1', assetClass: furnace, number: 1);
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace],
      assetInstances: [furnace1],
      operationalConditions: [
        condition(asset: furnace1, condition: AssetOperationalCondition.down),
      ],
      workflowStatuses: [workflow(key: 'furnace', number: 1, maintenance: 1)],
    );

    expect(overview.total, 1);
    expect(overview.down, 1);
    expect(overview.underMaintenance, 1);
    expect(overview.available, 0);
    expect(overview.classes.single.attention, 1);
  });

  test('temporary stuck-up constraints remove assets from available count', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'FURNACE',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace1 = asset(id: 'furnace-1', assetClass: furnace, number: 1);
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace],
      assetInstances: [furnace1],
      operationalConditions: const [],
      workflowStatuses: const [],
      availabilityProjections: [blocked(asset: furnace1)],
    );

    expect(overview.temporarilyBlocked, 1);
    expect(overview.available, 0);
    expect(overview.classes.single.attention, 1);
  });

  test('availability identity disagreement fails closed', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'FURNACE',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace1 = asset(id: 'furnace-1', assetClass: furnace, number: 1);
    final malformed = AssetAvailabilityRecord(
      assetType: 'furnace',
      assetClassId: furnace1.assetClassId,
      assetInstanceId: furnace1.id,
      assetNumber: 2,
      state: AssetAvailabilityState.temporarilyBlocked,
      activeConstraintId: 'case-1_${furnace1.id}',
      reasonType: 'furnaceStuckup',
      linkedCaseId: 'case-1',
      linkedTicketId: 'ticket-1',
      since: _time,
      updatedAt: _time,
      version: 1,
    );

    expect(
      () => PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: [furnace1],
        operationalConditions: const [],
        workflowStatuses: const [],
        availabilityProjections: [malformed],
      ),
      throwsStateError,
    );
  });

  test('custom class never inherits a legacy workflow projection', () {
    final custom = assetClass(
      id: 'custom-class',
      code: 'SPECIAL_FURNACE',
      name: 'Special Furnace',
    );
    final custom1 = asset(id: 'custom-1', assetClass: custom, number: 1);
    final overview = PlantAssetOverview.build(
      assetClasses: [custom],
      assetInstances: [custom1],
      operationalConditions: const [],
      workflowStatuses: [workflow(key: 'furnace', number: 1, maintenance: 1)],
    );

    expect(overview.underMaintenance, 0);
    expect(overview.available, 1);
  });

  test('same-number custom classes retain separate workflow projections', () {
    final annealingCar = assetClass(
      id: 'annealing-car-class',
      code: 'ANNEALING_CAR',
      name: 'Annealing Car',
    );
    final transferCar = assetClass(
      id: 'transfer-car-class',
      code: 'TRANSFER_CAR',
      name: 'Transfer Car',
    );
    final annealingCar3 = asset(
      id: 'annealing-car-3',
      assetClass: annealingCar,
      number: 3,
    );
    final transferCar3 = asset(
      id: 'transfer-car-3',
      assetClass: transferCar,
      number: 3,
    );

    final overview = PlantAssetOverview.build(
      assetClasses: [annealingCar, transferCar],
      assetInstances: [annealingCar3, transferCar3],
      operationalConditions: const [],
      workflowStatuses: [
        workflow(
          key: 'governedCustom',
          number: 3,
          assetClassId: annealingCar.id,
          assetInstanceId: annealingCar3.id,
          maintenance: 1,
        ),
        workflow(
          key: 'governedCustom',
          number: 3,
          assetClassId: transferCar.id,
          assetInstanceId: transferCar3.id,
          red: 1,
        ),
      ],
    );

    expect(overview.underMaintenance, 2);
    expect(
      overview.assets
          .firstWhere((state) => state.asset.id == annealingCar3.id)
          .workflowStatus
          ?.openMaintenanceCount,
      1,
    );
    expect(
      overview.assets
          .firstWhere((state) => state.asset.id == transferCar3.id)
          .workflowStatus
          ?.openRedCount,
      1,
    );
  });

  test('standby and out-of-service states are not reported as available', () {
    final base = assetClass(
      id: 'base-class',
      code: 'BASE',
      name: 'Base',
      legacyKey: 'base',
    );
    final overview = PlantAssetOverview.build(
      assetClasses: [base],
      assetInstances: [
        asset(
          id: 'base-1',
          assetClass: base,
          number: 1,
          serviceState: AssetServiceState.standby,
        ),
        asset(
          id: 'base-2',
          assetClass: base,
          number: 2,
          serviceState: AssetServiceState.outOfService,
        ),
      ],
      operationalConditions: const [],
      workflowStatuses: const [],
    );

    expect(overview.available, 0);
    expect(overview.standby, 1);
    expect(overview.outOfService, 1);
  });

  test('condition identity disagreement fails closed', () {
    final base = assetClass(
      id: 'base-class',
      code: 'BASE',
      name: 'Base',
      legacyKey: 'base',
    );
    final base1 = asset(id: 'base-1', assetClass: base, number: 1);
    final malformed = condition(
      asset: base1,
      condition: AssetOperationalCondition.unfit,
    );
    final wrong = AssetOperationalConditionRecord(
      assetInstanceId: malformed.assetInstanceId,
      assetClassId: malformed.assetClassId,
      assetClassCode: malformed.assetClassCode,
      assetClassName: malformed.assetClassName,
      assetNumber: 2,
      assetName: malformed.assetName,
      condition: malformed.condition,
      active: malformed.active,
      causes: malformed.causes,
      reason: malformed.reason,
      linkedIssueIds: malformed.linkedIssueIds,
      declaredAt: malformed.declaredAt,
      declaredByUid: malformed.declaredByUid,
      declaredByName: malformed.declaredByName,
      restoredAt: malformed.restoredAt,
      restoredByUid: malformed.restoredByUid,
      restoredByName: malformed.restoredByName,
      previousCondition: malformed.previousCondition,
      version: malformed.version,
      updatedAt: malformed.updatedAt,
      updatedByUid: malformed.updatedByUid,
      updatedByName: malformed.updatedByName,
      lastMutationId: malformed.lastMutationId,
    );

    expect(
      () => PlantAssetOverview.build(
        assetClasses: [base],
        assetInstances: [base1],
        operationalConditions: [wrong],
        workflowStatuses: const [],
      ),
      throwsStateError,
    );
  });

  test('mutable display names do not invalidate permanent asset identity', () {
    final base = assetClass(
      id: 'base-class',
      code: 'BASE',
      name: 'Annealing Base',
      legacyKey: 'base',
    );
    final base1 = asset(id: 'base-1', assetClass: base, number: 1);
    final oldNames = condition(
      asset: base1,
      condition: AssetOperationalCondition.down,
    );
    final renamed = AssetOperationalConditionRecord(
      assetInstanceId: oldNames.assetInstanceId,
      assetClassId: oldNames.assetClassId,
      assetClassCode: oldNames.assetClassCode,
      assetClassName: 'Base',
      assetNumber: oldNames.assetNumber,
      assetName: 'Old Base 1 name',
      condition: oldNames.condition,
      active: oldNames.active,
      causes: oldNames.causes,
      reason: oldNames.reason,
      linkedIssueIds: oldNames.linkedIssueIds,
      declaredAt: oldNames.declaredAt,
      declaredByUid: oldNames.declaredByUid,
      declaredByName: oldNames.declaredByName,
      restoredAt: oldNames.restoredAt,
      restoredByUid: oldNames.restoredByUid,
      restoredByName: oldNames.restoredByName,
      previousCondition: oldNames.previousCondition,
      version: oldNames.version,
      updatedAt: oldNames.updatedAt,
      updatedByUid: oldNames.updatedByUid,
      updatedByName: oldNames.updatedByName,
      lastMutationId: oldNames.lastMutationId,
    );

    final overview = PlantAssetOverview.build(
      assetClasses: [base],
      assetInstances: [base1],
      operationalConditions: [renamed],
      workflowStatuses: const [],
    );
    expect(overview.down, 1);
    expect(overview.classes.single.assetClass.name, 'Annealing Base');
    expect(overview.assets.single.asset.name, 'Annealing Base 1');
  });
}
