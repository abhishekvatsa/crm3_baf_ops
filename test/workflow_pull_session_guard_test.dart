import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cursorKey = 'last_maintenance_workflow_pull_v2_workflows';
const _quarantineKey = 'last_maintenance_workflow_pull_v2_quarantine';
final _time = DateTime.utc(2026, 9, 27, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final code in ['unauthenticated', 'data-loss']) {
    test('guarded remote $code escapes collection isolation', () async {
      final remote = _Remote()
        ..fetchError = FirebaseException(plugin: 'cloud_firestore', code: code);
      final local = _Local();
      await expectLater(
        WorkflowPullService(
          remote: remote,
          local: local,
        ).pull(runGuard: SyncRunGuard(() {})),
        throwsA(isA<SyncRunAborted>().having((e) => e.reason, 'reason', code)),
      );
      expect(remote.calls, ['workflows']);
      expect(local.attempted, isEmpty);
      await _expectNoCheckpointOrQuarantine();
    });
  }

  test(
    'guarded fatal local Isar failure is not quarantined as a bad record',
    () async {
      final remote = _Remote();
      final local = _Local()..upsertError = IsarError('database owner ended');
      await expectLater(
        WorkflowPullService(
          remote: remote,
          local: local,
        ).pull(runGuard: SyncRunGuard(() {})),
        throwsA(isA<IsarError>()),
      );
      expect(remote.calls, ['workflows']);
      expect(local.attempted, ['first']);
      await _expectNoCheckpointOrQuarantine();
    },
  );

  test(
    'session ending while remote fetch is in flight prevents all local adoption',
    () async {
      final state = _Session();
      final entered = Completer<void>();
      final release = Completer<void>();
      final remote = _Remote()
        ..onFetch = () async {
          entered.complete();
          await release.future;
        };
      final local = _Local();
      final result = WorkflowPullService(
        remote: remote,
        local: local,
      ).pull(runGuard: state.guard);
      await entered.future;
      state.current = false;
      release.complete();
      await expectLater(result, throwsA(isA<SyncRunAborted>()));
      expect(remote.calls, ['workflows']);
      expect(local.attempted, isEmpty);
      await _expectNoCheckpointOrQuarantine();
    },
  );

  test(
    'session ending during an upsert stops the next row and keeps checkpoint pending',
    () async {
      final state = _Session();
      final entered = Completer<void>();
      final release = Completer<void>();
      final remote = _Remote();
      final local = _Local()
        ..onUpsert = () async {
          entered.complete();
          await release.future;
        };
      final result = WorkflowPullService(
        remote: remote,
        local: local,
      ).pull(runGuard: state.guard);
      await entered.future;
      state.current = false;
      release.complete();
      await expectLater(result, throwsA(isA<SyncRunAborted>()));
      // The already-started upsert cannot be rolled back by the coordinator.
      // It must not authorize another row or a completed collection cursor.
      expect(local.attempted, ['first']);
      expect(local.saved, ['first']);
      expect(remote.calls, ['workflows']);
      await _expectNoCheckpointOrQuarantine();
    },
  );

  test(
    'session ending during cursor persistence restores its prior boundary',
    () async {
      final previous = _time
          .subtract(const Duration(days: 1))
          .toIso8601String();
      SharedPreferences.setMockInitialValues({_cursorKey: previous});
      final state = _Session();
      final remote = _Remote();
      final local = _Local();
      final service = WorkflowPullService(
        remote: remote,
        local: local,
        preferenceWriter: (preferences, key, value) async {
          final written = await preferences.setString(key, value);
          state.current = false;
          return written;
        },
      );
      await expectLater(
        service.pull(runGuard: state.guard),
        throwsA(isA<SyncRunAborted>()),
      );
      expect(local.saved, ['first', 'second']);
      expect(remote.calls, ['workflows']);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(_cursorKey), previous);
      expect(preferences.getString(_quarantineKey), isNull);
    },
  );

  test(
    'ordinary guarded record failure still quarantines and permits valid siblings',
    () async {
      final remote = _Remote();
      final local = _Local()..failFirstOnly = true;
      final summary = await WorkflowPullService(
        remote: remote,
        local: local,
      ).pull(runGuard: SyncRunGuard(() {}));
      expect(summary.workflows, 1);
      expect(summary.failures['workflows'], contains('a local upsert failed'));
      expect(summary.quarantinedRecords.single.documentId, 'first');
      expect(local.saved, ['second']);
      expect(remote.calls, hasLength(7));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(_cursorKey), isNull);
      expect(await WorkflowPullService.readQuarantine(), hasLength(1));
    },
  );

  test(
    'standalone no-guard pull keeps its existing collection failure summary',
    () async {
      final remote = _Remote()
        ..fetchError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
        );
      final summary = await WorkflowPullService(
        remote: remote,
        local: _Local(),
      ).pull();
      expect(summary.failures['workflows'], contains('unauthenticated'));
      expect(remote.calls, hasLength(7));
      await _expectNoCheckpointOrQuarantine();
    },
  );
}

Future<void> _expectNoCheckpointOrQuarantine() async {
  final preferences = await SharedPreferences.getInstance();
  expect(preferences.getString(_cursorKey), isNull);
  expect(preferences.getString(_quarantineKey), isNull);
}

class _Session {
  bool current = true;
  late final guard = SyncRunGuard(() {
    if (!current) throw const SyncRunAborted('session-ended');
  });
}

WorkflowAggregateRecord _record(String id) => WorkflowAggregateRecord()
  ..firestoreId = id
  ..jobExecutionFirestoreId = 'job-$id'
  ..assetTypeKey = 'furnace'
  ..assetNumber = 1
  ..updatedAt = _time;

class _Remote extends Fake implements WorkflowRemoteReadRepository {
  final calls = <String>[];
  Object? fetchError;
  Future<void> Function()? onFetch;

  @override
  Future<WorkflowRemoteBatch<WorkflowAggregateRecord>>
  fetchWorkflowsUpdatedSince(DateTime? since) async {
    calls.add('workflows');
    await onFetch?.call();
    if (fetchError case final error?) throw error;
    return WorkflowRemoteBatch(
      records: [_record('first'), _record('second')],
      failures: const [],
      observedTimestamps: [_time],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) async {
    calls.add(invocation.memberName.toString());
    return const WorkflowRemoteBatch<dynamic>(
      records: [],
      failures: [],
      observedTimestamps: [],
    );
  }
}

class _Local extends Fake implements WorkflowRepository {
  final attempted = <String>[];
  final saved = <String>[];
  Object? upsertError;
  bool failFirstOnly = false;
  Future<void> Function()? onUpsert;

  @override
  Future<void> upsertWorkflowFromRemote(WorkflowAggregateRecord record) async {
    attempted.add(record.firestoreId);
    await onUpsert?.call();
    if (upsertError case final error?) throw error;
    if (failFirstOnly && attempted.length == 1) {
      throw StateError('record needs repair');
    }
    saved.add(record.firestoreId);
  }
}
