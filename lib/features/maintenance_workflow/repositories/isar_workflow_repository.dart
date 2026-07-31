import 'package:isar/isar.dart';

import '../data/compliance_attempt_record.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_prompt_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_command_receipt_record.dart';
import '../data/workflow_command_record.dart';
import '../data/workflow_event_record.dart';
import 'workflow_repository.dart';

/// Isar-backed workflow projection repository.
///
/// The repository deliberately depends only on Isar's base collection/query
/// API. Filtering and ordering are applied after the local collection query.
/// This keeps the workflow persistence contract independent from generated
/// convenience extensions and makes genuine build-runner regeneration a
/// byte-checkable implementation detail rather than a behavioural dependency.
class IsarWorkflowRepository implements WorkflowRepository {
  final Isar isar;
  const IsarWorkflowRepository(this.isar);

  @override
  Stream<WorkflowAggregateRecord?> watchWorkflow(String workflowId) => isar
      .workflowAggregateRecords
      .where()
      .watch(fireImmediately: true)
      .map((rows) {
        for (final row in rows) {
          if (row.firestoreId == workflowId) return row;
        }
        return null;
      });

  @override
  Stream<List<JobLaneRecord>> watchLanes(String workflowId) =>
      isar.jobLaneRecords.where().watch(fireImmediately: true).map((rows) {
        final result = rows
            .where((row) => row.workflowFirestoreId == workflowId)
            .toList(growable: false)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return result;
      });

  @override
  Stream<List<JobLaneRecord>> watchLanesByLane(String laneKey) =>
      isar.jobLaneRecords.where().watch(fireImmediately: true).map((rows) {
        final result =
            rows.where((row) => row.laneKey == laneKey).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result;
      });

  @override
  Stream<List<JobLaneRecord>> watchAllLanes() =>
      isar.jobLaneRecords.where().watch(fireImmediately: true).map((rows) {
        final result =
            rows.where((row) => !row.isDeleted).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result;
      });

  @override
  Stream<List<ComplianceRequestRecord>> watchCompliance(String workflowId) =>
      isar.complianceRequestRecords.where().watch(fireImmediately: true).map((
        rows,
      ) {
        final result =
            rows.where((row) => row.linkedWorkflowId == workflowId).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result;
      });

  @override
  Stream<List<WorkflowEventRecord>> watchEvents(String workflowId) => isar
      .workflowEventRecords
      .where()
      .watch(fireImmediately: true)
      .map((rows) {
        final result =
            rows.where((row) => row.aggregateId == workflowId).toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        return result;
      });

  @override
  Stream<List<ComplianceRequestRecord>> watchComplianceInbox(String laneKey) =>
      isar.complianceRequestRecords.where().watch(fireImmediately: true).map((
        rows,
      ) {
        final result =
            rows
                .where((row) => row.targetLaneKey == laneKey && !row.isDeleted)
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result;
      });

  @override
  Stream<List<ComplianceRequestRecord>> watchAllCompliance() => isar
      .complianceRequestRecords
      .where()
      .watch(fireImmediately: true)
      .map((rows) {
        final result =
            rows.where((row) => !row.isDeleted).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result;
      });

  @override
  Stream<List<EquipmentStatusRecord>> watchEquipmentByState(String? stateKey) =>
      isar.equipmentStatusRecords.where().watch(fireImmediately: true).map((
        rows,
      ) {
        final result =
            rows
                .where((row) => stateKey == null || row.stateKey == stateKey)
                .toList()
              ..sort((a, b) {
                final type = a.assetTypeKey.compareTo(b.assetTypeKey);
                return type != 0
                    ? type
                    : a.assetNumber.compareTo(b.assetNumber);
              });
        return result;
      });

  @override
  Future<WorkflowAggregateRecord?> getWorkflow(String workflowId) async {
    final rows = await isar.workflowAggregateRecords.where().findAll();
    for (final row in rows) {
      if (row.firestoreId == workflowId) return row;
    }
    return null;
  }

