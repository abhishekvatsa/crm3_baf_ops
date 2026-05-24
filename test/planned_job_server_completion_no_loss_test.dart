import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:crm3_baf_ops/main.dart' as app;
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';

Future<void> _withTestIsar(Future<void> Function(Isar isar) body) async {
  final dir = await Directory.systemTemp.createTemp('baf_server_completion_');
  final instance = await Isar.open(
    [JobExecutionSchema, JobModuleInstanceSchema],
    directory: dir.path,
    name: 'baf_server_completion_test',
  );

  app.isar = instance;

  try {
    await body(instance);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

AppUser _supervisor() => AppUser(
  uid: 'supervisor_1',
  name: 'Shift Supervisor',
  email: 'shift@example.com',
  roles: [AppRole.shiftSupervisor],
  isApproved: true,
  createdAt: DateTime.utc(2026, 5, 16),
);

JobExecution _localExecution({
  String? firestoreId = 'exec_1',
  bool isSynced = true,
  bool isCompleted = false,
  int version = 2,
}) {
  return JobExecution()
    ..firestoreId = firestoreId
    ..templateFirestoreId = 'template_1'
    ..templateName = 'BAF closure template'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..isCompleted = isCompleted
    ..assignedByUid = 'planner'
    ..assignedByName = 'Planner'
    ..assignedAgencies = [RoutedTo.mechanical.name]
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..version = version
    ..isDeleted = false
    ..createdAt = DateTime.utc(2026, 5, 16, 8)
    ..updatedAt = DateTime.utc(2026, 5, 16, 8, 30)
    ..isSynced = isSynced;
}

JobExecution _remoteCompletedExecution({int version = 3}) {
  return JobExecution()
    ..firestoreId = 'exec_1'
    ..templateFirestoreId = 'template_1'
    ..templateName = 'BAF closure template'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..isCompleted = true
    ..assignedByUid = 'planner'
    ..assignedByName = 'Planner'
    ..assignedAgencies = [RoutedTo.mechanical.name]
    ..completedByUid = 'supervisor_1'
    ..completedByName = 'Shift Supervisor'
    ..remarks = 'Completed by server'
    ..teamsInvolved = ['mechanical']
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..metadataJson = '{"closureAttestation":{"hash":"server_hash"}}'
    ..version = version
    ..isDeleted = false
    ..createdAt = DateTime.utc(2026, 5, 16, 8)
    ..completedAt = DateTime.utc(2026, 5, 16, 9)
    ..updatedAt = DateTime.utc(2026, 5, 16, 9)
    ..isSynced = true;
}

JobModuleInstance _acceptedModule({bool isSynced = true}) {
  return JobModuleInstance()
    ..firestoreId = 'module_1'
    ..jobExecutionFirestoreId = 'exec_1'
    ..templateFirestoreId = 'template_1'
    ..moduleCode = 'M-01'
    ..moduleTitle = 'Inspect base fan'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson =
        '[{"key":"vt_reading","type":"number","isRequired":true}]'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..status = JobModuleStatus.accepted
    ..useMode = JobModuleUseMode.scheduledPM
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..isRequired = true
    ..requiredForClosure = true
    ..responsesJson = '[{"key":"vt_reading","value":"2.1"}]'
    ..actionsJson = '[]'
    ..createdByUid = 'supervisor_1'
    ..createdByName = 'Shift Supervisor'
    ..createdAt = DateTime.utc(2026, 5, 16, 8)
    ..updatedByUid = 'supervisor_1'
    ..updatedByName = 'Shift Supervisor'
    ..updatedAt = DateTime.utc(2026, 5, 16, 8, 45)
    ..version = 1
    ..isSynced = isSynced
    ..isDeleted = false;
}

class _FakeServerCompletion extends PlannedJobServerCompletionService {
  _FakeServerCompletion({this.response, this.error});

  final JobExecution? response;
  final Object? error;
  int calls = 0;
  int? lastExpectedCompletionVersion;

  @override
  Future<JobExecution> completeExecution({
    required String executionFirestoreId,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
    int? expectedCompletionVersion,
  }) async {
    calls += 1;
    lastExpectedCompletionVersion = expectedCompletionVersion;
    final failure = error;
    if (failure != null) throw failure;
    return response ?? _remoteCompletedExecution();
  }
}

Future<JobExecution> _putExecution(Isar isar, JobExecution execution) async {
  await isar.writeTxn(() async {
    final id = await isar.jobExecutions.put(execution);
    execution.id = id;
  });
  return execution;
}

Future<void> _putModule(Isar isar, JobModuleInstance module) async {
  await isar.writeTxn(() async {
    await isar.jobModuleInstances.put(module);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(download: false);
  });

  group('server completion no-loss preflight', () {
    test('does not call server when execution has no Firestore id', () async {
      await _withTestIsar((isar) async {
        final execution = await _putExecution(
          isar,
          _localExecution(firestoreId: null),
        );
        await _putModule(isar, _acceptedModule());
        final fakeServer = _FakeServerCompletion();
        final repo = IsarPlannedRepository(serverCompletion: fakeServer);

        await expectLater(
          repo.completeExecution(execution.id, actor: _supervisor()),
          throwsA(isA<StateError>()),
        );

        expect(fakeServer.calls, 0);
        final after = await isar.jobExecutions.get(execution.id);
        expect(after!.isCompleted, isFalse);
        expect(after.isSynced, isTrue);
      });
    });

    test('does not call server when execution header is unsynced', () async {
      await _withTestIsar((isar) async {
        final execution = await _putExecution(
          isar,
          _localExecution(isSynced: false),
        );
        await _putModule(isar, _acceptedModule());
        final fakeServer = _FakeServerCompletion();
        final repo = IsarPlannedRepository(serverCompletion: fakeServer);

        await expectLater(
          repo.completeExecution(execution.id, actor: _supervisor()),
          throwsA(isA<StateError>()),
        );

        expect(fakeServer.calls, 0);
        final after = await isar.jobExecutions.get(execution.id);
        expect(after!.isCompleted, isFalse);
        expect(after.isSynced, isFalse);
      });
    });

    test('does not call server when any attached module is unsynced', () async {
      await _withTestIsar((isar) async {
        final execution = await _putExecution(isar, _localExecution());
        await _putModule(isar, _acceptedModule(isSynced: false));
        final fakeServer = _FakeServerCompletion();
        final repo = IsarPlannedRepository(serverCompletion: fakeServer);

        await expectLater(
          repo.completeExecution(execution.id, actor: _supervisor()),
          throwsA(isA<StateError>()),
        );

        expect(fakeServer.calls, 0);
        final after = await isar.jobExecutions.get(execution.id);
        expect(after!.isCompleted, isFalse);
      });
    });

    test(
      'server failed-precondition leaves local execution uncompleted',
      () async {
        await _withTestIsar((isar) async {
          final execution = await _putExecution(
            isar,
            _localExecution(version: 2),
          );
          await _putModule(isar, _acceptedModule());
          final fakeServer = _FakeServerCompletion(
            error: const PlannedJobServerClosureGateException(
              message: 'Cannot complete planned job: modules are not ready.',
              issues: [
                PlannedJobServerClosureIssue(
                  type: 'openRequiredModule',
                  count: 1,
                  message: '1 required module(s) still open',
                  moduleFirestoreIds: ['module_1'],
                ),
              ],
            ),
          );
          final repo = IsarPlannedRepository(serverCompletion: fakeServer);

          await expectLater(
            repo.completeExecution(execution.id, actor: _supervisor()),
            throwsA(isA<PlannedJobServerClosureGateException>()),
          );

          expect(fakeServer.calls, 1);
          expect(fakeServer.lastExpectedCompletionVersion, 3);
          final after = await isar.jobExecutions.get(execution.id);
          expect(after!.isCompleted, isFalse);
          expect(after.version, 2);
          expect(after.completedByUid, isNull);
          expect(after.isSynced, isTrue);
        });
      },
    );

    test(
      'transient server failure leaves local execution uncompleted',
      () async {
        await _withTestIsar((isar) async {
          final execution = await _putExecution(
            isar,
            _localExecution(version: 2),
          );
          await _putModule(isar, _acceptedModule());
          final fakeServer = _FakeServerCompletion(
            error: const PlannedJobServerCompletionException(
              code: 'unavailable',
              message: 'transient transport failure',
            ),
          );
          final repo = IsarPlannedRepository(serverCompletion: fakeServer);

          await expectLater(
            repo.completeExecution(execution.id, actor: _supervisor()),
            throwsA(isA<PlannedJobServerCompletionException>()),
          );

          expect(fakeServer.calls, 1);
          expect(fakeServer.lastExpectedCompletionVersion, 3);
          final after = await isar.jobExecutions.get(execution.id);
          expect(after!.isCompleted, isFalse);
          expect(after.version, 2);
          expect(after.completedByUid, isNull);
          expect(after.completedAt, isNull);
          expect(after.metadataJson, isNull);
          expect(after.isSynced, isTrue);
        });
      },
    );

    test(
      'valid server response rebases local execution from canonical remote copy',
      () async {
        await _withTestIsar((isar) async {
          final execution = await _putExecution(
            isar,
            _localExecution(version: 2),
          );
          await _putModule(isar, _acceptedModule());
          final fakeServer = _FakeServerCompletion(
            response: _remoteCompletedExecution(version: 3),
          );
          final repo = IsarPlannedRepository(serverCompletion: fakeServer);

          await repo.completeExecution(execution.id, actor: _supervisor());

          expect(fakeServer.calls, 1);
          expect(fakeServer.lastExpectedCompletionVersion, 3);
          final after = await isar.jobExecutions.get(execution.id);
          expect(after!.isCompleted, isTrue);
          expect(after.version, 3);
          expect(after.completedByUid, 'supervisor_1');
          expect(after.metadataJson, contains('closureAttestation'));
          expect(after.isSynced, isTrue);
        });
      },
    );
  });
}
