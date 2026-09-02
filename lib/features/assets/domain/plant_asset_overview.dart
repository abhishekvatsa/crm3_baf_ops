import '../../maintenance_workflow/data/equipment_status_record.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/asset_availability_record.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';

class PlantIssueConditionContribution {
  final String ticketId;
  final MaintenanceIssuePlantConditionEffect effect;
  final String description;
  final DateTime startedAt;
  final String? raisedByName;
  final bool awaitingServerClosure;

  const PlantIssueConditionContribution({
    required this.ticketId,
    required this.effect,
    required this.description,
    required this.startedAt,
    required this.raisedByName,
    required this.awaitingServerClosure,
  });

  String get comment {
    final source = ticketId.length <= 8 ? ticketId : ticketId.substring(0, 8);
    final detail = description.trim();
    final reason = detail.endsWith('.') ? detail : '$detail.';
    final pending =
        awaitingServerClosure
            ? ' Closure is awaiting server confirmation.'
            : '';
    return '${effect.label} due to maintenance issue $source: $reason$pending';
  }
}

class PlantAssetState {
  final AssetInstanceRecord asset;
  final AssetOperationalConditionRecord? operationalCondition;
  final AssetAvailabilityRecord? availability;
  final EquipmentStatusRecord? workflowStatus;
  final List<PlantIssueConditionContribution> issueConditionContributions;

  const PlantAssetState({
    required this.asset,
    required this.operationalCondition,
    required this.availability,
    required this.workflowStatus,
    this.issueConditionContributions = const [],
  });

  bool get isUnderMaintenance =>
      workflowStatus != null &&
      (workflowStatus!.openMaintenanceCount > 0 ||
          workflowStatus!.openRedCount > 0 ||
          workflowStatus!.awaitingPreparationCount > 0);

  bool get isDown =>
      operationalCondition?.active == true &&
      operationalCondition?.condition == AssetOperationalCondition.down;

  bool get isManuallyUnfit =>
      operationalCondition?.active == true &&
      operationalCondition?.condition == AssetOperationalCondition.unfit;

  bool get hasIssueUnfitEvidence => issueConditionContributions.any(
    (item) => item.effect == MaintenanceIssuePlantConditionEffect.unfit,
  );

  bool get hasIssueUnavailableEvidence => issueConditionContributions.any(
    (item) => item.effect == MaintenanceIssuePlantConditionEffect.unavailable,
  );

  bool get hasActiveManualCondition => isDown || isManuallyUnfit;

  // Manual and stuck-up declarations remain authoritative; lower-priority issue
  // evidence is retained without double-counting the asset in summary states.
  bool get isIssueUnavailable =>
      !hasActiveManualCondition &&
      !isTemporarilyBlocked &&
      hasIssueUnavailableEvidence;

  bool get isIssueUnfit =>
      !hasActiveManualCondition &&
      !isTemporarilyBlocked &&
      !hasIssueUnavailableEvidence &&
      hasIssueUnfitEvidence;

  bool get isUnfit => isManuallyUnfit || isIssueUnfit;

  bool get isTemporarilyBlocked => availability?.isTemporarilyBlocked == true;

  bool get isStandby => asset.serviceState == AssetServiceState.standby;

  bool get isAdministrativelyOutOfService =>
      asset.serviceState == AssetServiceState.outOfService;

  bool get isAvailable =>
      asset.isActive &&
      asset.serviceState == AssetServiceState.inService &&
      !isUnderMaintenance &&
      !isDown &&
      !isUnfit &&
      !isIssueUnavailable &&
      !isTemporarilyBlocked;
}

class PlantAssetClassSummary {
  final AssetClassRecord assetClass;
  final List<PlantAssetState> assets;

  const PlantAssetClassSummary({
    required this.assetClass,
    required this.assets,
  });

