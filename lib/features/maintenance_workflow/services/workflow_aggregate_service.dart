import '../data/workflow_record_mappers.dart';
import '../domain/workflow_models.dart';
import '../repositories/workflow_repository.dart';

class WorkflowAggregateService {
  final WorkflowRepository repository;
  const WorkflowAggregateService(this.repository);

  Future<WorkflowAggregateSnapshot?> load(String workflowId) async {
    final workflowRecord = await repository.getWorkflow(workflowId);
    if (workflowRecord == null) return null;
    final laneRecords = await repository.getLanes(workflowId);
    final compliance = await repository.getCompliance(workflowId);
    final lanes = laneRecords
        .map((record) => record.toSnapshotOrNull())
        .whereType<JobLaneSnapshot>()
        .toList(growable: false);
    final openBlocking = compliance.where((record) {
      if (record.gatesLaneFirestoreId == null) return false;
      return record.statusKey != 'confirmedClosed' &&
          record.statusKey != 'superseded' &&
          record.statusKey != 'cancelled';
    }).length;
    return WorkflowAggregateSnapshot(
      workflow: workflowRecord.toSnapshot(),
      lanes: lanes,
      openBlockingComplianceCount: openBlocking,
    );
  }
}