  @override
  Future<List<JobLaneRecord>> getLanes(String workflowId) async {
    final rows = await isar.jobLaneRecords.where().findAll();
    final result = rows
        .where((row) => row.workflowFirestoreId == workflowId)
        .toList(growable: false)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return result;
  }

  @override
  Future<List<ComplianceRequestRecord>> getCompliance(String workflowId) async {
    final rows = await isar.complianceRequestRecords.where().findAll();
    final result = rows
        .where((row) => row.linkedWorkflowId == workflowId)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<ComplianceRequestRecord?> getComplianceById(
    String complianceId,
  ) async {
    final rows = await isar.complianceRequestRecords.where().findAll();
    for (final row in rows) {
      if (!row.isDeleted && row.firestoreId == complianceId) return row;
    }
    return null;
  }

  @override
  Future<EquipmentStatusRecord?> getEquipment(
    String assetTypeKey,
    int assetNumber,
  ) async {
    final rows = await isar.equipmentStatusRecords.where().findAll();
    for (final row in rows) {
      if (row.assetTypeKey == assetTypeKey && row.assetNumber == assetNumber) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<void> upsertWorkflowFromRemote(WorkflowAggregateRecord record) =>
      isar.writeTxn(() async => isar.workflowAggregateRecords.put(record));

  @override
  Future<void> upsertLaneFromRemote(JobLaneRecord record) =>
      isar.writeTxn(() async => isar.jobLaneRecords.put(record));

  @override
  Future<void> upsertComplianceFromRemote(ComplianceRequestRecord record) =>
      isar.writeTxn(() async => isar.complianceRequestRecords.put(record));

  @override
  Future<void> upsertComplianceAttemptFromRemote(
    ComplianceAttemptRecord record,
  ) => isar.writeTxn(() async => isar.complianceAttemptRecords.put(record));

  @override
  Future<void> upsertEquipmentFromRemote(EquipmentStatusRecord record) =>
      isar.writeTxn(() async => isar.equipmentStatusRecords.put(record));

  @override
  Future<void> upsertPromptFromRemote(EquipmentPromptRecord record) =>
      isar.writeTxn(() async => isar.equipmentPromptRecords.put(record));

  @override
  Future<void> upsertEventFromRemote(WorkflowEventRecord record) =>
      isar.writeTxn(() async => isar.workflowEventRecords.put(record));

  @override
  Future<void> saveReceipt(WorkflowCommandReceiptRecord record) =>
      isar.writeTxn(() async => isar.workflowCommandReceiptRecords.put(record));

  @override
  Future<void> saveRetryCommand(WorkflowCommandRecord record) =>
      isar.writeTxn(() async => isar.workflowCommandRecords.put(record));

  @override
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) async {
    final rows = await isar.workflowCommandRecords.where().findAll();
    for (final row in rows) {
      if (row.commandId == commandId) return row;
    }
    return null;
  }

  @override
  Future<List<WorkflowCommandRecord>> getRetryableCommands(DateTime now) async {
    final rows = await isar.workflowCommandRecords.where().findAll();
    final result = rows
        .where(
          (row) =>
              row.stateKey == 'uncertainOutcome' &&
              row.nextRetryAt != null &&
              !row.nextRetryAt!.isAfter(now),
        )
        .toList(growable: false)
      ..sort((a, b) => a.createdLocallyAt.compareTo(b.createdLocallyAt));
    return result;
  }

  @override
  Future<List<WorkflowCommandRecord>> getPendingCommands() async {
    final rows = await isar.workflowCommandRecords.where().findAll();
    final pending = rows
        .where((row) => row.stateKey != 'applied' && row.stateKey != 'rejected')
        .toList(growable: false)
      ..sort((a, b) => a.createdLocallyAt.compareTo(b.createdLocallyAt));
    return pending;
  }

  @override
  Future<void> deleteRetryCommand(String commandId) async {
    final row = await getRetryCommand(commandId);
    if (row == null) return;
    await isar.writeTxn(() async => isar.workflowCommandRecords.delete(row.id));
  }
}
