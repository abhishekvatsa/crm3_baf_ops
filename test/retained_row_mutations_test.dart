import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as database;
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late RetainedRowMutations controller;
  late DurableSubmissionRepository store;
  late _Gateway gateway;
  var uid = 'actor-a';
  var project = 'demo-queue';
  final instant = DateTime.utc(2026, 9, 20, 10);
  AppUser actor(String value) => AppUser(
    uid: value,
    name: value,
    email: '$value@example.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: instant,
  );

  Future<void> open() async {
    db = await Isar.open(
      [
        DurableSubmissionRecordSchema,
        AbnormalityTypeSchema,
        JobTemplateSchema,
        JobExecutionSchema,
      ],
      directory: directory.path,
      name: 'retained-row-ownership',
      inspector: false,
    );
    database.isar = db;
    store = DurableSubmissionRepository(db);
    controller = RetainedRowMutations(
      store: store,
      projectId: () => project,
      currentActorUid: () => uid,
      gateway: gateway,
    );
  }

  Future<void> reopen() async {
    await db.close();
    await open();
  }

  setUp(() async {
    uid = 'actor-a';
    project = 'demo-queue';
    gateway = _Gateway();
    directory = await Directory.systemTemp.createTemp('cf01_native_');
    await open();
  });
  tearDown(() async {
    if (db.isOpen) await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  dynamic fixture(RetainedRowKind kind) => switch (kind) {
    RetainedRowKind.abnormalityType => AbnormalityType.seedRaCoilColour(
      createdByUid: uid,
      createdByName: uid,
    )..firestoreId = 'type-one',
    RetainedRowKind.legacyTemplate =>
      JobTemplate()
        ..firestoreId = 'template-one'
        ..jobName = 'DEV inspection'
        ..applicableAssetType = AssetType.furnace
        ..createdAt = instant
        ..updatedAt = instant
        ..createdByUid = uid
        ..createdByName = uid,
    RetainedRowKind.executionWork =>
      JobExecution()
        ..firestoreId = 'execution-one'
        ..templateFirestoreId = 'template-one'
        ..assetType = AssetType.furnace
        ..assetNumber = 1
        ..assignedByUid = uid
        ..assignedByName = uid
        ..createdAt = instant
        ..updatedAt = instant
        ..isSynced = true,
  };
  Future<dynamic> read(RetainedRowKind kind) async => switch (kind) {
    RetainedRowKind.abnormalityType =>
      await db.abnormalityTypes.where().findFirst(),
    RetainedRowKind.legacyTemplate => await db.jobTemplates.where().findFirst(),
    RetainedRowKind.executionWork => await db.jobExecutions.where().findFirst(),
  };
  Future<void> put(RetainedRowKind kind, dynamic row) async {
    await db.writeTxn(() async {
      switch (kind) {
        case RetainedRowKind.abnormalityType:
          await db.abnormalityTypes.put(row as AbnormalityType);
        case RetainedRowKind.legacyTemplate:
          await db.jobTemplates.put(row as JobTemplate);
        case RetainedRowKind.executionWork:
          await db.jobExecutions.put(row as JobExecution);
      }
    });
  }

  Future<void> save(RetainedRowKind kind, dynamic row) async {
    final user = actor(uid);
    switch (kind) {
      case RetainedRowKind.abnormalityType:
        await IsarAbnormalityRepository(
          retainedMutations: controller,
        ).saveType(row as AbnormalityType, actor: user);
      case RetainedRowKind.legacyTemplate:
        await IsarPlannedRepository(
          retainedMutations: controller,
        ).saveTemplate(row as JobTemplate, actor: user);
      case RetainedRowKind.executionWork:
        await IsarPlannedRepository(
          retainedMutations: controller,
        ).saveExecution(row as JobExecution, actor: user);
    }
  }

  Future<dynamic> queued(RetainedRowKind kind) async {
    final row = fixture(kind);
    if (kind == RetainedRowKind.executionWork) {
      await put(kind, row);
      row.remarks = 'A saved offline inspection';
    }
    await save(kind, row);
    return await read(kind);
  }

  for (final kind in RetainedRowKind.values) {
    test(
      '${kind.name}: native A→B→restart→A preserves intent and adopts once',
      () async {
        var row = await queued(kind);
        final original = RetainedRowMutations.wire(row);
        final intent = (await store.listForActor('actor-a')).single;
        expect(intent.actorUid, 'actor-a');
        expect(intent.resourceKey, contains('demo-queue:${kind.collection}'));
        final frozen = intent.envelopeJson;
        uid = 'actor-b';
        await expectLater(
          controller.synchronize(kind, row),
          throwsA(isA<DurableSubmissionException>()),
        );
        await expectLater(
          save(kind, row),
          throwsA(isA<DurableSubmissionException>()),
        );
        expect(gateway.calls, 0);
        await reopen();
        row = await read(kind);
        expect(row.isSynced, false);
        expect(RetainedRowMutations.wire(row), original);
        await expectLater(
          controller.synchronize(kind, row),
          throwsA(isA<DurableSubmissionException>()),
        );
        expect((await store.read(intent.submissionId))!.envelopeJson, frozen);
        uid = 'actor-a';
        await controller.synchronize(kind, row);
        expect(gateway.calls, 1);
        expect(gateway.applied, 1);
        expect((await read(kind)).isSynced, true);
        expect(
          (await store.read(intent.submissionId))!.state,
          DurableSubmissionState.reconciled,
        );
        await controller.check(intent.submissionId, kind: kind);
        expect(gateway.calls, 1);
      },
    );

    test(
      '${kind.name}: legacy dirty evidence survives restart without inferred owner',
      () async {
        final row = fixture(kind)..isSynced = false;
        await put(kind, row);
        final before = RetainedRowMutations.wire(row);
        await expectLater(
          controller.synchronize(kind, row),
          throwsA(isA<DurableSubmissionException>()),
        );
        await reopen();
        final saved = await store.listForAdministrativeReview(
          requireReviewer: () {},
        );
        expect(saved.single.actorUid, isNull);
        expect(saved.single.state, DurableSubmissionState.needsReview);
        expect(
          jsonDecode(
            utf8.decode(base64Decode(saved.single.legacySourceBase64!)),
          ),
          before,
        );
        expect((await read(kind)).isSynced, false);
        expect(gateway.calls, 0);
      },
    );

    test(
      '${kind.name}: lost response replays frozen request after restart',
      () async {
        final row = await queued(kind);
        gateway.loseNext = true;
        await expectLater(controller.synchronize(kind, row), throwsStateError);
        expect(gateway.applied, 1);
        await reopen();
        await controller.synchronize(kind, await read(kind));
        expect(gateway.calls, 2);
        expect(gateway.applied, 1);
        expect((await read(kind)).isSynced, true);
      },
    );

    test(
      '${kind.name}: accepted receipt cannot acknowledge a concurrent local revision',
      () async {
        final row = await queued(kind);
        gateway.beforeReturn = () async {
          final changed = await read(kind);
          changed.version += 1;
          await put(kind, changed);
        };
        await expectLater(
          controller.synchronize(kind, row),
          throwsA(isA<DurableSubmissionException>()),
        );
        expect((await read(kind)).version, row.version + 1);
        expect((await read(kind)).isSynced, false);
        expect(
          (await store.listForActor(uid)).single.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
      },
    );
  }

  test(
    'accepted evidence survives an in-flight account replacement without local acknowledgement',
    () async {
      final row = await queued(RetainedRowKind.abnormalityType);
      final intent = (await store.listForActor(uid)).single;
      gateway.beforeReturn = () async {
        uid = 'actor-b';
      };
      await expectLater(
        controller.synchronize(RetainedRowKind.abnormalityType, row),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect((await read(RetainedRowKind.abnormalityType)).isSynced, false);
      expect(
        (await store.read(intent.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await reopen();
      await expectLater(
        controller.check(
          intent.submissionId,
          kind: RetainedRowKind.abnormalityType,
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      uid = 'actor-a';
      await controller.check(
        intent.submissionId,
        kind: RetainedRowKind.abnormalityType,
      );
      expect(gateway.calls, 1);
      expect((await read(RetainedRowKind.abnormalityType)).isSynced, true);
    },
  );

  test(
    'sticky authority loss prevents adoption even if same UID returns before receipt',
    () async {
      final row = await queued(RetainedRowKind.legacyTemplate);
      var allowed = true;
      final guard = SyncRunGuard(() {
        if (!allowed) {
          throw const SyncRunAborted('account-or-authority-changed');
        }
      });
      gateway.beforeReturn = () async {
        allowed = false;
        expect(guard.checkCurrent, throwsA(isA<SyncRunAborted>()));
        allowed = true;
      };
      await expectLater(
        controller.synchronize(
          RetainedRowKind.legacyTemplate,
          row,
          runGuard: guard,
        ),
        throwsA(isA<SyncRunAborted>()),
      );
      expect((await read(RetainedRowKind.legacyTemplate)).isSynced, false);
      expect(
        (await store.listForActor(uid)).single.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await controller.synchronize(
        RetainedRowKind.legacyTemplate,
        await read(RetainedRowKind.legacyTemplate),
        runGuard: SyncRunGuard(() {}),
      );
      expect(gateway.calls, 1);
    },
  );

  test(
    'another account cannot replace pending execution work by changing lifecycle flags',
    () async {
      await queued(RetainedRowKind.executionWork);
      uid = 'actor-b';
      final altered = await read(RetainedRowKind.executionWork);
      altered.isCompleted = true;
      await expectLater(
        save(RetainedRowKind.executionWork, altered),
        throwsA(isA<DurableSubmissionException>()),
      );
      final current = await read(RetainedRowKind.executionWork);
      expect(current.isCompleted, false);
      expect(current.remarks, 'A saved offline inspection');
      expect(current.isSynced, false);
    },
  );

  test(
    'account replacement while preparing a save rolls back row and frozen intent',
    () async {
      final row = fixture(RetainedRowKind.abnormalityType);
      await expectLater(
        controller.save(
          kind: RetainedRowKind.abnormalityType,
          actor: actor(uid),
          record: row,
          normalize: (_) {
            uid = 'actor-b';
          },
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(await db.abnormalityTypes.count(), 0);
      expect(await store.listForActor('actor-a'), isEmpty);
    },
  );

  test(
    'new legacy assignment creation refuses before saving, directing caller to published assignment',
    () async {
      final row = fixture(RetainedRowKind.executionWork);
      await expectLater(
        save(RetainedRowKind.executionWork, row),
        throwsStateError,
      );
      expect(await db.jobExecutions.count(), 0);
      expect(await store.listForActor(uid), isEmpty);
    },
  );

  test(
    'different workflow receipt marker cannot acknowledge retained work',
    () async {
      final row = await queued(RetainedRowKind.abnormalityType);
      gateway.resultKey = 'another-command-applied';
      await expectLater(
        controller.synchronize(RetainedRowKind.abnormalityType, row),
        throwsStateError,
      );
      expect((await read(RetainedRowKind.abnormalityType)).isSynced, false);
      expect(
        (await store.listForActor(uid)).single.state,
        DurableSubmissionState.uncertain,
      );
    },
  );

  test(
    'caller mutation after envelope freeze cannot change the atomically stored row',
    () async {
      final row = fixture(RetainedRowKind.legacyTemplate) as JobTemplate;
      row.assignedAgencies = ['MECH'];
      final racingStore = _AfterFreezeStore(db, () {
        row.assignedAgencies[0] = 'UNSAVED CHANGE';
      });
      final frozenController = RetainedRowMutations(
        store: racingStore,
        projectId: () => project,
        currentActorUid: () => uid,
        gateway: gateway,
      );
      await IsarPlannedRepository(
        retainedMutations: frozenController,
      ).saveTemplate(row, actor: actor(uid));
      expect(row.assignedAgencies, ['UNSAVED CHANGE']);
      final saved = await read(RetainedRowKind.legacyTemplate);
      expect(saved.assignedAgencies, ['MECH']);
      final intent = (await racingStore.listForActor(uid)).single;
      expect(
        intent.envelope['command']['payload']['record']['assignedAgencies'],
        ['MECH'],
      );
      await frozenController.synchronize(RetainedRowKind.legacyTemplate, saved);
      expect((await read(RetainedRowKind.legacyTemplate)).isSynced, true);
    },
  );

  for (final kind in [
    RetainedRowKind.abnormalityType,
    RetainedRowKind.legacyTemplate,
  ]) {
    test(
      '${kind.name}: changing Firestore identity cannot overwrite another numeric Isar row',
      () async {
        final original = fixture(kind)..isSynced = true;
        await put(kind, original);
        final before = RetainedRowMutations.wire(await read(kind));
        final aliased = await read(kind);
        aliased.firestoreId = 'another-document';
        await expectLater(
          save(kind, aliased),
          throwsA(
            isA<DurableSubmissionException>().having(
              (error) => error.code,
              'identity conflict',
              'local-identity-conflict',
            ),
          ),
        );
        expect(RetainedRowMutations.wire(await read(kind)), before);
        expect((await read(kind)).isSynced, true);
        expect(await store.listForActor(uid), isEmpty);
      },
    );
  }

  test(
    'project switch refuses retained dispatch before any network call',
    () async {
      final row = await queued(RetainedRowKind.abnormalityType);
      final intent = (await store.listForActor(uid)).single;
      project = 'demo-other';
      await expectLater(
        controller.check(
          intent.submissionId,
          kind: RetainedRowKind.abnormalityType,
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(gateway.calls, 0);
      expect((await read(RetainedRowKind.abnormalityType)).isSynced, false);
      expect(
        RetainedRowMutations.wire(await read(RetainedRowKind.abnormalityType)),
        RetainedRowMutations.wire(row),
      );
    },
  );

  test(
    'atomic save rolls back both intent and row on serialization failure',
    () async {
      final row = fixture(RetainedRowKind.abnormalityType) as AbnormalityType;
      await expectLater(
        controller.save(
          kind: RetainedRowKind.abnormalityType,
          actor: actor(uid),
          record: row,
          normalize: (_) {
            row.title = '';
          },
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await db.abnormalityTypes.count(), 0);
      expect(await store.listForActor(uid), isEmpty);
    },
  );
}

class _Gateway implements OriginBoundWorkflowCommandGateway {
  int calls = 0;
  int applied = 0;
  bool loseNext = false;
  String resultKey = 'retained-queue-mutation-applied';
  Future<void> Function()? beforeReturn;
  final receipts = <String, WorkflowCommandReceipt>{};
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    calls++;
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final command = Map<String, dynamic>.from(envelope['command'] as Map);
    final payload = Map<String, dynamic>.from(command['payload'] as Map);
    final kind = RetainedRowKind.values.singleWhere(
      (k) => k.commandType.name == command['commandType'],
    );
    final id = command['commandId'] as String;
    final record = Map<String, dynamic>.from(payload['record'] as Map);
    final receipt = receipts.putIfAbsent(id, () {
      applied++;
      return WorkflowCommandReceipt(
        commandId: id,
        resultKey: resultKey,
        aggregateVersion: record['version'] as int,
        appliedAt: DateTime.utc(2026, 9, 27, 11),
        result: {
          'collection': kind.collection,
          'recordId': command['aggregateId'],
          'record': record,
        },
      );
    });
    if (loseNext) {
      loseNext = false;
      throw StateError('Simulated lost server reply');
    }
    await beforeReturn?.call();
    return receipt;
  }
}

class _AfterFreezeStore extends DurableSubmissionRepository {
  _AfterFreezeStore(super.isar, this.afterFreeze);
  final void Function() afterFreeze;

  @override
  Future<DurableSubmission> prepareAtomically({
    required Future<DurableSubmissionDraft> Function() prepareDraft,
    Future<void> Function()? persistProjection,
  }) => super.prepareAtomically(
    prepareDraft: () async {
      final draft = await prepareDraft();
      afterFreeze();
      return draft;
    },
    persistProjection: persistProjection,
  );
}
