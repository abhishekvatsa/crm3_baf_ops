import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/remote_maintenance_reader.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import '../data/asset_availability_record.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../data/plant_condition_evidence.dart';
import '../domain/plant_asset_overview.dart';
import '../domain/qualified_plant_asset_overview.dart';

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

final plantAssetOverviewProvider = Provider<AsyncValue<PlantAssetOverview>>((
  ref,
) {
  final classes = ref.watch(plantClassEvidenceProvider);
  final assets = ref.watch(plantAssetEvidenceProvider);
  final conditions = ref.watch(plantManualEvidenceProvider);
  final workflow = ref.watch(plantWorkflowEvidenceProvider);
  final availability = ref.watch(plantAvailabilityEvidenceProvider);
  final tickets = ref.watch(plantTicketEvidenceProvider);
  final localTickets = ref.watch(plantConditionTicketsProvider);
  if (classes.isLoading || assets.isLoading) return const AsyncLoading();
  if (classes.hasError || assets.hasError) {
    final error = classes.asError ?? assets.asError!;
    return AsyncError(error.error, error.stackTrace);
  }
  final warnings = <String>[];
  void qualify<T>(String name, AsyncValue<PlantEvidenceBatch<T>> value) {
    final batch = value.asData?.value;
    if (batch == null) {
      warnings.add('$name evidence is unavailable or still loading.');
      return;
    }
    if (!batch.fromServer) {
      warnings.add(
        '$name is last-known evidence; current server state is unconfirmed.',
      );
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
    manualSourcesCurrent:
        classes.requireValue.fromServer &&
        assets.requireValue.fromServer &&
        conditions.asData?.value.fromServer == true,
    rejectedConditions: conditions.asData?.value.rejected.keys.toSet() ?? {},
    rejectedAssets: assets.requireValue.rejected.keys.toSet(),
    rejectedClasses: classes.requireValue.rejected.keys.toSet(),
  );
  return AsyncData(overview);
});
