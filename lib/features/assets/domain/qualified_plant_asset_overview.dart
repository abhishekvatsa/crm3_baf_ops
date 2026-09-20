import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/data/equipment_status_record.dart';
import '../data/asset_availability_record.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import 'plant_asset_overview.dart';

PlantAssetOverview qualifiedPlantAssetOverview({
  required List<AssetClassRecord> classes,
  required List<AssetInstanceRecord> assets,
  required List<AssetOperationalConditionRecord> conditions,
  required List<EquipmentStatusRecord> workflow,
  required List<AssetAvailabilityRecord> availability,
  required List<MaintenanceRecord> tickets,
  required List<String> populationWarnings,
  required bool manualSourcesCurrent,
  Set<String> rejectedConditions = const {},
  Set<String> rejectedAssets = const {},
  Set<String> rejectedClasses = const {},
}) {
  final warnings = [...populationWarnings];
  final activeIds = assets.where((a) => a.isActive).map((a) => a.id).toSet();
  final registeredIds = assets.map((a) => a.id).toSet();
  for (final id in {
    ...conditions.map((r) => r.assetInstanceId),
    ...availability.map((r) => r.assetInstanceId),
    ...workflow.map((r) => r.assetInstanceId).whereType<String>(),
  }) {
    if (!registeredIds.contains(id)) {
      warnings.add(
        'Condition evidence refers to unverified registered asset $id.',
      );
    }
  }
  final byAsset = <String, List<MaintenanceRecord>>{};
  for (final ticket in tickets) {
    try {
      if (!ticket.canStillAffectPlantCondition) continue;
      final id = ticket.assetHierarchyReference?.assetInstanceId;
      if (id == null || !activeIds.contains(id)) {
        throw StateError(
          'Issue ${ticket.firestoreId} has no verified active physical subject.',
        );
      }
      final rows = byAsset.putIfAbsent(id, () => []);
      // The unsynced local closure is additional adverse evidence, not a
      // second issue. Prefer it over the server row while acceptance is pending.
      final duplicate = rows.indexWhere(
        (r) => r.firestoreId == ticket.firestoreId,
      );
      if (duplicate < 0) {
        rows.add(ticket);
      } else if (!ticket.isSynced) {
        rows[duplicate] = ticket;
      }
    } catch (error) {
      warnings.add(error.toString());
    }
  }
  final states = <PlantAssetState>[];
  for (final asset in assets.where((row) => row.isActive)) {
    final assetClasses = classes
        .where((row) => row.id == asset.assetClassId)
        .toList();
    if (assetClasses.length != 1 || !assetClasses.single.isActive) {
      warnings.add('Asset ${asset.id} has an unreadable or conflicting class.');
      continue;
    }
    final scopedWorkflow = workflow
        .where(
          (row) =>
              row.assetInstanceId == asset.id ||
              (row.assetNumber == asset.assetNumber &&
                  row.assetTypeKey == assetClasses.single.legacyAssetTypeKey),
        )
        .toList();
    try {
      for (final row in scopedWorkflow) {
        if ((row.assetInstanceId != null && row.assetInstanceId != asset.id) ||
            (row.assetClassId != null &&
                row.assetClassId != asset.assetClassId) ||
            (row.assetTypeKey != 'innerCover' &&
                row.assetNumber != asset.assetNumber)) {
          throw StateError(
            'Workflow identity disagrees with the physical register.',
          );
        }
      }
      final verified = PlantAssetOverview.build(
        assetClasses: assetClasses,
        assetInstances: [asset],
        operationalConditions: conditions
            .where((row) => row.assetInstanceId == asset.id)
            .toList(),
        workflowStatuses: scopedWorkflow,
        availabilityProjections: availability
            .where((row) => row.assetInstanceId == asset.id)
            .toList(),
        maintenanceTickets: byAsset[asset.id] ?? [],
      ).assets.single;
      if (verified.workflowStatus == null) {
        warnings.add(
          'Asset ${asset.id}: current workflow evidence is missing.',
        );
      }
      states.add(
        PlantAssetState(
          asset: asset,
          operationalCondition: verified.operationalCondition,
          availability: verified.availability,
          workflowStatus: verified.workflowStatus,
          issueConditionContributions: verified.issueConditionContributions,
          evidenceWarnings: List.unmodifiable(warnings),
          permitsManualChange:
              manualSourcesCurrent &&
              !rejectedConditions.contains(asset.id) &&
              !rejectedAssets.contains(asset.id) &&
              !rejectedClasses.contains(asset.assetClassId),
        ),
      );
    } catch (error) {
      warnings.add('Asset ${asset.id}: $error');
      states.add(
        PlantAssetState(
          asset: asset,
          operationalCondition: null,
          availability: null,
          workflowStatus: null,
          evidenceWarnings: [error.toString()],
          permitsManualChange: false,
        ),
      );
    }
  }
  // A damaged unrelated row qualifies the fleet without hiding verified rows.
  return PlantAssetOverview(
    assets: List.unmodifiable(states),
    classes: [
      for (final cls in classes.where((row) => row.isActive))
        PlantAssetClassSummary(
          assetClass: cls,
          assets: states
              .where((row) => row.asset.assetClassId == cls.id)
              .toList(),
        ),
    ],
    evidenceWarnings: List.unmodifiable(warnings.toSet()),
  );
}
