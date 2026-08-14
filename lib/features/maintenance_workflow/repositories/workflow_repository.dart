import '../data/compliance_attempt_record.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_prompt_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_command_receipt_record.dart';
import '../data/workflow_command_record.dart';
import '../data/workflow_event_record.dart';

abstract interface class WorkflowRepository {
  Stream<WorkflowAggregateRecord?> watchWorkflow(String workflowId);
  Stream<List<JobLaneRecord>> watchLanes(String workflowId);
  Stream<List<JobLaneRecord>> watchLanesByLane(String laneKey);
  Stream<List<JobLaneRecord>> watchAllLanes();
  Stream<List<ComplianceRequestRecord>> watchCompliance(String workflowId);
  Stream<List<WorkflowEventRecord>> watchEvents(String workflowId);
  Stream<List<ComplianceRequestRecord>> watchComplianceInbox(String laneKey);
  Stream<List<ComplianceRequestRecord>> watchAllCompliance();
  Stream<List<EquipmentStatusRecord>> watchEquipmentByState(String? stateKey);

  Future<WorkflowAggregateRecord?> getWorkflow(String workflowId);
  Future<List<JobLaneRecord>> getLanes(String workflowId);
  Future<List<ComplianceRequestRecord>> getCompliance(String workflowId);
  Future<ComplianceRequestRecord?> getComplianceById(String complianceId);
  Future<EquipmentStatusRecord?> getEquipment(
    String assetTypeKey,
    int assetNumber, {
    String? assetClassId,
    String? assetInstanceId,
  });

  Future<void> upsertWorkflowFromRemote(WorkflowAggregateRecord record);
  Future<void> upsertLaneFromRemote(JobLaneRecord record);
  Future<void> upsertComplianceFromRemote(ComplianceRequestRecord record);
  Future<void> upsertComplianceAttemptFromRemote(
    ComplianceAttemptRecord record,
  );
  Future<void> upsertEquipmentFromRemote(EquipmentStatusRecord record);
  Future<void> upsertPromptFromRemote(EquipmentPromptRecord record);
  Future<void> upsertEventFromRemote(WorkflowEventRecord record);
  Future<void> saveReceipt(WorkflowCommandReceiptRecord record);

  Future<void> saveRetryCommand(WorkflowCommandRecord record);
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId);
  Future<List<WorkflowCommandRecord>> getRetryableCommands(DateTime now);
  Future<List<WorkflowCommandRecord>> getPendingCommands();
  Future<void> deleteRetryCommand(String commandId);
}
