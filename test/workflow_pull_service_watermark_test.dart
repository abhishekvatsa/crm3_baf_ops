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
      await WorkflowPullService.clearQuarantine();
      final recovered = await service.pull();
      await service.pull();

      expect(failed.workflows, 0);
      expect(failed.failures['workflows'], contains('a local upsert failed'));
      expect(recovered.workflows, 1);
      expect(remote.workflowSince, <DateTime?>[null, null, updatedAt]);
      expect(local.workflowUpsertAttempts, 3);
    },
  );

  test(
    'durable remote quarantine holds the cursor and deduplicates retries',
    () async {
      const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final observedAt = DateTime.utc(2026, 8, 11, 1, 30);
      final service = WorkflowPullService(
        remote: _QuarantiningRemote(observedAt),
        local: _FakeLocal(),
      );

      final first = await service.pull();
      final second = await service.pull();
      final prefs = await SharedPreferences.getInstance();

      expect(first.failures['workflows'], contains('current batch'));
      expect(second.failures['workflows'], contains('existing quarantine'));
      expect(prefs.getString(workflowCursor), isNull);
      expect(await WorkflowPullService.readQuarantine(), hasLength(1));
    },
  );

  test(
    'malformed local cursor blocks fetch and remains available for repair',
    () async {
      const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
      SharedPreferences.setMockInitialValues(<String, Object>{
        workflowCursor: 'not-a-time',
      });
      final remote = _FakeRemote(_workflow(DateTime.utc(2026, 8, 11, 1)));
      final service = WorkflowPullService(remote: remote, local: _FakeLocal());

      final summary = await service.pull();
      final prefs = await SharedPreferences.getInstance();

      expect(summary.workflows, 0);
      expect(
        summary.failures['workflows'],
        contains('workflow-pull-cursor-invalid'),
      );
      expect(remote.workflowSince, isEmpty);
      expect(prefs.getString(workflowCursor), 'not-a-time');
    },
  );

  test(
    'corrupt quarantine prevents cursor advance past a malformed record',
    () async {
      const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
      const quarantineKey = 'last_maintenance_workflow_pull_v2_quarantine';
      SharedPreferences.setMockInitialValues(<String, Object>{
        quarantineKey: '{not-json',
      });
      final observedAt = DateTime.utc(2026, 8, 11, 2);
      final remote = _QuarantiningRemote(observedAt);
      final service = WorkflowPullService(remote: remote, local: _FakeLocal());

      final summary = await service.pull();
      final prefs = await SharedPreferences.getInstance();

      expect(summary.workflows, 0);
      expect(
        summary.failures['workflows'],
        contains('workflow-pull-quarantine-invalid'),
      );
      expect(summary.quarantinedRecords, isEmpty);
      expect(prefs.getString(workflowCursor), isNull);
      expect(prefs.getString(quarantineKey), '{not-json');
    },
  );

  test('wrongly typed local cursor maps to the same stable failure', () async {
    const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
    SharedPreferences.setMockInitialValues(<String, Object>{workflowCursor: 7});
    final remote = _FakeRemote(_workflow(DateTime.utc(2026, 8, 11, 1)));
    final service = WorkflowPullService(remote: remote, local: _FakeLocal());

    final summary = await service.pull();
    final prefs = await SharedPreferences.getInstance();

    expect(
      summary.failures['workflows'],
      contains('workflow-pull-cursor-invalid'),
    );
    expect(remote.workflowSince, isEmpty);
    expect(prefs.getInt(workflowCursor), 7);
  });

  test('failed quarantine write prevents cursor advance', () async {
    const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
    const quarantineKey = 'last_maintenance_workflow_pull_v2_quarantine';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final observedAt = DateTime.utc(2026, 8, 11, 3);
    final service = WorkflowPullService(
      remote: _QuarantiningRemote(observedAt),
      local: _FakeLocal(),
      preferenceWriter: (preferences, key, value) async {
        await preferences.setString(key, value);
        return false;
      },
    );

    final summary = await service.pull();
    final prefs = await SharedPreferences.getInstance();

    expect(
      summary.failures['workflows'],
      contains('workflow-pull-quarantine-write-failed'),
    );
    expect(prefs.getString(workflowCursor), isNull);
    expect(prefs.getString(quarantineKey), isNull);
  });

  test('readback mismatch prevents cursor advance', () async {
    const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
    const quarantineKey = 'last_maintenance_workflow_pull_v2_quarantine';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var quarantineWriteAttempted = false;
    final observedAt = DateTime.utc(2026, 8, 11, 4);
    final service = WorkflowPullService(
      remote: _QuarantiningRemote(observedAt),
      local: _FakeLocal(),
      preferenceReader: (preferences, key) {
        if (key == quarantineKey && quarantineWriteAttempted) return '[]';
        return preferences.getString(key);
      },
      preferenceWriter: (preferences, key, value) async {
        if (key == quarantineKey) {
          quarantineWriteAttempted = true;
          return true;
        }
        return preferences.setString(key, value);
      },
    );

    final summary = await service.pull();
    final prefs = await SharedPreferences.getInstance();

    expect(
      summary.failures['workflows'],
      contains('workflow-pull-quarantine-write-failed'),
    );
    expect(prefs.getString(workflowCursor), isNull);
  });

  test(
    'existing corrupt quarantine blocks valid-only cursor advance',
    () async {
      const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
      const quarantineKey = 'last_maintenance_workflow_pull_v2_quarantine';
      SharedPreferences.setMockInitialValues(<String, Object>{
        quarantineKey: '{not-json',
      });
      final remote = _FakeRemote(_workflow(DateTime.utc(2026, 8, 11, 5)));
      final local = _FakeLocal();
      final service = WorkflowPullService(remote: remote, local: local);

      final summary = await service.pull();
      final prefs = await SharedPreferences.getInstance();

      expect(
        summary.failures['workflows'],
        contains('workflow-pull-quarantine-invalid'),
      );
      expect(remote.workflowSince, isEmpty);
      expect(local.workflowUpsertAttempts, 0);
      expect(prefs.getString(workflowCursor), isNull);
      expect(prefs.getString(quarantineKey), '{not-json');
    },
  );

  test(
    'failed cursor write returns a stable failure and remains unset',
    () async {
      const workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final remote = _FakeRemote(_workflow(DateTime.utc(2026, 8, 11, 6)));
      final service = WorkflowPullService(
        remote: remote,
        local: _FakeLocal(),
        preferenceWriter: (preferences, key, value) async {
          if (key == workflowCursor) {
            await preferences.setString(key, value);
            return false;
          }
          return preferences.setString(key, value);
        },
      );

      final summary = await service.pull();
      final prefs = await SharedPreferences.getInstance();

      expect(
        summary.failures['workflows'],
        contains('workflow-pull-cursor-write-failed'),
      );
      expect(prefs.getString(workflowCursor), isNull);
    },
  );

  test('corrupt quarantine is visible until explicitly cleared', () async {
    const quarantineKey = 'last_maintenance_workflow_pull_v2_quarantine';
    SharedPreferences.setMockInitialValues(<String, Object>{
      quarantineKey: '["not-an-object"]',
    });

    await expectLater(
      WorkflowPullService.readQuarantine(),
      throwsA(
        isA<WorkflowPullStateException>().having(
          (error) => error.reasonCode,
          'reasonCode',
          'workflow-pull-quarantine-invalid',
        ),
      ),
    );

    await WorkflowPullService.clearQuarantine();
    expect(await WorkflowPullService.readQuarantine(), isEmpty);
  });
}

WorkflowAggregateRecord _workflow(DateTime updatedAt) =>
    WorkflowAggregateRecord()
      ..firestoreId = 'workflow-1'
      ..jobExecutionFirestoreId = 'execution-1'
      ..assetTypeKey = 'furnace'
      ..assetNumber = 1
      ..updatedAt = updatedAt;

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

class _QuarantiningRemote implements WorkflowRemoteReadRepository {
  final DateTime observedAt;

  const _QuarantiningRemote(this.observedAt);

  @override
  Future<WorkflowRemoteBatch<WorkflowAggregateRecord>>
  fetchWorkflowsUpdatedSince(DateTime? since) async {
    return WorkflowRemoteBatch<WorkflowAggregateRecord>(
      records: const <WorkflowAggregateRecord>[],
      failures: <WorkflowRemoteFailure>[
        WorkflowRemoteFailure(
          collection: 'maintenance_workflows',
          documentId: 'workflow-malformed',
          error: 'Malformed workflow projection.',
          observedAt: observedAt,
        ),
      ],
      observedTimestamps: <DateTime>[observedAt],
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
