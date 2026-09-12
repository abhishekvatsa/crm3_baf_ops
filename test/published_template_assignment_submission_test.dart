import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_idempotency_store.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_server_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_submission_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';
import 'support/published_assignment_receipt_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Isar database;
  late Directory directory;
  late DurableSubmissionRepository store;
  late PublishedTemplateAssignmentSubmissionController controller;
  late _AssignmentServer server;
  late AppUser actor;
  Future<void> Function(String)? capability;
  var probes = 0;

  AppUser manager([String uid = 'assigner-1']) => AppUser(
    uid: uid,
    name: 'Manager',
    email: '$uid@example.test',
    roles: const [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  PublishedTemplateAssignmentRequest request({
    String id = '11111111-1111-4111-8111-111111111111',
    String? remarks,
  }) => PublishedTemplateAssignmentRequest(
    requestId: id,
    packageFirestoreId: 'package-1',
    versionFirestoreId: 'version-1',
    expectedVersionNumber: 1,
    expectedContentHash: 'hash-1',
    assetType: AssetType.base,
    assetNumber: 101,
    assetClassId: 'class-base',
    assetInstanceId: 'base-101',
    remarks: remarks,
  );
  Future<void> open({bool modules = true}) async {
    database = await Isar.open(
      [
        DurableSubmissionRecordSchema,
        JobExecutionSchema,
        if (modules) JobModuleInstanceSchema,
      ],
      directory: directory.path,
      name: 'assignment_submission',
      inspector: false,
    );
    store = DurableSubmissionRepository(database);
    controller = PublishedTemplateAssignmentSubmissionController(
      store: store,
      server: server,
      legacy: PublishedTemplateAssignmentIdempotencyStore(),
      requireActor: () => actor,
      requireCapability: (uid) async {
        probes++;
        await capability?.call(uid);
      },
    );
  }

  Future<void> reopen({bool modules = true}) async {
    await database.close();
    await open(modules: modules);
  }

  Future<DurableSubmission> prepare({
    PublishedTemplateAssignmentRequest? value,
  }) => controller.prepare(
    originActorUid: actor.uid,
    request: value ?? request(),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('assignment_submission_');
    server = _AssignmentServer();
    actor = manager();
    probes = 0;
    capability = null;
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });

  test(
    'lost response and process-store reopen recover full assignment without duplicate job',
    () async {
      final saved = await prepare();
      server.loseResponse = true;
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<PublishedTemplateAssignmentServerException>()),
      );
      await reopen();
      final restored = (await controller.restore())!;
      expect(restored.envelopeJson, saved.envelopeJson);
      final result = await controller.check(restored.submissionId);
      expect(result.requestId, saved.requestId);
      expect(server.created, 1);
      expect(server.envelopes.toSet(), {saved.envelopeJson});
      expect(await database.jobExecutions.count(), 1);
      expect(await database.jobModuleInstances.count(), 1);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
      await reopen();
      expect(await controller.restore(), isNull);
    },
  );

  test(
    'module collection failure rolls back execution and marker; reopen adopts saved receipt without resend',
    () async {
      await database.close(deleteFromDisk: true);
      await open(modules: false);
      final saved = await prepare();
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(anything),
      );
      expect(await database.jobExecutions.count(), 0);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await reopen();
      await controller.check(saved.submissionId);
      expect(server.envelopes.length, 1);
      expect(probes, 1);
      expect(await database.jobExecutions.count(), 1);
      expect(await database.jobModuleInstances.count(), 1);
    },
  );

  test(
    'newer dirty execution and module are retained inside atomic acceptance adoption',
    () async {
      final saved = await prepare();
      final raw = retainedAssignmentReceipt(saved.requestId);
      final prior = PublishedTemplateAssignmentServerResult.fromCallableData(
        raw,
        fallbackRequestId: saved.requestId,
        expectedRequest: request(),
      );
      prior.execution
        ..version = 2
        ..isSynced = false
        ..remarks = 'New operator work';
      prior.modules.single
        ..version = 2
        ..isSynced = false
        ..draftNote = 'Unsynced module evidence';
      await database.writeTxn(() async {
        await database.jobExecutions.put(prior.execution);
        await database.jobModuleInstances.put(prior.modules.single);
      });
      await controller.check(saved.submissionId);
      expect(
        (await database.jobExecutions.get(prior.execution.id))!.remarks,
        'New operator work',
      );
      expect(
        (await database.jobExecutions.get(prior.execution.id))!.isSynced,
        isFalse,
      );
      expect(
        (await database.jobModuleInstances.get(
          prior.modules.single.id,
        ))!.draftNote,
        'Unsynced module evidence',
      );
      expect(
        (await database.jobModuleInstances.get(
          prior.modules.single.id,
        ))!.isSynced,
        isFalse,
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'conflicting local module origin rolls back inserted execution and retains receipt',
    () async {
      final saved = await prepare();
      final result = PublishedTemplateAssignmentServerResult.fromCallableData(
        retainedAssignmentReceipt(saved.requestId),
        fallbackRequestId: saved.requestId,
        expectedRequest: request(),
      );
      result.modules.single.metadataJson = jsonEncode({
        'source': 'server_governed_published_template_assignment',
        'requestId': 'another-request',
        'publicationAuditId': 'audit-1',
      });
      await database.writeTxn(
        () => database.jobModuleInstances.put(result.modules.single),
      );
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<PublishedTemplateAssignmentServerException>()),
      );
      expect(await database.jobExecutions.count(), 0);
      expect(
        (await database.jobModuleInstances.get(
          result.modules.single.id,
        ))!.metadataJson,
        contains('another-request'),
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    },
  );

  for (final conflictModule in [false, true]) {
    test(
      'clean equal-version ${conflictModule ? 'module' : 'execution'} disagreement retains work and acceptance without reconciliation',
      () async {
        final saved = await prepare();
        final prior = PublishedTemplateAssignmentServerResult.fromCallableData(
          retainedAssignmentReceipt(saved.requestId),
          fallbackRequestId: saved.requestId,
          expectedRequest: request(),
        );
        await database.writeTxn(() async {
          if (conflictModule) {
            prior.modules.single.draftNote = 'Contradictory clean evidence';
            await database.jobModuleInstances.put(prior.modules.single);
          } else {
            prior.execution.remarks = 'Contradictory clean evidence';
            await database.jobExecutions.put(prior.execution);
          }
        });
        await expectLater(
          controller.check(saved.submissionId),
          throwsA(isA<PublishedTemplateAssignmentServerException>()),
        );
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
        expect(await database.jobExecutions.count(), conflictModule ? 0 : 1);
        expect(
          await database.jobModuleInstances.count(),
          conflictModule ? 1 : 0,
        );
        await reopen();
        await expectLater(
          controller.check(saved.submissionId),
          throwsA(isA<PublishedTemplateAssignmentServerException>()),
        );
        expect(server.envelopes.length, 1);
        expect(
          (await store.read(saved.submissionId))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
      },
    );
  }

  test(
    'matching clean equal-version rows reconcile without duplicate rows',
    () async {
      final saved = await prepare();
      final prior = PublishedTemplateAssignmentServerResult.fromCallableData(
        retainedAssignmentReceipt(saved.requestId),
        fallbackRequestId: saved.requestId,
        expectedRequest: request(),
      );
      await database.writeTxn(() async {
        await database.jobExecutions.put(prior.execution);
        await database.jobModuleInstances.put(prior.modules.single);
      });
      await controller.check(saved.submissionId);
      expect(await database.jobExecutions.count(), 1);
      expect(await database.jobModuleInstances.count(), 1);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'lost response then later completed remarks adopts the current projection using original intent',
    () async {
      final saved = await prepare();
      server.loseResponse = true;
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(anything),
      );
      final advanced = server.accepted[saved.requestId]!['execution'] as Map;
      advanced.addAll(<String, dynamic>{
        'isCompleted': true,
        'completedAt': '2026-06-20T12:00:00.000Z',
        'completedByUid': 'closer-1',
        'updatedAt': '2026-06-20T12:00:00.000Z',
        'version': 2,
        'remarks': 'Later completion note',
      });
      await reopen();
      final result = await controller.check(saved.submissionId);
      expect(result.execution.isCompleted, isTrue);
      expect(result.execution.remarks, 'Later completion note');
      expect(result.execution.version, 2);
      expect(server.envelopes.toSet(), {saved.envelopeJson});
      expect(server.created, 1);
      expect(
        (await database.jobExecutions.where().findAll()).single.remarks,
        'Later completion note',
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'changed remarks on an uncompleted original version remain uncertain',
    () async {
      final saved = await prepare();
      server.accepted[saved.requestId] = retainedAssignmentReceipt(
        saved.requestId,
      );
      (server.accepted[saved.requestId]!['execution'] as Map)['remarks'] =
          'Not the original assignment';
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(anything),
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.uncertain,
      );
      expect((await store.read(saved.submissionId))!.receiptJson, isNull);
      expect(await database.jobExecutions.count(), 0);
    },
  );

  for (final raw in [
    '{"requestId":"old","payloadFingerprint":"hash-only"}',
    '{malformed legacy evidence',
  ]) {
    test(
      'legacy raw evidence stays needsReview and blocks new assignment: $raw',
      () async {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'PENDING_GOVERNED_ASSIGNMENT::assigner-1',
          raw,
        );
        final saved = (await controller.restore())!;
        expect(saved.state, DurableSubmissionState.needsReview);
        expect(saved.actorUid, isNull);
        expect(utf8.decode(base64Decode(saved.legacySourceBase64!)), raw);
        await expectLater(
          prepare(),
          throwsA(isA<DurableSubmissionException>()),
        );
        expect(server.envelopes, isEmpty);
        expect(
          preferences.getString('PENDING_GOVERNED_ASSIGNMENT::assigner-1'),
          raw,
        );
      },
    );
  }

  test(
    'changed form cannot replace full frozen payload or start another uncertain owner',
    () async {
      final saved = await prepare();
      server.loseResponse = true;
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(anything),
      );
      await expectLater(
        prepare(value: request(remarks: 'Changed')),
        throwsA(isA<DurableSubmissionException>()),
      );
      await expectLater(
        prepare(value: request(id: '22222222-2222-4222-8222-222222222222')),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(
        (await store.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
      expect(server.created, 1);
    },
  );

  test(
    'wrong actor receipt cannot settle acceptance or insert local rows',
    () async {
      final saved = await prepare();
      server.receiptActor = 'other-actor';
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<PublishedTemplateAssignmentServerException>()),
      );
      expect((await store.read(saved.submissionId))!.receiptJson, isNull);
      expect(await database.jobExecutions.count(), 0);
      expect(await database.jobModuleInstances.count(), 0);
    },
  );

  test(
    'capability failure and account change before claim leave never-sent work intact',
    () async {
      final saved = await prepare();
      capability = (_) async => throw StateError('V2 unavailable');
      await expectLater(controller.check(saved.submissionId), throwsStateError);
      expect((await store.read(saved.submissionId))!.attemptCount, 0);
      capability = (_) async {
        actor = manager('assigner-2');
      };
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<PublishedTemplateAssignmentServerException>()),
      );
      expect((await store.read(saved.submissionId))!.attemptCount, 0);
      expect(server.envelopes, isEmpty);
    },
  );

  test(
    'valid receipt after account change is retained but not adopted or returned to new actor',
    () async {
      final saved = await prepare();
      server.beforeReturn = () {
        actor = manager('assigner-2');
      };
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<PublishedTemplateAssignmentServerException>()),
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect(await database.jobExecutions.count(), 0);
      actor = manager();
      server.beforeReturn = null;
      await controller.check(saved.submissionId);
      expect(server.envelopes.length, 1);
      expect(await database.jobExecutions.count(), 1);
    },
  );
}

class _AssignmentServer extends PublishedTemplateAssignmentServerService {
  final List<String> envelopes = [];
  final Map<String, Map<String, dynamic>> accepted = {};
  bool loseResponse = false;
  int created = 0;
  String receiptActor = 'assigner-1';
  void Function()? beforeReturn;
  @override
  Future<Map<String, dynamic>> assignFrozenEnvelope(String envelopeJson) async {
    envelopes.add(envelopeJson);
    final request = (jsonDecode(envelopeJson) as Map)['request'] as Map;
    final id = request['requestId'] as String;
    final prior = accepted.containsKey(id);
    final response = accepted.putIfAbsent(id, () {
      created++;
      return retainedAssignmentReceipt(id, actor: receiptActor);
    });
    beforeReturn?.call();
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Server accepted but response was lost');
    }
    return {
      ...Map<String, dynamic>.from(jsonDecode(jsonEncode(response)) as Map),
      'idempotentReplay': prior,
    };
  }
}
