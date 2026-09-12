import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

class _NoRemoteAudit extends AuditRepository {
  @override
  Future<void> log(AuditEvent event, {bool syncToRemote = true}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late IsarJobModuleRepository repository;
  late JobModuleDraftRecovery recovery;
  late int moduleId;
  late int parentId;
  final actor = AppUser(
    uid: 'editor-1',
    name: 'Editor',
    email: 'editor@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  final other = AppUser(
    uid: 'editor-2',
    name: 'Other',
    email: 'other@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );

  Future<void> open({bool audits = true}) async {
    isar = await Isar.open(
      [
        JobModuleInstanceSchema,
        JobExecutionSchema,
        if (audits) AuditEventSchema,
      ],
      directory: directory.path,
      name: 'module_save_conflict',
      inspector: false,
    );
    repository = IsarJobModuleRepository(auditRepository: _NoRemoteAudit());
    recovery = JobModuleDraftRecovery(repository: repository);
  }

  Future<void> reopen() async {
    await isar.close();
    await open();
  }

  Future<JobModuleInstance> read() async =>
      (await isar.jobModuleInstances.get(moduleId))!;

  ComponentAction action(String id) => ComponentAction(
    id: id,
    asset: 'Base 7',
    component: 'Seal',
    actionType: ActionType.inspection,
    remarks: id,
    createdAt: DateTime.utc(2026, 9, 12, 10),
    performedBy: 'Editor',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('module_cas_');
    await open();
    final parent = JobExecution()
      ..firestoreId = 'job-7'
      ..templateFirestoreId = 'template-7'
      ..assetType = AssetType.base
      ..assetNumber = 7
      ..createdAt = DateTime.utc(2026, 9, 12)
      ..updatedAt = DateTime.utc(2026, 9, 12);
    final module = JobModuleInstance()
      ..firestoreId = 'module-7'
      ..jobExecutionFirestoreId = 'job-7'
      ..moduleTitle = 'Seal inspection'
      ..discipline = JobModuleDiscipline.mechanical
      ..createdAt = DateTime.utc(2026, 9, 12)
      ..updatedAt = DateTime.utc(2026, 9, 12)
      ..status = JobModuleStatus.draftSaved
      ..version = 4
      ..isSynced = true;
    await isar.writeTxn(() async {
      parentId = await isar.jobExecutions.put(parent);
      moduleId = await isar.jobModuleInstances.put(module);
    });
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('preimage covers every actual native schema property', () async {
    expect(jobModuleLocalSnapshot(await read()).keys.toSet(), {
      ...JobModuleInstanceSchema.properties.keys,
      'id',
    });
  });

  test(
    'editor clone preserves raw governance and local fields without list aliases',
    () async {
      final current = await read()
        ..laneKey = null
        ..workflowLaneFirestoreId = null
        ..templateName = '  original raw title  '
        ..tags = [' one '];
      final copy = copyJobModuleForEditing(current);
      expect(jobModuleLocalSnapshot(copy), jobModuleLocalSnapshot(current));
      copy.tags.add('two');
      expect(current.tags, [' one ']);
    },
  );

  test(
    'two real editors retain winner and losing actions/responses across restart',
    () async {
      final a = await read();
      final b = await read();
      final aBaseline = JobModuleSaveBaseline.capture(a);
      final bBaseline = JobModuleSaveBaseline.capture(b);
      b.actions = [action('B')];
      b.responses = [
        FieldResponse(
          key: 'seal',
          fieldLabel: 'Seal',
          fieldType: FieldType.text,
          value: 'B checked',
        ),
      ];
      await repository.saveModule(b, actor: actor, expectedBaseline: bBaseline);
      expect(b.version, 5);
      a.actions = [action('A')];
      a.responses = [
        FieldResponse(
          key: 'seal',
          fieldLabel: 'Seal',
          fieldType: FieldType.text,
          value: 'A checked',
        ),
      ];
      await expectLater(
        repository.saveModule(a, actor: actor, expectedBaseline: aBaseline),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).actions.single.id, 'B');
      expect((await read()).responses.single.value, 'B checked');
      expect(
        a.version,
        4,
        reason: 'Refused candidate is not normalized as if saved.',
      );
      await reopen();
      final drafts = await recovery.list(actor: actor, moduleLocalId: moduleId);
      expect(drafts, hasLength(1));
      final evidence = drafts.single.evidence;
      expect(evidence['reviewed']['version'], 4);
      expect(evidence['current']['version'], 5);
      expect(
        jsonDecode(evidence['attempted']['actionsJson']).single['id'],
        'A',
      );
      expect(
        (await recovery.list(actor: other, moduleLocalId: moduleId)),
        isEmpty,
      );
      await expectLater(
        recovery.review(actor: other, saved: drafts.single),
        throwsStateError,
      );
    },
  );

  test(
    'same revision and time with contradictory raw content still conflicts',
    () async {
      final stale = await read();
      final baseline = JobModuleSaveBaseline.capture(stale);
      final newer = await read()
        ..draftNote = 'newer raw note';
      await isar.writeTxn(() => isar.jobModuleInstances.put(newer));
      stale.draftNote = 'losing note';
      await expectLater(
        repository.saveModule(stale, actor: actor, expectedBaseline: baseline),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).draftNote, 'newer raw note');
      expect((await read()).version, 4);
    },
  );

  test(
    'full raw preimage detects whitespace change hidden by wire normalization',
    () async {
      final stale = await read();
      final baseline = JobModuleSaveBaseline.capture(stale);
      final newer = await read()
        ..draftNote = '  ';
      await isar.writeTxn(() => isar.jobModuleInstances.put(newer));
      stale.draftNote = 'losing';
      await expectLater(
        repository.saveModule(stale, actor: actor, expectedBaseline: baseline),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).draftNote, '  ');
    },
  );

