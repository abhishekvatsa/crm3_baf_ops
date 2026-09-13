import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crm3_baf_ops/core/persistence/app_database.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/workflow_module_reopen_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../tool/test_support/test_isar_core.dart';

class _Gateway implements OriginBoundWorkflowCommandGateway {
  _Gateway(this.send);
  final Future<WorkflowCommandReceipt> Function(String) send;
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) => send(envelopeJson);
}

// Match Flutter's native Firestore transport for outer document values. Audit
// JSON strings are deliberately untouched, including their Timestamp maps.
dynamic _hydrateFirestoreFixture(dynamic value) {
  if (value is Map) {
    if (value.length == 2 &&
        value.containsKey('_seconds') &&
        value.containsKey('_nanoseconds')) {
      return Timestamp(value['_seconds'] as int, value['_nanoseconds'] as int);
    }
    return value.map(
      (key, child) => MapEntry(key as String, _hydrateFirestoreFixture(child)),
    );
  }
  if (value is List) return value.map(_hydrateFirestoreFixture).toList();
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final actor = AppUser(
    uid: 'admin-1',
    name: 'Admin',
    email: 'admin@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  final other = AppUser(
    uid: 'admin-2',
    name: 'Other',
    email: 'other@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  final appliedAt = DateTime.utc(2026, 9, 13, 9);
  late Directory directory;
  late JobModuleInstance baseline;
  late IsarJobModuleRepository repository;
  late DurableSubmissionRepository store;
  late AppUser currentActor;
  late Map<String, dynamic> remote;
  late Map<String, dynamic> audit;
  late int dispatches, probes, reads;
  bool failRead = false;
  Future<void> Function(String collection)? afterRead;
  Future<void> Function()? afterDispatch;
  void Function()? transactionFence;
  Future<void> open() async {
    isar = await Isar.open(
      [JobModuleInstanceSchema, DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'module_reopen',
      inspector: false,
    );
    repository = IsarJobModuleRepository(
      verifyActor: (expected) {
        transactionFence?.call();
        if (currentActor.uid != expected.uid ||
            !currentActor.isApproved ||
            !currentActor.canReopenJobModule) {
          throw StateError('Actor changed');
        }
      },
    );
    store = DurableSubmissionRepository(isar);
  }

  Future<JobModuleInstance> local() async =>
      (await isar.jobModuleInstances.get(baseline.id))!;
  Future<void> put(JobModuleInstance value) async {
    await isar.writeTxn(() async {
      await isar.jobModuleInstances.put(value);
    });
  }

  JobModuleInstance serverModule({
    int version = 5,
    JobModuleStatus status = JobModuleStatus.reopened,
  }) => copyJobModuleForEditing(baseline)
    ..version = version
    ..status = status
    ..updatedAt = appliedAt.add(Duration(minutes: version - 5))
    ..reopenedByUid = actor.uid
    ..reopenedByName = actor.name
    ..reopenedAt = appliedAt
    ..reopenReason = 'Reinspect seal'
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..isSynced = true;
  WorkflowModuleReopenController controller() => WorkflowModuleReopenController(
    store: store,
    modules: repository,
    requireActor: () => currentActor,
    requireCapability: (uid) async {
      probes++;
      expect(uid, actor.uid);
    },
    gateway: _Gateway((envelope) async {
      dispatches++;
      final wrapper = jsonDecode(envelope) as Map;
      final command = wrapper['command'] as Map;
      expect(wrapper['originActorUid'], actor.uid);
      expect(command['payload'], {
        'moduleFirestoreId': 'module-7',
        'reason': 'Reinspect seal',
      });
      if (afterDispatch != null) await afterDispatch!();
      return WorkflowCommandReceipt(
        commandId: command['commandId'] as String,
        resultKey: 'workflow-module-reopened',
        aggregateVersion: 11,
        result: {
          'moduleFirestoreId': 'module-7',
          'laneKey': 'mech',
          'laneReactivated': true,
        },
        appliedAt: appliedAt,
      );
    }),
    readDocument: (collection, id) async {
      reads++;
      if (failRead) throw StateError('Readback interrupted');
      if (afterRead != null) await afterRead!(collection);
      if (collection == 'audit_logs') {
        expect(id, 'workflow_module_reopen_module-7_11');
        return audit;
      }
      expect(collection, 'job_modules');
      expect(id, 'module-7');
      return remote;
    },
  );
  Future<DurableSubmission> prepare() => controller().prepare(
    actorUid: actor.uid,
    executionId: 'job-7',
    workflowVersion: 10,
    reason: 'Reinspect seal',
    baseline: baseline,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('module_reopen_');
    currentActor = actor;
    dispatches = 0;
    probes = 0;
    reads = 0;
    failRead = false;
    afterRead = null;
    afterDispatch = null;
    transactionFence = null;
    await open();
    baseline = JobModuleInstance()
      ..firestoreId = 'module-7'
      ..jobExecutionFirestoreId = 'job-7'
      ..jobExecutionLocalId = 91
      ..assetType = AssetType.base
      ..assetNumber = 107
      ..moduleTitle = 'Seal inspection'
      ..discipline = JobModuleDiscipline.mechanical
      ..laneKey = 'mech'
      ..workflowLaneFirestoreId = 'job-7__mech'
      ..createdByUid = 'creator-1'
      ..createdAt = DateTime.utc(2026, 9, 12)
      ..updatedAt = DateTime.utc(2026, 9, 12)
      ..version = 4
      ..isSynced = true
      ..status = JobModuleStatus.accepted;
    await put(baseline);
    remote = serverModule().toMap();
    if (Platform.environment['EXPORT_REOPEN_PRODUCER_SEED'] == '1') {
      await File(
        'build/review-20260913/workflow-module-before-seed.json',
      ).writeAsString(jsonEncode(baseline.toMap()));
    }
    audit = {
      'entityType': 'jobModule',
      'entityId': 'module-7',
      'action': 'reopen',
      'performedByUid': actor.uid,
      'performedByName': actor.name,
      'timestamp': appliedAt.toIso8601String(),
      'reason': 'workflowModuleReopened',
      'reasonNotes': 'Reinspect seal',
      'workflowAggregateId': 'job-7',
      'laneKey': 'mech',
      'beforeJson': jsonEncode(baseline.toMap()),
      'afterJson': jsonEncode({
        ...baseline.toMap(),
        'status': 'reopened',
        'isOpenForWork': true,
      }),
    };
  });
  tearDown(() async {
    transactionFence = null;
    await isar.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test(
    'already mirrored workflow reopen never invents another revision',
    () async {
      final expected = JobModuleSaveBaseline.capture(baseline),
          mirrored = serverModule();
      await put(mirrored);
      final before = jsonEncode(jobModuleLocalSnapshot(await local()));
      final adopted = await repository.applyWorkflowModuleReopenProjection(
        serverModule(),
        actor: actor,
        expectedLocal: expected,
      );
      expect(adopted.version, 5);
      expect(jsonEncode(jobModuleLocalSnapshot(await local())), before);
    },
  );
  test(
    'server-owned version and time are copied without increment or clock replacement',
    () async {
      final adopted = await repository.applyWorkflowModuleReopenProjection(
        serverModule(),
        actor: actor,
        expectedLocal: JobModuleSaveBaseline.capture(baseline),
      );
      expect(adopted.version, 5);
      expect(adopted.updatedAt, appliedAt);
      expect(adopted.jobExecutionLocalId, 91);
      expect(adopted.isSynced, isTrue);
    },
  );
  test(
    'dirty local work survives accepted reopen with original raw bytes',
    () async {
      final dirty = copyJobModuleForEditing(baseline)
        ..version = 5
        ..isSynced = false
        ..draftNote = 'Fresh offline finding'
        ..responsesJson = ' {"inspection":"unfinished"} ';
      await put(dirty);
      final before = jsonEncode(jobModuleLocalSnapshot(await local()));
      await expectLater(
        repository.applyWorkflowModuleReopenProjection(
          serverModule(),
          actor: actor,
          expectedLocal: JobModuleSaveBaseline.capture(baseline),
        ),
        throwsStateError,
      );
      expect(jsonEncode(jobModuleLocalSnapshot(await local())), before);
    },
  );
  for (final kind in ['later', 'same-version-contradiction']) {
    test('$kind local state is never overwritten', () async {
      final changed = serverModule(version: kind == 'later' ? 6 : 5)
        ..draftNote = 'Other confirmed work';
      await put(changed);
      final before = jsonEncode(jobModuleLocalSnapshot(await local()));
      await expectLater(
        repository.applyWorkflowModuleReopenProjection(
          serverModule(),
          actor: actor,
          expectedLocal: JobModuleSaveBaseline.capture(baseline),
        ),
        throwsStateError,
      );
      expect(jsonEncode(jobModuleLocalSnapshot(await local())), before);
    });
  }
  test(
    'mirror transaction wins while adoption is queued; no stale pretransaction read',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final writer = isar.writeTxn(() async {
        await isar.jobModuleInstances.put(serverModule(version: 6));
        entered.complete();
        await release.future;
      });
      await entered.future;
      final adoption = repository.applyWorkflowModuleReopenProjection(
        serverModule(),
        actor: actor,
        expectedLocal: JobModuleSaveBaseline.capture(baseline),
      );
      final refusal = expectLater(adoption, throwsStateError);
      release.complete();
      await writer;
      await refusal;
      expect((await local()).version, 6);
    },
  );
  test('actor change at transaction commit rolls back the adoption', () async {
    var fences = 0;
    transactionFence = () {
      if (++fences == 4) currentActor = other;
    };
    await expectLater(
      repository.applyWorkflowModuleReopenProjection(
        serverModule(),
        actor: actor,
        expectedLocal: JobModuleSaveBaseline.capture(baseline),
      ),
      throwsStateError,
    );
    expect((await local()).version, 4);
  });
  test(
    'same revision mirror with different evidence requires reconciliation',
    () async {
      final contradiction = copyJobModuleForEditing(baseline)
        ..draftNote = 'Contradictory same revision';
      final result = await repository.applyModuleFromRemote(contradiction);
      expect(
        result.outcome,
        RemoteRecordApplyOutcome.cleanLocalReconciliationRequired,
      );
      expect((await local()).draftNote, baseline.draftNote);
      expect(
        (await repository.applyModuleFromRemote(
          copyJobModuleForEditing(baseline),
        )).outcome,
        RemoteRecordApplyOutcome.unchanged,
      );
    },
  );
  test(
    'fresh accepted receipt is settled before audit and module reads',
    () async {
      final saved = await prepare();
      afterRead = (collection) async {
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
      };
      final adopted = await controller().check(saved.submissionId);
      expect(adopted.version, 5);
      expect(dispatches, 1);
      expect(probes, 1);
      expect(reads, 2);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );
  test(
    'lost readback survives a real database restart and never resends accepted command',
    () async {
      final saved = await prepare();
      failRead = true;
      await expectLater(
        controller().check(saved.submissionId),
        throwsStateError,
      );
      final accepted = await store.read(saved.submissionId);
      expect(accepted!.state, DurableSubmissionState.acceptedPendingAdoption);
      expect((await local()).version, 4);
      await isar.close();
      await open();
      failRead = false;
      final restored = await controller().restore('module-7');
      expect(restored!.envelopeJson, saved.envelopeJson);
      expect(restored.receiptSha256, accepted.receiptSha256);
      final adopted = await controller().check(saved.submissionId);
      expect(adopted.version, 5);
      expect(dispatches, 1);
      expect(probes, 1);
    },
  );
  test(
    'later legitimate server state is adopted as current, never forced reopened',
    () async {
      final saved = await prepare();
      remote = serverModule(
        version: 6,
        status: JobModuleStatus.accepted,
      ).toMap();
      final adopted = await controller().check(saved.submissionId);
      expect(adopted.status, JobModuleStatus.accepted);
      expect(adopted.version, 6);
    },
  );
  test(
    'accepted request retains receipt while a new local edit waits',
    () async {
      final saved = await prepare();
      afterDispatch = () async {
        await put(
          copyJobModuleForEditing(baseline)
            ..isSynced = false
            ..draftNote = 'Keep this new draft',
        );
      };
      await expectLater(
        controller().check(saved.submissionId),
        throwsStateError,
      );
      expect((await local()).draftNote, 'Keep this new draft');
      expect((await local()).isSynced, isFalse);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    },
  );
  test(
    'account switch after acceptance retains receipt before stopping readback',
    () async {
      final saved = await prepare();
      afterDispatch = () async {
        currentActor = other;
      };
      await expectLater(
        controller().check(saved.submissionId),
        throwsStateError,
      );
      expect(reads, 0);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      currentActor = actor;
      afterDispatch = null;
      await controller().check(saved.submissionId);
      expect(dispatches, 1);
    },
  );
  test(
    'account switch during fresh server read prevents native adoption',
    () async {
      final saved = await prepare();
      afterRead = (collection) async {
        if (collection == 'job_modules') currentActor = other;
      };
      await expectLater(
        controller().check(saved.submissionId),
        throwsStateError,
      );
      expect((await local()).version, 4);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    },
  );
  for (final field in [
    'performedByUid',
    'reasonNotes',
    'timestamp',
    'beforeJson',
    'afterJson',
  ]) {
    test(
      'corrupt immutable audit $field holds original accepted receipt',
      () async {
        final saved = await prepare();
        if (field == 'beforeJson') {
          audit[field] = jsonEncode({
            ...baseline.toMap(),
            'jobExecutionFirestoreId': 'other-job',
          });
        } else if (field == 'afterJson') {
          audit[field] = jsonEncode({
            ...baseline.toMap(),
            'status': 'reopened',
            'isOpenForWork': true,
            'draftNote': 'invented',
          });
        } else {
          audit[field] = 'contradictory';
        }
        await expectLater(
          controller().check(saved.submissionId),
          throwsA(anything),
        );
        expect((await local()).version, 4);
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
      },
    );
  }
  for (final change in [
    'below',
    'first-actor',
    'first-reason',
    'first-time',
    'identity',
  ]) {
    test('contradictory server revision $change is never adopted', () async {
      final saved = await prepare();
      switch (change) {
        case 'below':
          remote['version'] = 4;
        case 'first-actor':
          remote['reopenedByUid'] = 'other';
        case 'first-reason':
          remote['reopenReason'] = 'other';
        case 'first-time':
          remote['reopenedAt'] = appliedAt
              .add(const Duration(seconds: 1))
              .toIso8601String();
        case 'identity':
          remote['jobExecutionFirestoreId'] = 'other-job';
      }
      await expectLater(
        controller().check(saved.submissionId),
        throwsA(anything),
      );
      expect((await local()).version, 4);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    });
  }
  test(
    'a second pending logical reopen cannot replace the saved envelope',
    () async {
      final saved = await prepare();
      await expectLater(prepare(), throwsA(isA<DurableSubmissionException>()));
      expect(
        (await controller().restore('module-7'))!.envelopeJson,
        saved.envelopeJson,
      );
      expect(dispatches, 0);
    },
  );
  for (final fixtureName in [
    'workflow_module_reopen_actual_handler',
    'workflow_module_reopen_firestore_handler',
  ]) {
    test(
      '$fixtureName actual producer receipt/audit/module survives native adoption',
      () async {
        final fixture =
            jsonDecode(
                  await File('test/fixtures/$fixtureName.json').readAsString(),
                )
                as Map<String, dynamic>;
        final command = fixture['command'] as Map<String, dynamic>;
        final before =
            JobModuleInstance.fromMap(
                _hydrateFirestoreFixture(fixture['beforeModule'])
                    as Map<String, dynamic>,
                'module-7',
              )
              ..id = baseline.id
              ..jobExecutionLocalId = 91
              ..isSynced = true;
        baseline = before;
        await put(before);
        final saved = await store.prepare(
          DurableSubmissionDraft(
            submissionId: command['commandId'],
            actorUid: actor.uid,
            requestId: command['commandId'],
            aggregateId: command['aggregateId'],
            resourceKey: WorkflowModuleReopenController.resource('module-7'),
            protocol: 'maintenanceWorkflow.v2',
            envelopeJson: jsonEncode({
              'protocolVersion': 2,
              'originActorUid': actor.uid,
              'command': command,
            }),
            displayMetadataJson: jsonEncode({
              'schemaVersion': 1,
              'module': before.toMap(),
              'local': jobModuleLocalSnapshot(before),
            }),
          ),
        );
        final actualController = WorkflowModuleReopenController(
          store: store,
          modules: repository,
          requireActor: () => currentActor,
          requireCapability: (uid) async {
            probes++;
          },
          gateway: _Gateway((envelope) async {
            dispatches++;
            expect(jsonDecode(envelope)['command'], command);
            return WorkflowCommandReceipt.fromMap(
              fixture['receipt'] as Map<String, dynamic>,
            );
          }),
          readDocument: (collection, id) async =>
              _hydrateFirestoreFixture(
                    collection == 'audit_logs'
                        ? fixture['audit']
                        : fixture['module'],
                  )
                  as Map<String, dynamic>,
        );
        final adopted = await actualController.check(saved.submissionId);
        expect(adopted.version, fixture['module']['version']);
        expect(
          adopted.reopenedAt!.toUtc().toIso8601String(),
          fixture['receipt']['appliedAt'],
        );
        expect(adopted.status, JobModuleStatus.reopened);
        expect(adopted.jobExecutionLocalId, 91);
        if (fixtureName.endsWith('firestore_handler')) {
          expect(adopted.createdAt.microsecondsSinceEpoch % 1000000, 123456);
          expect(
            (jsonDecode(fixture['audit']['beforeJson'])
                as Map)['updatedAt']['_nanoseconds'],
            654321000,
          );
          expect(fixture['audit']['beforeJson'], isA<String>());
        }
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.reconciled,
        );
        expect(dispatches, 1);
      },
    );
  }
  for (final malformed in <Object>[
    {'_seconds': 1, '_nanoseconds': 0, 'extra': true},
    {'_seconds': 1, 'nanoseconds': 0},
    {'_seconds': 1, '_nanoseconds': 0, 'seconds': 1, 'nanoseconds': 0},
    {'_seconds': 1.0, '_nanoseconds': 0},
    {'_seconds': 1, '_nanoseconds': -1000},
    {'_seconds': 1, '_nanoseconds': 1000000000},
    {'_seconds': 1, '_nanoseconds': 1},
    {'_seconds': 253402300800, '_nanoseconds': 0},
    {'_seconds': -62135596801, '_nanoseconds': 0},
    '2026-02-30T09:00:00.000Z',
    '2026-09-13T09:00:00.1234567Z',
  ]) {
    test(
      'malformed or lossy original timestamp $malformed retains accepted receipt',
      () async {
        final saved = await prepare();
        final before =
            jsonDecode(audit['beforeJson'] as String) as Map<String, dynamic>;
        before['createdAt'] = malformed;
        audit['beforeJson'] = jsonEncode(before);
        audit['afterJson'] = jsonEncode({
          ...before,
          'status': 'reopened',
          'isOpenForWork': true,
        });
        await expectLater(
          controller().check(saved.submissionId),
          throwsA(isA<StateError>()),
        );
        expect((await local()).version, 4);
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
      },
    );
  }
  for (final boundary in ['audit', 'current']) {
    test(
      'native nanosecond drift at $boundary is not silently truncated',
      () async {
        final saved = await prepare();
        if (boundary == 'audit') {
          audit['timestamp'] = Timestamp(
            appliedAt.millisecondsSinceEpoch ~/ 1000,
            1,
          );
        } else {
          remote['createdAt'] = Timestamp(
            baseline.createdAt.millisecondsSinceEpoch ~/ 1000,
            1,
          );
        }
        await expectLater(
          controller().check(saved.submissionId),
          throwsA(isA<StateError>()),
        );
        expect((await local()).version, 4);
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
      },
    );
  }
  test(
    'exact newer-version refusal remains retained across restart and requires new reviewed attempt',
    () async {
      final saved = await prepare();
      afterDispatch = () async {
        throw const WorkflowException(
          WorkflowErrorCode.versionConflict,
          'Changed',
          details: {
            'workflowCode': 'workflow-version-conflict',
            'expectedVersion': 10,
            'actualVersion': 11,
          },
        );
      };
      await expectLater(
        controller().check(saved.submissionId),
        throwsStateError,
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.rejected,
      );
      expect((await local()).version, 4);
      expect(reads, 0);
      await isar.close();
      await open();
      expect(await controller().restore('module-7'), isNull);
      final old = await store.read(saved.submissionId);
      expect(old!.envelopeJson, saved.envelopeJson);
      expect(dispatches, 1);
      // An explicit new operator review, using the fresh workflow revision.
      final next = await controller().prepare(
        actorUid: actor.uid,
        executionId: 'job-7',
        workflowVersion: 11,
        reason: 'Reinspect seal',
        baseline: await local(),
      );
      expect(next.requestId, isNot(saved.requestId));
      expect(dispatches, 1);
      expect(
        (await store.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
    },
  );
  for (final error in [
    const WorkflowException(WorkflowErrorCode.aborted, 'Aborted'),
    const WorkflowException(WorkflowErrorCode.unavailable, 'Network'),
    const WorkflowException(WorkflowErrorCode.permissionDenied, 'Actor'),
    const WorkflowException(
      WorkflowErrorCode.versionConflict,
      'Missing detail',
    ),
    const WorkflowException(
      WorkflowErrorCode.versionConflict,
      'Wrong expected',
      details: {
        'workflowCode': 'workflow-version-conflict',
        'expectedVersion': 9,
        'actualVersion': 11,
      },
    ),
    const WorkflowException(
      WorkflowErrorCode.versionConflict,
      'Equal actual',
      details: {
        'workflowCode': 'workflow-version-conflict',
        'expectedVersion': 10,
        'actualVersion': 10,
      },
    ),
    const WorkflowException(
      WorkflowErrorCode.versionConflict,
      'Lower actual',
      details: {
        'workflowCode': 'workflow-version-conflict',
        'expectedVersion': 10,
        'actualVersion': 9,
      },
    ),
    const WorkflowException(
      WorkflowErrorCode.versionConflict,
      'String version',
      details: {
        'workflowCode': 'workflow-version-conflict',
        'expectedVersion': 10,
        'actualVersion': '11',
      },
    ),
    const WorkflowException(
      WorkflowErrorCode.versionConflict,
      'Wrong wire code',
      details: {
        'workflowCode': 'command-idempotency-conflict',
        'expectedVersion': 10,
        'actualVersion': 11,
      },
    ),
  ]) {
    test(
      'ambiguous refusal ${error.message} retains the original pending identity',
      () async {
        final saved = await prepare();
        afterDispatch = () async {
          throw error;
        };
        await expectLater(
          controller().check(saved.submissionId),
          throwsA(isA<WorkflowException>()),
        );
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.uncertain,
        );
        expect(
          (await controller().restore('module-7'))!.requestId,
          saved.requestId,
        );
        expect(dispatches, 1);
        expect((await local()).version, 4);
      },
    );
  }
}