  int get total => assets.length;
  int get available => assets.where((asset) => asset.isAvailable).length;
  int get underMaintenance =>
      assets.where((asset) => asset.isUnderMaintenance).length;
  int get down => assets.where((asset) => asset.isDown).length;
  int get unfit => assets.where((asset) => asset.isUnfit).length;
  int get issueUnavailable =>
      assets.where((asset) => asset.isIssueUnavailable).length;
  int get temporarilyBlocked =>
      assets.where((asset) => asset.isTemporarilyBlocked).length;
  int get standby => assets.where((asset) => asset.isStandby).length;
  int get outOfService =>
      assets.where((asset) => asset.isAdministrativelyOutOfService).length;
  int get attention =>
      assets
          .where(
            (asset) =>
                asset.isDown ||
                asset.isUnfit ||
                asset.isIssueUnavailable ||
                asset.isTemporarilyBlocked ||
                asset.isUnderMaintenance ||
                asset.isAdministrativelyOutOfService,
          )
          .length;
}

class PlantAssetOverview {
  final List<PlantAssetClassSummary> classes;
  final List<PlantAssetState> assets;

  const PlantAssetOverview({required this.classes, required this.assets});

  int get total => assets.length;
  int get available => assets.where((asset) => asset.isAvailable).length;
  int get underMaintenance =>
      assets.where((asset) => asset.isUnderMaintenance).length;
  int get down => assets.where((asset) => asset.isDown).length;
  int get unfit => assets.where((asset) => asset.isUnfit).length;
  int get issueUnavailable =>
      assets.where((asset) => asset.isIssueUnavailable).length;
  int get temporarilyBlocked =>
      assets.where((asset) => asset.isTemporarilyBlocked).length;
  int get standby => assets.where((asset) => asset.isStandby).length;
  int get outOfService =>
      assets.where((asset) => asset.isAdministrativelyOutOfService).length;