  for (final status in [
    JobModuleStatus.accepted,
    JobModuleStatus.submitted,
    JobModuleStatus.notApplicable,
  ]) {
    test(
      'current $status module cannot be overwritten even with matching baseline',
      () async {
        if (status == JobModuleStatus.notApplicable) {
          await repository.markModuleNotApplicable(moduleId, actor: actor, reason: 'Not required for this job');
        } else {
          await repository.submitModule(moduleId, actor: actor);
          if (status == JobModuleStatus.accepted) {
            await repository.acceptModule(moduleId, actor: actor);
          }
        }
        final current = await read();
        final baseline = JobModuleSaveBaseline.capture(current);
        current.status = JobModuleStatus.draftSaved;
        current.draftNote = 'retained work';
        await expectLater(
          repository.saveModule(
            current,
            actor: actor,
            expectedBaseline: baseline,
          ),
          throwsA(isA<JobModuleSaveConflict>()),
        );
        expect((await read()).status, status);
        expect(
          await recovery.list(actor: actor, moduleLocalId: moduleId),
          hasLength(1),
        );
      },
    );
  }

  for (final state in [
    'deleted-module',
    'completed-parent',
    'cancelled-parent',
    'deleted-parent',
    'missing-parent',
  ]) {
    test('$state retains the attempted draft and current lifecycle', () async {
      final draft = await read();
      final baseline = JobModuleSaveBaseline.capture(draft);
      await isar.writeTxn(() async {
        if (state == 'deleted-module') {
          final current = await read()
            ..isDeleted = true
            ..deletedAt = DateTime.utc(2026, 9, 13);
          await isar.jobModuleInstances.put(current);
        } else if (state == 'missing-parent') {
          await isar.jobExecutions.delete(parentId);
        } else {
          final parent = (await isar.jobExecutions.get(parentId))!;
          parent.isCompleted = state == 'completed-parent';
          parent.isCancelled = state == 'cancelled-parent';
          parent.isDeleted = state == 'deleted-parent';
          parent.completedAt = parent.isCompleted ? DateTime.utc(2026, 9, 13) : null;
          parent.cancelledAt = parent.isCancelled ? DateTime.utc(2026, 9, 13) : null;
          parent.deletedAt = parent.isDeleted ? DateTime.utc(2026, 9, 13) : null;
          await isar.jobExecutions.put(parent);
        }
      });
      draft.draftNote = 'keep this work';
      await expectLater(
        repository.saveModule(draft, actor: actor, expectedBaseline: baseline),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).draftNote, isNull);
      await reopen();
      final saved = (await recovery.list(
        actor: actor,
        moduleLocalId: moduleId,
      )).single;
      expect(saved.evidence['attempted']['draftNote'], 'keep this work');
      final review = await recovery.review(actor: actor, saved: saved);
      expect(review.blockingReason, isNotNull);
    });
  }

  test(
    'missing explicit baseline cannot turn a stale update into creation',
    () async {
      final draft = await read()
        ..draftNote = 'no baseline';
      await expectLater(
        repository.saveModule(draft, actor: actor),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).version, 4);
      expect(
        (await recovery.list(
          actor: actor,
          moduleLocalId: moduleId,
        )).single.evidence['attempted']['draftNote'],
        'no baseline',
      );
    },
  );

  test(
    'pull adoption while editor stays open is detected with real repository apply',
    () async {
      final stale = await read();
      final baseline = JobModuleSaveBaseline.capture(stale);
      final remote = await read()
        ..version = 5
        ..updatedAt = DateTime.utc(2026, 9, 13)
        ..draftNote = 'adopted from server'
        ..actions = [action('remote')];
      await repository.applyModuleFromRemote(remote);
      stale.draftNote = 'unsaved local';
      await expectLater(
        repository.saveModule(stale, actor: actor, expectedBaseline: baseline),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).actions.single.id, 'remote');
      expect((await read()).draftNote, 'adopted from server');
    },
  );

  Future<JobModuleSavedDraft> makeConflict({String losing = 'losing'}) async {
    final stale = await read();
    final baseline = JobModuleSaveBaseline.capture(stale);
    final winner = await read()
      ..draftNote = 'winner';
    await repository.saveModule(
      winner,
      actor: actor,
      expectedBaseline: baseline,
    );
    stale.draftNote = losing;
    await expectLater(
      repository.saveModule(stale, actor: actor, expectedBaseline: baseline),
      throwsA(isA<JobModuleSaveConflict>()),
    );
    return (await recovery.list(actor: actor, moduleLocalId: moduleId)).first;
  }

  test(
    'explicit reviewed recovery uses fresh revision, retains original, and audits atomically',
    () async {
      await makeConflict();
      await reopen();
      final saved = (await recovery.list(
        actor: actor,
        moduleLocalId: moduleId,
      )).single;
      final review = await recovery.review(actor: actor, saved: saved);
      expect(review.current.draftNote, 'winner');
      final applied = await recovery.apply(actor: actor, review: review);
      expect(applied.version, 6);
      expect((await read()).draftNote, 'losing');
      expect(
        await recovery.list(actor: actor, moduleLocalId: moduleId),
        hasLength(1),
      );
      final resolutions = await isar.auditEvents
          .filter()
          .entityTypeEqualTo('planned_job_module_edit_conflict_resolved')
          .findAll();
      expect(resolutions, hasLength(1));
      expect(resolutions.single.entityId, saved.conflictId);
      await reopen();
      expect((await read()).draftNote, 'losing');
      expect(
        await isar.auditEvents
            .filter()
            .entityTypeEqualTo('planned_job_module_edit_conflict_resolved')
            .count(),
        1,
      );
    },
  );

  test(
    'edit while recovery review is open cannot overwrite new state',
    () async {
      final saved = await makeConflict();
      final review = await recovery.review(actor: actor, saved: saved);
      final newer = await read();
      final baseline = JobModuleSaveBaseline.capture(newer);
      newer.draftNote = 'third editor';
      await repository.saveModule(
        newer,
        actor: actor,
        expectedBaseline: baseline,
      );
      await expectLater(
        recovery.apply(actor: actor, review: review),
        throwsA(isA<JobModuleSaveConflict>()),
      );
      expect((await read()).draftNote, 'third editor');
      expect(
        await recovery.list(actor: actor, moduleLocalId: moduleId),
        hasLength(2),
      );
      expect(
        await isar.auditEvents
            .filter()
            .entityTypeEqualTo('planned_job_module_edit_conflict_resolved')
            .count(),
        0,
      );
    },
  );

  test(
    'large exact conflict evidence is chunked below existing audit Rules caps',
    () async {
      final large = List.filled(32000, 'quote " and unicode π ').join();
      final saved = await makeConflict(losing: large);
      await reopen();
      final restored = (await recovery.list(
        actor: actor,
        moduleLocalId: moduleId,
      )).single;
      expect(restored.evidence['attempted']['draftNote'], large);
      final events = await isar.auditEvents
          .filter()
          .entityIdEqualTo(saved.conflictId)
          .findAll();
      expect(events.length, greaterThan(2));
      for (final event in events) {
        expect(event.afterJson!.length, lessThanOrEqualTo(20000));
        expect(event.performedByUid, actor.uid);
        expect(event.isSynced, isFalse);
      }
    },
  );

  test(
    'missing or corrupt conflict chunks fail closed without discarding evidence',
    () async {
      final saved = await makeConflict();
      final part = (await isar.auditEvents
          .filter()
          .entityTypeEqualTo('planned_job_module_edit_conflict_part')
          .findFirst())!;
      await isar.writeTxn(() async {
        final payload = part.after!;
        payload['bytesBase64'] = base64Encode(utf8.encode('changed'));
        part.after = payload;
        await isar.auditEvents.put(part);
      });
      await expectLater(
        recovery.list(actor: actor, moduleLocalId: moduleId),
        throwsStateError,
      );
      expect((await read()).draftNote, 'winner');
      expect(
        await isar.auditEvents
            .filter()
            .entityIdEqualTo(saved.conflictId)
            .count(),
        greaterThan(0),
      );
    },
  );

  test(
    'unavailable conflict collection never permits the rejected business write',
    () async {
      final stale = await read();
      final baseline = JobModuleSaveBaseline.capture(stale);
      final winner = await read()
        ..draftNote = 'winner';
      await repository.saveModule(
        winner,
        actor: actor,
        expectedBaseline: baseline,
      );
      await isar.close();
      await open(audits: false);
      stale.draftNote = 'must stay in editor if storage fails';
      await expectLater(
        repository.saveModule(stale, actor: actor, expectedBaseline: baseline),
        throwsA(isA<IsarError>()),
      );
      expect((await read()).draftNote, 'winner');
    },
  );

  test(
    'actor revocation during native recovery rolls back module and resolution together',
    () async {
      final saved = await makeConflict();
      final review = await recovery.review(actor: actor, saved: saved);
      var checks = 0;
      final guarded = JobModuleDraftRecovery(
        repository: IsarJobModuleRepository(
          auditRepository: _NoRemoteAudit(),
          verifyActor: (_) {
            checks++;
            if (checks == 4) {
              throw StateError('Account changed after awaited local put.');
            }
          },
        ),
      );
      await expectLater(
        guarded.apply(actor: actor, review: review),
        throwsStateError,
      );
      expect(checks, 4);
      expect((await read()).draftNote, 'winner');
      expect((await read()).version, 5);
      expect(
        await isar.auditEvents
            .filter()
            .entityTypeEqualTo('planned_job_module_edit_conflict_resolved')
            .count(),
        0,
      );
      await reopen();
      expect(
        (await recovery.list(
          actor: actor,
          moduleLocalId: moduleId,
        )).single.conflictId,
        saved.conflictId,
      );
    },
  );
}
