import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local upsert failure holds watermark until the same record succeeds',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final updatedAt = DateTime.utc(2026, 7, 25, 12);
      final workflow =
          WorkflowAggregateRecord()
            ..firestoreId = 'workflow-1'
            ..jobExecutionFirestoreId = 'execution-1'
            ..assetTypeKey = 'furnace'
            ..assetNumber = 1
            ..updatedAt = updatedAt;
      final remote = _FakeRemote(workflow);
      final local = _FakeLocal()..failWorkflowUpserts = 1;
      final service = WorkflowPullService(remote: remote, local: local);

      final failed = await service.pull();
      final recovered = await service.pull();
      await service.pull();

      expect(failed.workflows, 0);
      expect(failed.failures['workflows'], contains('a local upsert failed'));
      expect(recovered.workflows, 1);
      expect(remote.workflowSince, <DateTime?>[null, null, updatedAt]);
      expect(local.workflowUpsertAttempts, 3);
    },
  );
}

class _FakeRemote implements WorkflowRemoteReadRepository {
  final WorkflowAggregateRecord workflow;
  final List<DateTime?> workflowSince = <DateTime?>[];

  _FakeRemote(this.workflow);

  @override
  Future<WorkflowRemoteBatch<WorkflowAggregateRecord>>
  fetchWorkflowsUpdatedSince(DateTime? since) async {
    workflowSince.add(since);
    return WorkflowRemoteBatch<WorkflowAggregateRecord>(
      records: <WorkflowAggregateRecord>[workflow],
      failures: const <WorkflowRemoteFailure>[],
      observedTimestamps: <DateTime>[workflow.updatedAt],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) async =>
      const WorkflowRemoteBatch<dynamic>(
        records: <dynamic>[],
        failures: <WorkflowRemoteFailure>[],
        observedTimestamps: <DateTime>[],
      );
}

class _FakeLocal implements WorkflowRepository {
  int failWorkflowUpserts = 0;
  int workflowUpsertAttempts = 0;

  @override
  Future<void> upsertWorkflowFromRemote(WorkflowAggregateRecord record) async {
    workflowUpsertAttempts += 1;
    if (failWorkflowUpserts > 0) {
      failWorkflowUpserts -= 1;
      throw StateError('transient local write failure');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod &&
        invocation.memberName.toString().startsWith('Symbol("upsert')) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