  factory PlantAssetOverview.build({
    required List<AssetClassRecord> assetClasses,
    required List<AssetInstanceRecord> assetInstances,
    required List<AssetOperationalConditionRecord> operationalConditions,
    required List<EquipmentStatusRecord> workflowStatuses,
    List<AssetAvailabilityRecord> availabilityProjections = const [],
    List<MaintenanceRecord> maintenanceTickets = const [],
  }) {
    final classesById = <String, AssetClassRecord>{};
    for (final assetClass in assetClasses.where((item) => item.isActive)) {
      if (classesById.containsKey(assetClass.id)) {
        throw StateError('Duplicate governed asset class ${assetClass.id}.');
      }
      classesById[assetClass.id] = assetClass;
    }

    final conditionsByAssetId = <String, AssetOperationalConditionRecord>{};
    for (final condition in operationalConditions) {
      if (conditionsByAssetId.containsKey(condition.assetInstanceId)) {
        throw StateError(
          'Duplicate operational condition for ${condition.assetInstanceId}.',
        );
      }
      conditionsByAssetId[condition.assetInstanceId] = condition;
    }

    final workflowByKey = <String, EquipmentStatusRecord>{};
    for (final status in workflowStatuses) {
      final key = status.projectionIdentityKey;
      if (workflowByKey.containsKey(key)) {
        throw StateError('Duplicate workflow projection for $key.');
      }
      workflowByKey[key] = status;
    }

    final availabilityByAssetId = <String, AssetAvailabilityRecord>{};
    for (final projection in availabilityProjections) {
      if (availabilityByAssetId.containsKey(projection.assetInstanceId)) {
        throw StateError(
          'Duplicate availability projection for ${projection.assetInstanceId}.',
        );
      }
      availabilityByAssetId[projection.assetInstanceId] = projection;
    }

    final activeAssetsById = <String, AssetInstanceRecord>{};
    for (final asset in assetInstances.where((item) => item.isActive)) {
      if (activeAssetsById.containsKey(asset.id)) {
        throw StateError('Duplicate governed asset ${asset.id}.');
      }
      activeAssetsById[asset.id] = asset;
    }
    final issueConditionsByAssetId =
        <String, List<PlantIssueConditionContribution>>{};
    for (final ticket in maintenanceTickets) {
      final effect = ticket.effectivePlantConditionEffect;
      if (!ticket.canStillAffectPlantCondition ||
          effect == MaintenanceIssuePlantConditionEffect.none ||
          effect == MaintenanceIssuePlantConditionEffect.stuckUp) {
        continue;
      }
      final ticketId = ticket.firestoreId?.trim();
      final reference = ticket.assetHierarchyReference;
      if (ticketId == null ||
          ticketId.isEmpty ||
          reference == null ||
          reference.scope == AssetHierarchyReferenceScope.definition ||
          reference.assetInstanceId == null) {
        throw StateError(
          'Issue-derived Plant Condition evidence lacks an exact asset identity.',
        );
      }
      final asset = activeAssetsById[reference.assetInstanceId];
      if (asset == null ||
          reference.assetClassId != asset.assetClassId ||
          reference.assetNumber != asset.assetNumber) {
        throw StateError(
          'Issue-derived Plant Condition evidence for $ticketId disagrees with the asset registry.',
        );
      }
      issueConditionsByAssetId
          .putIfAbsent(asset.id, () => <PlantIssueConditionContribution>[])
          .add(
            PlantIssueConditionContribution(
              ticketId: ticketId,
              effect: effect,
              description: ticket.description.trim(),
              startedAt: ticket.startDate,
              raisedByName: ticket.loggedByName?.trim(),
              awaitingServerClosure:
                  (ticket.isResolved || ticket.isDeleted) && !ticket.isSynced,
            ),
          );
    }
    for (final contributions in issueConditionsByAssetId.values) {
      contributions.sort(
        (left, right) => right.startedAt.compareTo(left.startedAt),
      );
    }

    final states = <PlantAssetState>[];
    for (final asset in assetInstances.where((item) => item.isActive)) {
      final assetClass = classesById[asset.assetClassId];
      if (assetClass == null || asset.assetClassCode != assetClass.code) {
        throw StateError(
          'Asset ${asset.id} disagrees with its governed asset class.',
        );
      }
      final condition = conditionsByAssetId[asset.id];
      if (condition != null &&
          (condition.assetClassId != asset.assetClassId ||
              condition.assetClassCode != asset.assetClassCode ||
              condition.assetNumber != asset.assetNumber)) {
        throw StateError(
          'Operational condition for ${asset.id} disagrees with the asset registry.',
        );
      }
      final legacyKey = assetClass.legacyAssetTypeKey;
      final availability = availabilityByAssetId[asset.id];
      if (availability != null &&
          (availability.assetClassId != asset.assetClassId ||
              availability.assetNumber != asset.assetNumber)) {
        throw StateError(
          'Availability projection for ${asset.id} disagrees with the asset registry.',
        );
      }
      states.add(
        PlantAssetState(
          asset: asset,
          operationalCondition: condition,
          availability: availability,
          workflowStatus:
              legacyKey == null
                  ? workflowByKey['governedCustom:${asset.assetClassId}:${asset.id}']
                  : workflowByKey['$legacyKey:${asset.assetNumber}'],
          issueConditionContributions: List.unmodifiable(
            issueConditionsByAssetId[asset.id] ?? const [],
          ),
        ),
      );
    }
    states.sort((left, right) {
      final classOrder = left.asset.assetClassName.toLowerCase().compareTo(
        right.asset.assetClassName.toLowerCase(),
      );
      return classOrder != 0
          ? classOrder
          : left.asset.assetNumber.compareTo(right.asset.assetNumber);
    });

    final summaries =
        classesById.values.map((assetClass) {
            return PlantAssetClassSummary(
              assetClass: assetClass,
              assets: List<PlantAssetState>.unmodifiable(
                states.where(
                  (state) => state.asset.assetClassId == assetClass.id,
                ),
              ),
            );
          }).toList()
          ..sort((left, right) {
            final areaOrder = left.assetClass.majorArea.toLowerCase().compareTo(
              right.assetClass.majorArea.toLowerCase(),
            );
            return areaOrder != 0
                ? areaOrder
                : left.assetClass.name.toLowerCase().compareTo(
                  right.assetClass.name.toLowerCase(),
                );
          });

    return PlantAssetOverview(
      classes: List<PlantAssetClassSummary>.unmodifiable(summaries),
      assets: List<PlantAssetState>.unmodifiable(states),
    );
  }
}
