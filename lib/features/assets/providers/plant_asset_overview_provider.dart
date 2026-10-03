import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../data/inner_cover_workflow_evidence.dart';
import '../domain/inner_cover_dependencies.dart';
import '../domain/apply_inner_cover_dependencies.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/remote_maintenance_reader.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import '../data/asset_availability_record.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../data/plant_condition_evidence.dart';
import '../data/inner_cover_lifecycle.dart';
import '../domain/physical_plant_inventory.dart';
import '../domain/plant_asset_overview.dart';
import '../domain/qualified_plant_asset_overview.dart';
import '../domain/base_cover_reconciliation.dart';
import '../../reports/domain/base_inner_cover_register.dart';
import 'asset_hierarchy_provider.dart';
import 'furnace_stuckup_provider.dart';
import '../domain/inner_cover_stock_summary.dart';

AutoDisposeStreamProvider<PlantEvidenceBatch<T>> _source<T>(
  String collection,
  T Function(Map<String, dynamic>, String) decode,
) => StreamProvider.autoDispose((ref) {
  final actor = ref.watch(currentAppUserProvider).asData?.value;
  if (actor?.isApproved != true) {
    throw StateError('Approved plant-condition access is required.');
  }
  return watchPlantEvidence(FirebaseFirestore.instance, collection, decode);
});

final plantClassEvidenceProvider = _source(
  'asset_classes',
  AssetClassRecord.fromMap,
);
final plantAssetEvidenceProvider = _source(
  'asset_instances',
  AssetInstanceRecord.fromMap,
);
final plantManualEvidenceProvider = _source(
  'asset_operational_conditions',
  AssetOperationalConditionRecord.fromMap,
);
final plantAvailabilityEvidenceProvider = _source(
  'asset_availability_current',
  AssetAvailabilityRecord.fromMap,
);
final plantWorkflowEvidenceProvider = _source(
  'equipment_status',
  (data, id) =>
      equipmentStatusRecordFromFirestoreData(documentId: id, data: data),
);
final plantTicketEvidenceProvider = _source(
  'maintenance_records',
  (data, id) => readRemoteMaintenanceRecord(data, documentId: id),
);
final plantInnerCoverEvidenceProvider = _source(
  'inner_cover_profiles',
  InnerCoverProfile.fromMap,
);
final plantInnerCoverWorkflowEvidenceProvider = _source(
  'maintenance_workflows',
  InnerCoverWorkflowEvidence.fromMap,
);
final plantInnerCoverExecutionEvidenceProvider = _source(
  'job_executions',
  JobExecution.fromMap,
);

// Delinking legitimately deletes an assignment and removes the active linkage
// from the query. Decode each current snapshot rather than retaining deleted rows.
final plantCoverAssignmentEvidenceProvider =
    StreamProvider.autoDispose<DecodedSnapshotBatch<BaseInnerCoverAssignment>>((
      ref,
    ) {
      if (ref.watch(currentAppUserProvider).asData?.value?.isApproved != true) {
        throw StateError('Approved plant-condition access is required.');
      }
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverAssignmentBatches();
    });

final plantActiveCoverLinkEvidenceProvider =
    StreamProvider.autoDispose<DecodedSnapshotBatch<InnerCoverLinkage>>((ref) {
      if (ref.watch(currentAppUserProvider).asData?.value?.isApproved != true) {
        throw StateError('Approved plant-condition access is required.');
      }
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchActiveInnerCoverLinkages();
    });

DecodedSnapshotBatch<T> _registerBatch<T>(
  AsyncValue<PlantEvidenceBatch<T>> value,
) {
  final batch = value.asData?.value;
  return DecodedSnapshotBatch(
    records: batch?.rows ?? [],
    rejectedDocumentIds: batch?.rejected.keys.toList() ?? [],
    isFromCache: batch?.fromServer != true,
  );
}

DecodedSnapshotBatch<T> _currentBatch<T>(
  AsyncValue<DecodedSnapshotBatch<T>> value,
) =>
    value.asData?.value ??
    const DecodedSnapshotBatch(
      records: [],
      rejectedDocumentIds: [],
      isFromCache: true,
    );

