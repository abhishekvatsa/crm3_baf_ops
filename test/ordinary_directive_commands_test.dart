import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_edit_directive_dialog.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/remote_operational_directive_reader.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late DurableSubmissionRepository store;
  late String uid;
  late DateTime now;
  late List<Map<String, dynamic>> sent;
  late Map<String, dynamic>? server;
  late bool loseReply;
  late bool readFails;
  final actor = AppUser(
    uid: 'issuer',
    name: 'Issuer',
    email: 'issuer@example.com',
    roles: const [AppRole.admin, AppRole.operations],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  Future<void> open() async {
    db = await Isar.open(
      [OperationalDirectiveSchema, DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'ordinary_command',
      inspector: false,
    );
    app.isar = db;
    store = DurableSubmissionRepository(db, now: () => now);
  }

  Future<Map<String, dynamic>> invoke(Map<String, dynamic> envelope) async {
    sent.add(jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>);
    final request = Map<String, dynamic>.from(envelope['request'] as Map);
    server = Map<String, dynamic>.from(request['after'] as Map);
    if (loseReply) {
      loseReply = false;
      throw StateError('Lost reply after acceptance');
    }
    return {
      'ok': true,
      'requestId': request['requestId'],
      'operation': 'APPLY_ORDINARY_DIRECTIVE',
      'entityId': request['directiveId'],
      'version': server!['version'],
      'committedAt': '2026-09-20T10:00:00.000Z',
      'idempotentReplay': sent.length > 1,
      'entity': server,
    };
  }

  OrdinaryDirectiveCommands owner({bool web = false}) =>
      OrdinaryDirectiveCommands(
        store: store,
        actorUid: () => uid,
        projectId: 'demo-test',
        web: web,
        capability: (_) async {},
        invoke: invoke,
        read: (_) async {
          if (readFails) throw StateError('Read unavailable');
          if (server == null) throw OrdinaryDirectiveMissing();
          return server!;
        },
      );
  OperationalDirective draft() => OperationalDirective()
    ..firestoreId = 'directive-one'
    ..title = 'Inspect cooler'
    ..description = 'Check temperature'
    ..directedTo = AppRole.operations
    ..createdByUid = actor.uid
    ..createdByName = actor.name
    ..issuedByUid = actor.uid
    ..issuedByName = actor.name
    ..issuedAt = DateTime.utc(2026, 9, 19)
    ..createdAt = DateTime.utc(2026, 9, 19)
    ..updatedAt = DateTime.utc(2026, 9, 19)
    ..version = 1;
  Future<DurableSubmission> pending() async =>
      (await store.listForActor(uid)).single;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ordinary_commands_');
    uid = 'issuer';
    now = DateTime.utc(2026, 9, 20, 10);
    sent = [];
    server = null;
    loseReply = false;
    readFails = false;
    SharedPreferences.setMockInitialValues({});
    await open();
  });
  tearDown(() async {
    if (db.isOpen) await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });
  test(
    'intent and actor survive Isar close/reopen and adopt exact server readback',
    () async {
      await owner().save(
        actor: actor,
        action: 'create',
        after: draft(),
        reason: 'Issue instruction',
      );
      final original = await pending();
      expect(sent, isEmpty);
      await db.close();
      await open();
      await owner().check(original.submissionId);
      expect(sent.single['originActorUid'], 'issuer');
      expect(sent.single, (jsonDecode(original.envelopeJson)));
      expect(
        (await db.operationalDirectives.where().findAll()).single.isSynced,
        isTrue,
      );
      expect(
        (await store.read(original.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );
  test(
    'offline successor is blocked without collapsing original command',
    () async {
      await owner().save(
        actor: actor,
        action: 'create',
        after: draft(),
        reason: 'Issue instruction',
      );
      final saved = await pending();
      final local = (await db.operationalDirectives.where().findAll()).single;
      final repo = IsarDirectiveRepository(ordinaryCommands: owner());
      await expectLater(
        repo.acknowledgeDirective(local.id, actor: actor, expectedVersion: 1),
        throwsStateError,
      );
      expect((await pending()).envelopeJson, saved.envelopeJson);
      expect(
        (await db.operationalDirectives.get(local.id))!.status,
        DirectiveStatus.open,
      );
    },
  );
  test('lost reply retries original identity after restart', () async {
    await owner().save(
      actor: actor,
      action: 'create',
      after: draft(),
      reason: 'Issue instruction',
    );
    final saved = await pending();
    loseReply = true;
    await expectLater(owner().check(saved.submissionId), throwsStateError);
    await db.close();
    now = now.add(const Duration(hours: 1));
    await open();
    await owner().check(saved.submissionId);
    expect(sent, hasLength(2));
    expect(sent[0], sent[1]);
    expect(
      (await store.read(saved.submissionId))!.state,
      DurableSubmissionState.reconciled,
    );
  });
  test('another signed-in actor cannot replay or claim saved work', () async {
    await owner().save(
      actor: actor,
      action: 'create',
      after: draft(),
      reason: 'Issue instruction',
    );
    final saved = await pending();
    uid = 'other';
    await expectLater(owner().check(saved.submissionId), throwsStateError);
    expect(sent, isEmpty);
    expect(await owner().owns('directive-one'), isTrue);
  });
  test(
    'accepted receipt survives failed readback and is not dispatched again',
    () async {
      await owner().save(
        actor: actor,
        action: 'create',
        after: draft(),
        reason: 'Issue instruction',
      );
      final saved = await pending();
      readFails = true;
      await expectLater(owner().check(saved.submissionId), throwsStateError);
      expect(
        (await pending()).state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await db.close();
      await open();
      readFails = false;
      await owner().check(saved.submissionId);
      expect(sent, hasLength(1));
    },
  );
  test('newer local text cannot be erased by acceptance', () async {
    await owner().save(
      actor: actor,
      action: 'create',
      after: draft(),
      reason: 'Issue instruction',
    );
    final saved = await pending();
    final local = (await db.operationalDirectives.where().findAll()).single
      ..title = 'Preserve this evidence';
    await db.writeTxn(() => db.operationalDirectives.put(local));
    await expectLater(owner().check(saved.submissionId), throwsStateError);
    expect(
      (await db.operationalDirectives.get(local.id))!.title,
      'Preserve this evidence',
    );
    expect(
      (await pending()).state,
      DurableSubmissionState.acceptedPendingAdoption,
    );
  });
  test(
    'clean same-revision divergent text is held, while old closed-active flag is repaired',
    () async {
      final local = draft()..isSynced = true;
      await db.writeTxn(() => db.operationalDirectives.put(local));
      final remote = copyOperationalDirective(local)..title = 'Different';
      final repo = IsarDirectiveRepository(ordinaryCommands: owner());
      final result = await repo.applyDirectiveFromRemote(remote);
      expect(result.outcome.name, 'cleanLocalReconciliationRequired');
      local
        ..status = DirectiveStatus.closed
        ..closedAt = local.updatedAt
        ..closedByUid = actor.uid
        ..closedWithoutAcknowledgement = true
        ..isActive = true;
      await db.writeTxn(() => db.operationalDirectives.put(local));
      final canonical = copyOperationalDirective(local)..isActive = false;
      expect(
        (await repo.applyDirectiveFromRemote(canonical)).outcome.name,
        'updated',
      );
      expect((await db.operationalDirectives.get(local.id))!.isActive, isFalse);
    },
  );
  test(
    'Admin changes acknowledged instruction into unacknowledged revision and freezes old acknowledgement',
    () async {
      final local = draft()
        ..isSynced = true
        ..status = DirectiveStatus.acknowledged
        ..acknowledgedByUid = 'recipient'
        ..acknowledgedByName = 'Recipient'
        ..acknowledgedAt = DateTime.utc(2026, 9, 19);
      await db.writeTxn(() => db.operationalDirectives.put(local));
      final edited = copyOperationalDirective(local)
        ..title = 'Revised wording'
        ..directedTo = AppRole.seniorMechanical
        ..amendmentReason = 'Correct target and instruction';
      await IsarDirectiveRepository(
        ordinaryCommands: owner(),
      ).updateDirective(edited, actor: actor);
      final request = (await pending()).envelope['request'] as Map;
      expect((request['before'] as Map)['acknowledgedByUid'], 'recipient');
      expect((request['after'] as Map)['acknowledgedByUid'], isNull);
      expect((request['after'] as Map)['directedTo'], 'seniorMechanical');
    },
  );
  test(
    'web retains receipt before readback and does not reissue after reload',
    () async {
      readFails = true;
      await expectLater(
        owner(web: true).save(
          actor: actor,
          action: 'create',
          after: draft(),
          reason: 'Issue instruction',
        ),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.endsWith(':accepted')),
        hasLength(1),
      );
      readFails = false;
      expect((await owner(web: true).checkAll()).succeeded, 1);
      expect(sent, hasLength(1));
      expect(prefs.getKeys(), isEmpty);
    },
  );
  test(
    'reviewed cancellation releases only its exact optimistic projection, retaining the command and decision',
    () async {
      await owner().save(
        actor: actor,
        action: 'create',
        after: draft(),
        reason: 'Issue instruction',
      );
      final row = await pending();
      final decision = {
        'schemaVersion': 1,
        'domain': 'ordinaryDirective',
        'requestId': row.requestId,
        'evidenceSha256': row.reviewEvidenceSha256,
        'originalActorUid': uid,
        'reviewerUid': uid,
        'outcome': 'cancelled',
        'decisionId': 'review-decision',
        'decidedAt': '2026-09-20T10:00:00.000Z',
        'receiptSha256': null,
        'receiptSummary': null,
        'reason': 'Confirmed safe cancellation with permanent server fence',
      };
      await store.settleReview(
        submissionId: row.submissionId,
        evidenceSha256: row.reviewEvidenceSha256,
        reviewerUid: uid,
        decisionJson: jsonEncode(decision),
        requireReviewer: () {},
      );
      expect((await owner().checkAll()).succeeded, 1);
      expect(await db.operationalDirectives.where().findAll(), isEmpty);
      expect(
        (await store.read(row.submissionId))!.envelopeJson,
        row.envelopeJson,
      );
      expect(sent, isEmpty);
    },
  );
  test(
    'automatic Burner/UV directives cannot be poisoned by ordinary Admin edits',
    () async {
      final local = draft()
        ..firestoreId = 'burner_round_red_hot_control'
        ..isSynced = true;
      await db.writeTxn(() => db.operationalDirectives.put(local));
      final changed = copyOperationalDirective(local)
        ..title = 'Ordinary edit'
        ..amendmentReason = 'Wrong route';
      await expectLater(
        IsarDirectiveRepository(
          ordinaryCommands: owner(),
        ).updateDirective(changed, actor: actor),
        throwsStateError,
      );
      expect(
        (await db.operationalDirectives.get(local.id))!.title,
        local.title,
      );
      expect(await store.listForActor(uid), isEmpty);
    },
  );
  test(
    'browser Admin review archives exact original evidence before releasing the retry',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final envelope = {
        'protocolVersion': 2,
        'originActorUid': 'original',
        'request': {
          'requestId': 'web-held-request',
          'operation': 'APPLY_ORDINARY_DIRECTIVE',
          'directiveId': 'directive-one',
          'action': 'amend',
          'expectedVersion': 1,
          'before': ordinaryDirectiveWire(draft()),
          'after': ordinaryDirectiveWire(draft()),
          'reason': 'Correct instruction',
        },
      };
      const key = 'ordinaryDirective:demo-test:original:directive-one';
      final raw = jsonEncode(envelope);
      await prefs.setString(key, raw);
      final calls = <Map<String, dynamic>>[];
      final reviewer = OrdinaryDirectiveCommands(
        web: true,
        projectId: 'demo-test',
        actorUid: () => uid,
        invoke: (outer) async {
          calls.add(outer);
          final q = Map<String, dynamic>.from(outer['recovery'] as Map);
          if (q['phase'] == 'inspect') {
            return {
              ...q
                ..remove('phase')
                ..remove('reason'),
              'reviewerUid': actor.uid,
              'reviewToken': 'a' * 64,
              'observation': 'receiptAbsent',
              'receiptSha256': null,
              'receiptSummary': null,
            };
          }
          return {
            ...q
              ..remove('phase')
              ..remove('reviewToken'),
            'reviewerUid': actor.uid,
            'outcome': 'cancelled',
            'decisionId': 'review-web',
            'decidedAt': '2026-09-20T10:00:00.000Z',
            'receiptSha256': null,
            'receiptSummary': null,
          };
        },
      );
      final inspection = await reviewer.inspectWebReview(
        actor: actor,
        key: key,
        reason: 'Confirmed wrong instruction',
      );
      expect(prefs.getString(key), raw);
      await reviewer.finalizeWebReview(actor: actor, inspection: inspection);
      expect(prefs.containsKey(key), isFalse);
      final archive =
          jsonDecode(
                prefs.getString(
                  'ordinaryDirectiveReview:demo-test:web-held-request',
                )!,
              )
              as Map;
      expect(archive['envelope'], raw);
      expect((archive['decision'] as Map)['originalActorUid'], 'original');
      expect(calls.every((call) => !call.containsKey('request')), isTrue);
    },
  );
  testWidgets('failed amendment keeps text and reason in the actual editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminEditDirectiveDialog(
            directive: draft(),
            onSave: (_) async => throw StateError('Reviewed version changed'),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Keep my revised wording',
    );
    final reason = find.widgetWithText(
      TextFormField,
      'Reason for the amendment',
    );
    await tester.ensureVisible(reason);
    await tester.enterText(reason, 'Correct the original instruction');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Keep my revised wording'), findsOneWidget);
    expect(find.text('Correct the original instruction'), findsOneWidget);
    expect(find.textContaining('Your entries remain here.'), findsOneWidget);
  });
  test(
    'actual backend output is readable by installed strict Dart decoder',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/ordinary_directive_actual_handler.json',
                ).readAsStringSync(),
              )
              as List;
      for (final result in fixture) {
        final row = readRemoteOperationalDirective(
          Map<String, dynamic>.from(result['entity'] as Map),
          documentId: result['entityId'] as String,
        );
        expect(row.version, result['version']);
      }
    },
  );
}
