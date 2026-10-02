import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/data/equipment_status_record.dart';
import '../data/asset_availability_record.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import 'plant_asset_overview.dart';

/// Qualify each physical identity independently. Population warnings describe
/// coverage; only an asset's own evidence (or an unavailable whole feed) changes
/// its condition. Registry order can never change an asset's condition.
PlantAssetOverview qualifiedPlantAssetOverview({
  required List<AssetClassRecord> classes,
  required List<AssetInstanceRecord> assets,
  required List<AssetOperationalConditionRecord> conditions,
  required List<EquipmentStatusRecord> workflow,
  required List<AssetAvailabilityRecord> availability,
  required List<MaintenanceRecord> tickets,
  required List<String> populationWarnings,
  required bool manualSourcesCurrent,
  bool physicalInventoryComplete = true,
  List<String> unverifiedSources = const [],
  Set<String> rejectedConditions = const {},
  Set<String> rejectedAssets = const {},
  Set<String> rejectedClasses = const {},
  Set<String> rejectedWorkflow = const {},
  Set<String> rejectedAvailability = const {},
  Set<String> rejectedTickets = const {},
}) {
  final warnings = [...populationWarnings];
  final assetsById = <String, List<AssetInstanceRecord>>{};
  for (final asset in assets) {
    assetsById.putIfAbsent(asset.id, () => []).add(asset);
  }
  final activeIds = assets.where((a) => a.isActive).map((a) => a.id).toSet();
  for (final id in {
    ...conditions.map((r) => r.assetInstanceId),
    ...availability.map((r) => r.assetInstanceId),
    ...workflow.map((r) => r.assetInstanceId).whereType<String>(),
  }) {
    if (!assetsById.containsKey(id)) {
      warnings.add(
        'Condition evidence refers to unverified registered asset $id.',
      );
    }
  }
  final byAsset = <String, List<MaintenanceRecord>>{};
  final issueWarningsByAsset = <String, List<String>>{};
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
      try {
        var id = ticket.assetHierarchyReference?.assetInstanceId;
        if (id == null) {
          final legacyClasses = classes
              .where((c) => c.legacyAssetTypeKey == ticket.assetType.name)
              .toList();
          final candidates = assets
              .where(
                (a) =>
                    a.assetNumber == ticket.assetNumber &&
                    legacyClasses.any((c) => c.id == a.assetClassId),
              )
              .toList();
          if (legacyClasses.length == 1 && candidates.length == 1) {
            id = candidates.single.id;
          }
        }
        if (id != null && activeIds.contains(id)) {
          issueWarningsByAsset
              .putIfAbsent(id, () => [])
              .add('Issue ${ticket.firestoreId}: $error');
        }
      } catch (_) {
        // An unreadable identity can qualify the population, never be guessed
        // onto another physical asset by its display number.
      }
    }
  }
  final states = <PlantAssetState>[];
  for (final entry in assetsById.entries) {
    if (!entry.value.any((a) => a.isActive)) continue;
    final asset = entry.value.firstWhere((a) => a.isActive);
    final localWarnings = [
      ...unverifiedSources,
      ...?issueWarningsByAsset[asset.id],
    ];
    final assetClasses = classes
        .where((c) => c.id == asset.assetClassId)
        .toList();
    if (assetClasses.length == 1 &&
        assetClasses.single.legacyAssetTypeKey == 'innerCover') {
      continue;
    }
    final validClass =
        assetClasses.length == 1 &&
        assetClasses.single.isActive &&
        assetClasses.single.code == asset.assetClassCode;
    if (!validClass) {
      localWarnings.add(
        'The registered asset class is missing, retired or conflicting.',
      );
    }
    if (entry.value.length != 1 || rejectedAssets.contains(asset.id)) {
      localWarnings.add(
        'The physical registry identity is conflicting or unverified.',
      );
    }
    if (rejectedClasses.contains(asset.assetClassId)) {
      localWarnings.add('The asset class evidence is unverified.');
    }
    if (!manualSourcesCurrent) {
      localWarnings.add('Current manual restrictions are unverified.');
    }
    if (rejectedConditions.contains(asset.id)) {
      localWarnings.add(
        'Manual restriction evidence is conflicting or unverified.',
      );
    }
    if (rejectedAvailability.contains(asset.id)) {
      localWarnings.add(
        'Specialized availability evidence is conflicting or unverified.',
      );
    }

    // Validate each evidence family separately: a corrupt workflow must never
    // erase an independently verified Down, Unfit or stuck-up declaration.
    PlantAssetState? read({
      List<AssetOperationalConditionRecord> manual = const [],
      List<AssetAvailabilityRecord> specialized = const [],
      List<EquipmentStatusRecord> flows = const [],
      List<MaintenanceRecord> issues = const [],
    }) {
      try {
        // A missing class cannot certify availability. Its stored identity still
        // allows independently exact adverse evidence to remain visible.
        final evidenceClass = validClass
            ? assetClasses.single
            : AssetClassRecord(
                id: asset.assetClassId,
                code: asset.assetClassCode,
                name: asset.assetClassName,
                majorArea: '',
                status: AssetHierarchyStatus.active,
                version: 1,
                createdAt: asset.createdAt,
                createdByUid: '',
                updatedAt: asset.updatedAt,
                updatedByUid: '',
                lastMutationId: asset.lastMutationId,
              );
        return PlantAssetOverview.build(
          assetClasses: [evidenceClass],
          assetInstances: [asset],
          operationalConditions: manual,
          availabilityProjections: specialized,
          workflowStatuses: flows,
          maintenanceTickets: issues,
        ).assets.single;
      } catch (error) {
        localWarnings.add(error.toString());
        return null;
      }
    }

    final manualState = read(
      manual: conditions.where((r) => r.assetInstanceId == asset.id).toList(),
    );
    final manual = manualState?.operationalCondition;
    final specialized = read(
      specialized: availability
          .where((r) => r.assetInstanceId == asset.id)
          .toList(),
    )?.availability;
    EquipmentStatusRecord? flow;
    if (validClass && entry.value.length == 1) {
      final legacyKey = assetClasses.single.legacyAssetTypeKey;
      final scoped = <EquipmentStatusRecord>[];
      for (final row in workflow) {
        final exact = row.assetInstanceId != null;
        final typeMatches = row.assetTypeKey == (legacyKey ?? 'governedCustom');
        if (exact) {
          if (row.assetInstanceId != asset.id) continue;
          final linkedCover =
              row.assetTypeKey == 'innerCover' && legacyKey == 'base';
          if (row.assetClassId != asset.assetClassId ||
              (!linkedCover &&
                  (!typeMatches || row.assetNumber != asset.assetNumber))) {
            localWarnings.add(
              'Workflow identity disagrees with the physical register.',
            );
            continue;
          }
        } else {
          if (!typeMatches || row.assetNumber != asset.assetNumber) continue;
          final matchingClasses = classes
              .where((c) => c.legacyAssetTypeKey == legacyKey)
              .toList();
          final candidates = assets
              .where(
                (a) =>
                    a.assetNumber == row.assetNumber &&
                    matchingClasses.any((c) => c.id == a.assetClassId),
              )
              .toList();
          if (matchingClasses.length != 1 ||
              candidates.length != 1 ||
              (row.assetClassId != null &&
                  row.assetClassId != asset.assetClassId)) {
            localWarnings.add(
              'Legacy workflow has no unique physical registry identity.',
            );
            continue;
          }
        }
        if (rejectedWorkflow.contains(row.firestoreId)) {
          localWarnings.add('Workflow evidence is conflicting or unverified.');
        }
        scoped.add(row);
      }
      flow = read(flows: scoped)?.workflowStatus;
    }
    if (flow == null) {
      localWarnings.add('Current workflow evidence is missing or unverified.');
    }
    final contributions = <PlantIssueConditionContribution>[];
    for (final ticket in byAsset[asset.id] ?? <MaintenanceRecord>[]) {
      if (rejectedTickets.contains(ticket.firestoreId)) {
        localWarnings.add(
          'Issue ${ticket.firestoreId} evidence is conflicting or unverified.',
        );
      }
      contributions.addAll(
        read(issues: [ticket])?.issueConditionContributions ?? [],
      );
    }
    final rowWarnings = localWarnings.toSet().toList()..sort();
    warnings.addAll(rowWarnings.map((w) => 'Asset ${asset.id}: $w'));
    states.add(
      PlantAssetState(
        asset: asset,
        operationalCondition: manual,
        availability: specialized,
        workflowStatus: flow,
        issueConditionContributions: List.unmodifiable(contributions),
        evidenceWarnings: List.unmodifiable(rowWarnings),
        permitsManualChange:
            validClass &&
            entry.value.length == 1 &&
            manualSourcesCurrent &&
            manualState != null &&
            !rejectedConditions.contains(asset.id) &&
            !rejectedAssets.contains(asset.id) &&
            !rejectedClasses.contains(asset.assetClassId),
      ),
    );
  }
  states.sort((a, b) => a.asset.id.compareTo(b.asset.id));
  final uniqueClasses = <String, AssetClassRecord>{};
  for (final cls in classes) {
    if (classes.where((c) => c.id == cls.id).length == 1) {
      uniqueClasses[cls.id] = cls;
    }
  }
  // A rejected identity may belong to any class. Do not guess a complete class
  // denominator from the remaining readable records.
  final inventoryComplete =
      physicalInventoryComplete &&
      rejectedAssets.isEmpty &&
      rejectedClasses.isEmpty &&
      uniqueClasses.length == classes.length &&
      assetsById.values.every((rows) => rows.length == 1) &&
      states.every((state) {
        final cls = uniqueClasses[state.asset.assetClassId];
        return cls != null &&
            cls.isActive &&
            cls.code == state.asset.assetClassCode;
      });
  return PlantAssetOverview(
    assets: List.unmodifiable(states),
    physicalInventoryComplete: inventoryComplete,
    classes: [
      for (final cls in uniqueClasses.values)
        if (cls.isActive || states.any((s) => s.asset.assetClassId == cls.id))
          PlantAssetClassSummary(
            assetClass: cls,
            inventoryComplete: inventoryComplete,
            assets: states
                .where((s) => s.asset.assetClassId == cls.id)
                .toList(),
          ),
    ],
    evidenceWarnings: List.unmodifiable(warnings.toSet().toList()..sort()),
  );
}
