import 'package:isar_community/isar.dart';

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
/// Scoped reads use the generated index queries so unrelated records are not
/// loaded into Dart or included in watched results. Remaining predicates and
/// ordering also run in Isar, including filters on fields without an index.
class IsarWorkflowRepository implements WorkflowRepository {
  final Isar isar;
  const IsarWorkflowRepository(this.isar);

  @override
  Stream<WorkflowAggregateRecord?> watchWorkflow(String workflowId) => isar
      .workflowAggregateRecords
      .where()
      .firestoreIdEqualTo(workflowId)
      .watch(fireImmediately: true)
      .map((rows) => rows.isEmpty ? null : rows.first);

  @override
  Stream<List<JobLaneRecord>> watchLanes(String workflowId) => isar
      .jobLaneRecords
      .where()
      .workflowFirestoreIdEqualTo(workflowId)
      .sortByDisplayOrder()
      .watch(fireImmediately: true);

  @override
  Stream<List<JobLaneRecord>> watchLanesByLane(String laneKey) => isar
      .jobLaneRecords
      .where()
      .laneKeyEqualTo(laneKey)
      .sortByUpdatedAtDesc()
      .watch(fireImmediately: true);

  @override
  Stream<List<JobLaneRecord>> watchAllLanes() => isar.jobLaneRecords
      .filter()
      .isDeletedEqualTo(false)
      .sortByUpdatedAtDesc()
      .watch(fireImmediately: true);

  @override
  Stream<List<ComplianceRequestRecord>> watchCompliance(String workflowId) =>
      isar.complianceRequestRecords
          .where()
          .linkedWorkflowIdEqualTo(workflowId)
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);

  @override
  Stream<List<WorkflowEventRecord>> watchEvents(String workflowId) => isar
      .workflowEventRecords
      .where()
      .aggregateIdEqualTo(workflowId)
      .sortByOccurredAtDesc()
      .watch(fireImmediately: true);

  @override
  Stream<List<ComplianceRequestRecord>> watchComplianceInbox(String laneKey) =>
      isar.complianceRequestRecords
          .where()
          .targetLaneKeyEqualTo(laneKey)
          .filter()
          .isDeletedEqualTo(false)
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);

  @override
  Stream<List<ComplianceRequestRecord>> watchAllCompliance() => isar
      .complianceRequestRecords
      .filter()
      .isDeletedEqualTo(false)
      .sortByUpdatedAtDesc()
      .watch(fireImmediately: true);

  @override
  Stream<List<EquipmentStatusRecord>> watchEquipmentByState(String? stateKey) {
    final query = stateKey == null
        ? isar.equipmentStatusRecords.where().sortByAssetTypeKey()
        : isar.equipmentStatusRecords
              .where()
              .stateKeyEqualTo(stateKey)
              .sortByAssetTypeKey();
    return query.thenByAssetNumber().watch(fireImmediately: true);
  }

  @override
  Future<WorkflowAggregateRecord?> getWorkflow(String workflowId) => isar
      .workflowAggregateRecords
      .where()
      .firestoreIdEqualTo(workflowId)
      .findFirst();

  @override
  Future<List<JobLaneRecord>> getLanes(String workflowId) => isar.jobLaneRecords
      .where()
      .workflowFirestoreIdEqualTo(workflowId)
      .sortByDisplayOrder()
      .findAll();

  @override
  Future<List<ComplianceRequestRecord>> getCompliance(String workflowId) => isar
      .complianceRequestRecords
      .where()
      .linkedWorkflowIdEqualTo(workflowId)
      .sortByUpdatedAtDesc()
      .findAll();

  @override
  Future<ComplianceRequestRecord?> getComplianceById(String complianceId) =>
      isar.complianceRequestRecords
          .where()
          .firestoreIdEqualTo(complianceId)
          .filter()
          .isDeletedEqualTo(false)
          .findFirst();

  @override
  Future<EquipmentStatusRecord?> getEquipment(
    String assetTypeKey,
    int assetNumber, {
    String? assetClassId,
    String? assetInstanceId,
  }) => isar.equipmentStatusRecords
      .where()
      .assetNumberEqualTo(assetNumber)
      .filter()
      .assetTypeKeyEqualTo(assetTypeKey)
      .optional(
        assetTypeKey == 'governedCustom',
        (query) => query
            .assetClassIdEqualTo(assetClassId)
            .assetInstanceIdEqualTo(assetInstanceId),
      )
      .findFirst();

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
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) => isar
      .workflowCommandRecords
      .where()
      .commandIdEqualTo(commandId)
      .findFirst();

  @override
  Future<List<WorkflowCommandRecord>> getRetryableCommands(DateTime now) => isar
      .workflowCommandRecords
      .where()
      .stateKeyEqualTo('uncertainOutcome')
      .filter()
      .nextRetryAtIsNotNull()
      .nextRetryAtLessThan(now, include: true)
      .sortByCreatedLocallyAt()
      .findAll();

  @override
  Future<List<WorkflowCommandRecord>> getPendingCommands() => isar
      .workflowCommandRecords
      .where()
      .stateKeyNotEqualTo('applied')
      .filter()
      .not()
      .stateKeyEqualTo('rejected')
      .sortByCreatedLocallyAt()
      .findAll();

  @override
  Future<void> deleteRetryCommand(String commandId) async {
    final row = await getRetryCommand(commandId);
    if (row == null) return;
    await isar.writeTxn(() async => isar.workflowCommandRecords.delete(row.id));
  }
}