final plantAssetOverviewProvider = Provider<AsyncValue<PlantAssetOverview>>((
  ref,
) {
  final classes = ref.watch(plantClassEvidenceProvider);
  final assets = ref.watch(plantAssetEvidenceProvider);
  final conditions = ref.watch(plantManualEvidenceProvider);
  final workflow = ref.watch(plantWorkflowEvidenceProvider);
  final availability = ref.watch(plantAvailabilityEvidenceProvider);
  final tickets = ref.watch(plantTicketEvidenceProvider);
  final covers = ref.watch(plantInnerCoverEvidenceProvider);
  final localTickets = ref.watch(plantConditionTicketsProvider);
  if (classes.isLoading || assets.isLoading) return const AsyncLoading();
  if (classes.hasError || assets.hasError) {
    final error = classes.asError ?? assets.asError!;
    return AsyncError(error.error, error.stackTrace);
  }
  final warnings = <String>[];
  final unverifiedSources = <String>[];
  void qualify<T>(String name, AsyncValue<PlantEvidenceBatch<T>> value) {
    final batch = value.asData?.value;
    if (batch == null) {
      warnings.add('$name evidence is unavailable or still loading.');
      unverifiedSources.add(warnings.last);
      return;
    }
    if (!batch.fromServer) {
      warnings.add(
        '$name is last-known evidence; current server state is unconfirmed.',
      );
      unverifiedSources.add(warnings.last);
    }
    for (final entry in batch.rejected.entries) {
      warnings.add('$name ${entry.key}: ${entry.value}');
    }
  }

  qualify('Register classes', classes);
  qualify('Registered assets', assets);
  qualify('Manual restrictions', conditions);
  qualify('Workflow', workflow);
  qualify('Specialized availability', availability);
  qualify('Issues', tickets);
  if (localTickets.hasError || localTickets.isLoading) {
    warnings.add('Local pending issue evidence is not yet verified.');
    unverifiedSources.add(warnings.last);
  }
  final overview = qualifiedPlantAssetOverview(
    classes: classes.requireValue.rows,
    assets: assets.requireValue.rows,
    conditions: conditions.asData?.value.rows ?? [],
    workflow: workflow.asData?.value.rows ?? [],
    availability: availability.asData?.value.rows ?? [],
    tickets: [
      ...?tickets.asData?.value.rows,
      ...?localTickets.asData?.value.where((row) => !row.isSynced),
    ],
    populationWarnings: warnings,
    physicalInventoryComplete:
        classes.requireValue.complete && assets.requireValue.complete,
    unverifiedSources: unverifiedSources,
    manualSourcesCurrent:
        classes.requireValue.fromServer &&
        assets.requireValue.fromServer &&
        conditions.asData?.value.fromServer == true,
    rejectedConditions: conditions.asData?.value.rejected.keys.toSet() ?? {},
    rejectedAssets: assets.requireValue.rejected.keys.toSet(),
    rejectedClasses: classes.requireValue.rejected.keys.toSet(),
    rejectedWorkflow: workflow.asData?.value.rejected.keys.toSet() ?? {},
    rejectedAvailability:
        availability.asData?.value.rejected.keys.toSet() ?? {},
    rejectedTickets: tickets.asData?.value.rejected.keys.toSet() ?? {},
  );
  final coverWarnings = <String>[
    if (covers.asData?.value.fromServer != true)
      'Inner Cover inventory is incomplete or last-known; current server state is unconfirmed.',
    if (!classes.requireValue.fromServer)
      'Inner Cover class evidence is last-known; current server state is unconfirmed.',
  ];
  final coverPopulationWarnings = <String>[
    for (final entry
        in covers.asData?.value.rejected.entries ??
            <MapEntry<String, String>>[])
      'Inner Cover ${entry.key}: ${entry.value}',
  ];
  final activeBaseIds = overview.assets
      .where(
        (state) => classes.requireValue.rows.any(
          (cls) =>
              cls.isActive &&
              cls.legacyAssetTypeKey == 'base' &&
              cls.id == state.asset.assetClassId,
        ),
      )
      .map((state) => state.asset.id)
      .toSet();
  final hasCoverPopulation =
      classes.requireValue.rows.any(
        (c) => c.legacyAssetTypeKey == 'innerCover',
      ) ||
      covers.asData?.value.rows.isNotEmpty == true;
  final needsLinkEvidence = activeBaseIds.isNotEmpty || hasCoverPopulation;
  final assignments = !needsLinkEvidence
      ? const AsyncData<DecodedSnapshotBatch<BaseInnerCoverAssignment>>(
          DecodedSnapshotBatch(records: [], rejectedDocumentIds: []),
        )
      : ref.watch(plantCoverAssignmentEvidenceProvider);
  final links = !needsLinkEvidence
      ? const AsyncData<DecodedSnapshotBatch<InnerCoverLinkage>>(
          DecodedSnapshotBatch(records: [], rejectedDocumentIds: []),
        )
      : ref.watch(plantActiveCoverLinkEvidenceProvider);
  final register = buildBaseInnerCoverRegister(
    classes: _registerBatch(classes),
    assets: _registerBatch(assets),
    assignments: _currentBatch(assignments),
    covers: _registerBatch(covers),
    linkages: _currentBatch(links),
  );
  final stock = hasCoverPopulation
      ? buildInnerCoverStockSummary(
          classes: _registerBatch(classes),
          profiles: _registerBatch(covers),
          assignments: _currentBatch(assignments),
          links: _currentBatch(links),
          register: register,
          cases: _currentBatch(ref.watch(furnaceStuckupCaseBatchProvider)),
          declarations: _currentBatch(
            ref.watch(innerCoverBulgeDeclarationBatchProvider),
          ),
        )
      : null;
  final physical = physicalPlantInventory(
    overview: overview,
    classes: classes.requireValue.rows,
    profiles: covers.asData?.value.rows ?? [],
    coverSourceWarnings: coverWarnings,
    coverPopulationWarnings: coverPopulationWarnings,
    rejectedProfiles: covers.asData?.value.rejected.keys.toSet() ?? {},
    rejectedClasses: classes.requireValue.rejected.keys.toSet(),
    innerCoverStock: stock,
    baseCoverReconciliation: reconcileBaseCoverRegister(
      register: register,
      activeBaseIds: activeBaseIds,
      verifiedConditionBaseIds: conditions.asData?.value.complete == true
          ? overview.assets
                .where((state) => state.permitsManualChange)
                .map((state) => state.asset.id)
                .toSet()
          : {},
      downBaseIds: overview.assets
          .where((state) => state.isDown)
          .map((state) => state.asset.id)
          .toSet(),
    ),
  );
  if (!hasCoverPopulation) return AsyncData(physical);
  final remoteTickets = _registerBatch(tickets);
  final dependencies = deriveInnerCoverDependencies(
    stuckupCases: _currentBatch(ref.watch(furnaceStuckupCaseBatchProvider)),
    profiles: _registerBatch(covers),
    tickets: DecodedSnapshotBatch(
      records: [
        ...remoteTickets.records,
        ...?localTickets.asData?.value.where((row) => !row.isSynced),
      ],
      rejectedDocumentIds: [
        ...remoteTickets.rejectedDocumentIds,
        if (localTickets.isLoading || localTickets.hasError)
          'local-pending-issue-evidence-unavailable',
      ],
      isFromCache: !remoteTickets.isServerConfirmed,
    ),
    workflows: _registerBatch(
      ref.watch(plantInnerCoverWorkflowEvidenceProvider),
    ),
    executions: _registerBatch(
      ref.watch(plantInnerCoverExecutionEvidenceProvider),
    ),
  );
  return AsyncData(
    applyInnerCoverDependencies(
      overview: physical,
      register: register,
      dependencies: qualifyInnerCoverDependencyProjections(
        dependencies,
        _registerBatch(workflow),
      ),
    ),
  );
});
