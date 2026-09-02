import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_availability_record.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
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

MaintenanceRecord issueCondition({
  required String id,
  required AssetInstanceRecord asset,
  required MaintenanceIssuePlantConditionEffect effect,
  String description = 'Cooling-water leakage requires repair',
  bool resolved = false,
  bool synced = true,
}) =>
    MaintenanceRecord()
      ..firestoreId = id
      ..version = resolved ? 2 : 1
      ..isSynced = synced
      ..assetType = AssetType.values.byName(
        asset.assetClassCode.toLowerCase() == 'forced_cooler'
            ? 'forceCooler'
            : asset.assetClassCode.toLowerCase(),
      )
      ..assetNumber = asset.assetNumber
      ..assetHierarchyRefJson = asset.toReference().encode()
      ..maintenanceType = MaintenanceType.breakdown
      ..description = description
      ..plantConditionEffect = effect
      ..routedTo = RoutedTo.mechanical
      ..status = resolved ? TicketStatus.resolved : TicketStatus.open
      ..isResolved = resolved
      ..startDate = _time
      ..createdAt = _time
      ..updatedAt = _time
      ..loggedByUid = 'operator-1'
      ..loggedByName = 'Operator One';

MaintenanceRecord administrativelyClosedIssueCondition({
  required String id,
  required AssetInstanceRecord asset,
  required MaintenanceIssuePlantConditionEffect effect,
  required IssueAdministrativeClosureDisposition disposition,
}) {
  final record = issueCondition(
    id: id,
    asset: asset,
    effect: effect,
    resolved: true,
    synced: true,
  );
  record
    ..status = TicketStatus.closedWithoutResolution
    ..endDate = _time.add(const Duration(hours: 1))
    ..closedByUid = 'admin-1'
    ..closedByName = 'Admin One'
    ..administrativeClosure = IssueAdministrativeClosure(
      disposition: disposition,
      reason: 'Administrative closure after plant review.',
    );
  return record;
}

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

  test('open maintenance issue derives unfit state and visible provenance', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'furnace',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace7 = asset(id: 'furnace-7', assetClass: furnace, number: 7);
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace],
      assetInstances: [furnace7],
      operationalConditions: const [],
      workflowStatuses: const [],
      maintenanceTickets: [
        issueCondition(
          id: 'ticket-plant-1',
          asset: furnace7,
          effect: MaintenanceIssuePlantConditionEffect.unfit,
        ),
      ],
    );

    final state = overview.assets.single;
    expect(state.isUnfit, isTrue);
    expect(state.isManuallyUnfit, isFalse);
    expect(state.isAvailable, isFalse);
    expect(
      state.issueConditionContributions.single.comment,
      contains('Unfit due to maintenance issue'),
    );
    expect(
      state.issueConditionContributions.single.comment,
      contains('Cooling-water leakage requires repair'),
    );
  });

  test('manual down remains authoritative over open issue unfit evidence', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'furnace',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace12 = asset(id: 'furnace-12', assetClass: furnace, number: 12);
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace],
      assetInstances: [furnace12],
      operationalConditions: [
        condition(asset: furnace12, condition: AssetOperationalCondition.down),
      ],
      workflowStatuses: const [],
      maintenanceTickets: [
        issueCondition(
          id: 'ticket-open-unfit',
          asset: furnace12,
          effect: MaintenanceIssuePlantConditionEffect.unfit,
        ),
      ],
    );

    final state = overview.assets.single;
    expect(state.isDown, isTrue);
    expect(state.hasIssueUnfitEvidence, isTrue);
    expect(state.isIssueUnfit, isFalse);
    expect(state.isUnfit, isFalse);
    expect(state.issueConditionContributions, hasLength(1));
    expect(overview.down, 1);
    expect(overview.unfit, 0);
  });

  test(
    'manual unfit remains authoritative over issue unavailable evidence',
    () {
      final base = assetClass(
        id: 'base-class',
        code: 'base',
        name: 'Base',
        legacyKey: 'base',
      );
      final base201 = asset(id: 'base-201', assetClass: base, number: 201);
      final overview = PlantAssetOverview.build(
        assetClasses: [base],
        assetInstances: [base201],
        operationalConditions: [
          condition(asset: base201, condition: AssetOperationalCondition.unfit),
        ],
        workflowStatuses: const [],
        maintenanceTickets: [
          issueCondition(
            id: 'ticket-open-unavailable',
            asset: base201,
            effect: MaintenanceIssuePlantConditionEffect.unavailable,
          ),
        ],
      );

      final state = overview.assets.single;
      expect(state.isManuallyUnfit, isTrue);
      expect(state.hasIssueUnavailableEvidence, isTrue);
      expect(state.isIssueUnavailable, isFalse);
      expect(state.isUnfit, isTrue);
      expect(state.issueConditionContributions, hasLength(1));
      expect(overview.issueUnavailable, 0);
      expect(overview.unfit, 1);
    },
  );

  test('issue unavailable supersedes issue-default unfit', () {
    final base = assetClass(
      id: 'base-class',
      code: 'base',
      name: 'Base',
      legacyKey: 'base',
    );
    final base201 = asset(id: 'base-201', assetClass: base, number: 201);
    final overview = PlantAssetOverview.build(
      assetClasses: [base],
      assetInstances: [base201],
      operationalConditions: const [],
      workflowStatuses: const [],
      maintenanceTickets: [
        issueCondition(
          id: 'ticket-open-unfit',
          asset: base201,
          effect: MaintenanceIssuePlantConditionEffect.unfit,
        ),
        issueCondition(
          id: 'ticket-open-unavailable',
          asset: base201,
          effect: MaintenanceIssuePlantConditionEffect.unavailable,
        ),
      ],
    );

    final state = overview.assets.single;
    expect(state.hasIssueUnfitEvidence, isTrue);
    expect(state.hasIssueUnavailableEvidence, isTrue);
    expect(state.isIssueUnavailable, isTrue);
    expect(state.isIssueUnfit, isFalse);
    expect(state.isUnfit, isFalse);
    expect(state.issueConditionContributions, hasLength(2));
    expect(overview.issueUnavailable, 1);
    expect(overview.unfit, 0);
  });

  test('issue unavailable is distinct and survives an unsynced closure', () {
    final base = assetClass(
      id: 'base-class',
      code: 'base',
      name: 'Base',
      legacyKey: 'base',
    );
    final base201 = asset(id: 'base-201', assetClass: base, number: 201);
    final pendingClosure = issueCondition(
      id: 'ticket-pending-close',
      asset: base201,
      effect: MaintenanceIssuePlantConditionEffect.unavailable,
      resolved: true,
      synced: false,
    );
    final overview = PlantAssetOverview.build(
      assetClasses: [base],
      assetInstances: [base201],
      operationalConditions: const [],
      workflowStatuses: const [],
      maintenanceTickets: [pendingClosure],
    );

    final state = overview.assets.single;
    expect(state.isIssueUnavailable, isTrue);
    expect(state.isUnfit, isFalse);
    expect(state.isAvailable, isFalse);
    expect(
      state.issueConditionContributions.single.awaitingServerClosure,
      isTrue,
    );
    expect(
      state.issueConditionContributions.single.comment,
      contains('awaiting server confirmation'),
    );
  });

  test(
    'still-relevant administrative closure preserves only its Plant Condition effect',
    () {
      final base = assetClass(
        id: 'base-class',
        code: 'base',
        name: 'Base',
        legacyKey: 'base',
      );
      final relevantBase = asset(id: 'base-201', assetClass: base, number: 201);
      final irrelevantBase = asset(
        id: 'base-202',
        assetClass: base,
        number: 202,
      );
      final resolvedBase = asset(id: 'base-203', assetClass: base, number: 203);
      final overview = PlantAssetOverview.build(
        assetClasses: [base],
        assetInstances: [relevantBase, irrelevantBase, resolvedBase],
        operationalConditions: const [],
        workflowStatuses: const [],
        maintenanceTickets: [
          administrativelyClosedIssueCondition(
            id: 'ticket-still-relevant',
            asset: relevantBase,
            effect: MaintenanceIssuePlantConditionEffect.unavailable,
            disposition: IssueAdministrativeClosureDisposition.stillRelevant,
          ),
          administrativelyClosedIssueCondition(
            id: 'ticket-relevance-ended',
            asset: irrelevantBase,
            effect: MaintenanceIssuePlantConditionEffect.unavailable,
            disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
          ),
          issueCondition(
            id: 'ticket-resolved',
            asset: resolvedBase,
            effect: MaintenanceIssuePlantConditionEffect.unavailable,
            resolved: true,
            synced: true,
          ),
        ],
      );

      final statesByNumber = {
        for (final state in overview.assets) state.asset.assetNumber: state,
      };
      expect(statesByNumber[201]!.isIssueUnavailable, isTrue);
      expect(statesByNumber[201]!.issueConditionContributions, hasLength(1));
      expect(statesByNumber[202]!.isAvailable, isTrue);
      expect(statesByNumber[202]!.issueConditionContributions, isEmpty);
      expect(statesByNumber[203]!.isAvailable, isTrue);
      expect(statesByNumber[203]!.issueConditionContributions, isEmpty);
    },
  );

  test(
    'server-confirmed issue closure preserves an independent manual state',
    () {
      final furnace = assetClass(
        id: 'furnace-class',
        code: 'furnace',
        name: 'Furnace',
        legacyKey: 'furnace',
      );
      final furnace8 = asset(id: 'furnace-8', assetClass: furnace, number: 8);
      final overview = PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: [furnace8],
        operationalConditions: [
          condition(asset: furnace8, condition: AssetOperationalCondition.down),
        ],
        workflowStatuses: const [],
        maintenanceTickets: [
          issueCondition(
            id: 'ticket-closed',
            asset: furnace8,
            effect: MaintenanceIssuePlantConditionEffect.unfit,
            resolved: true,
            synced: true,
          ),
        ],
      );

      final state = overview.assets.single;
      expect(state.isDown, isTrue);
      expect(state.isUnfit, isFalse);
      expect(state.issueConditionContributions, isEmpty);
      expect(state.isAvailable, isFalse);
    },
  );

  test('issue evidence remains visible beneath a manual condition', () {
    final base = assetClass(
      id: 'base-class',
      code: 'base',
      name: 'Base',
      legacyKey: 'base',
    );
    final base201 = asset(id: 'base-201', assetClass: base, number: 201);
    final remainingIssue = issueCondition(
      id: 'ticket-unavailable',
      asset: base201,
      effect: MaintenanceIssuePlantConditionEffect.unavailable,
      description: 'Inner cover is unavailable',
    );
    final resolvedIssue = issueCondition(
      id: 'ticket-unfit',
      asset: base201,
      effect: MaintenanceIssuePlantConditionEffect.unfit,
      description: 'Base fan motor needs repair',
      resolved: true,
      synced: true,
    );
    final overview = PlantAssetOverview.build(
      assetClasses: [base],
      assetInstances: [base201],
      operationalConditions: [
        condition(asset: base201, condition: AssetOperationalCondition.unfit),
      ],
      workflowStatuses: const [],
      maintenanceTickets: [resolvedIssue, remainingIssue],
    );

    final state = overview.assets.single;
    expect(state.isManuallyUnfit, isTrue);
    expect(state.hasIssueUnavailableEvidence, isTrue);
    expect(state.isIssueUnavailable, isFalse);
    expect(state.issueConditionContributions, hasLength(1));
    expect(
      state.issueConditionContributions.single.comment,
      'Unavailable due to maintenance issue ticket-u: Inner cover is unavailable.',
    );
    expect(state.isAvailable, isFalse);
  });

  test('stuck-up ticket remains represented by its specialized projection', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'furnace',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace8 = asset(id: 'furnace-8', assetClass: furnace, number: 8);
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace],
      assetInstances: [furnace8],
      operationalConditions: const [],
      workflowStatuses: const [],
      availabilityProjections: [blocked(asset: furnace8)],
      maintenanceTickets: [
        issueCondition(
          id: 'ticket-stuck-up',
          asset: furnace8,
          effect: MaintenanceIssuePlantConditionEffect.stuckUp,
        ),
      ],
    );

    final state = overview.assets.single;
    expect(state.isTemporarilyBlocked, isTrue);
    expect(state.issueConditionContributions, isEmpty);
    expect(state.isAvailable, isFalse);
  });

  test('stuck-up remains exclusive while retaining other issue evidence', () {
    final furnace = assetClass(
      id: 'furnace-class',
      code: 'furnace',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final furnace8 = asset(id: 'furnace-8', assetClass: furnace, number: 8);
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace],
      assetInstances: [furnace8],
      operationalConditions: const [],
      workflowStatuses: const [],
      availabilityProjections: [blocked(asset: furnace8)],
      maintenanceTickets: [
        issueCondition(
          id: 'ticket-stuck-up',
          asset: furnace8,
          effect: MaintenanceIssuePlantConditionEffect.stuckUp,
        ),
        issueCondition(
          id: 'ticket-unavailable',
          asset: furnace8,
          effect: MaintenanceIssuePlantConditionEffect.unavailable,
        ),
        issueCondition(
          id: 'ticket-unfit',
          asset: furnace8,
          effect: MaintenanceIssuePlantConditionEffect.unfit,
        ),
      ],
    );

    final state = overview.assets.single;
    expect(state.isTemporarilyBlocked, isTrue);
    expect(state.hasIssueUnavailableEvidence, isTrue);
    expect(state.hasIssueUnfitEvidence, isTrue);
    expect(state.issueConditionContributions, hasLength(2));
    expect(state.isIssueUnavailable, isFalse);
    expect(state.isIssueUnfit, isFalse);
    expect(overview.temporarilyBlocked, 1);
    expect(overview.issueUnavailable, 0);
    expect(overview.unfit, 0);
  });
}
