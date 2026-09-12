import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_record.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository repository;
  late DateTime now;
  var token = 0;

  DurableSubmissionRepository createRepository() => DurableSubmissionRepository(
    database,
    now: () => now,
    newClaimToken: () => 'claim-${++token}',
  );

  Future<void> open({bool includeSubmissions = true}) async {
    database = await Isar.open(
      <CollectionSchema<dynamic>>[
        MaintenanceRecordSchema,
        if (includeSubmissions) DurableSubmissionRecordSchema,
      ],
      directory: directory.path,
      name: 'durable_submission_test',
      inspector: false,
    );
    repository = createRepository();
  }

  setUp(() async {
    now = DateTime.utc(2026, 9, 12, 10);
    token = 0;
    directory = await Directory.systemTemp.createTemp('durable_submission_');
    await open();
  });

  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<void> reopen() async {
    await database.close();
    await open();
  }

  MaintenanceRecord businessRow() => MaintenanceRecord()
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Pending local evidence'
    ..routedTo = RoutedTo.mechanical
    ..startDate = now
    ..createdAt = now
    ..updatedAt = now;

  DurableSubmissionDraft draft({
    String id = 'submission-a',
    String actor = 'admin-a',
    String request = 'request-a',
    String cover = 'cover-a',
    String? envelope,
  }) => DurableSubmissionDraft(
    submissionId: id,
    actorUid: actor,
    requestId: request,
    aggregateId: cover,
    resourceKey: 'innerCoverAcceptance:$cover',
    protocol: 'assetHierarchy.v2',
    envelopeJson:
        envelope ??
        jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor,
          'request': {
            'requestId': request,
            'operation': 'ACCEPT_INNER_COVER',
            'innerCoverId': cover,
            'expectedVersion': 3,
            'reason': 'Inspection complete',
            'acceptanceDraft': {
              'inspectedOn': '2026-09-12T09:00:00.000Z',
              'acceptanceReference': 'REF-A',
              'leakTestReference': null,
              'ndtReference': null,
              'notes': null,
            },
          },
        }),
  );

  String receipt({String request = 'request-a', int version = 4}) =>
      jsonEncode({'requestId': request, 'version': version, 'accepted': true});

  bool validateReceipt(
    DurableSubmission submission,
    Map<String, dynamic> value,
  ) =>
      value['requestId'] == submission.requestId &&
      value['version'] == 4 &&
      value['accepted'] == true;

  Future<DurableSubmission> accept(DurableSubmission value, {String? raw}) =>
      repository.settleAccepted(
        submissionId: value.submissionId,
        envelopeSha256: value.envelopeSha256,
        receiptJson: raw ?? receipt(request: value.requestId),
        validateReceipt: validateReceipt,
      );

  Matcher code(String value) => isA<DurableSubmissionException>().having(
    (error) => error.code,
    'code',
    value,
  );

  test(
    'exact envelope bytes and original identity survive database reopen',
    () async {
      final input = draft(
        envelope: const JsonEncoder.withIndent(
          '  ',
        ).convert(jsonDecode(draft().envelopeJson)),
      );
      final saved = await repository.prepare(input);
      await reopen();
      final found = await repository.findUnresolvedForResource(
        input.resourceKey,
      );
      expect(found!.envelopeJson, input.envelopeJson);
      expect(found.envelopeSha256, saved.envelopeSha256);
      expect(found.actorUid, 'admin-a');
      expect(found.requestId, 'request-a');
      expect(found.aggregateId, 'cover-a');
      expect(found.state, DurableSubmissionState.intent);
      expect(found.attemptCount, 0);
    },
  );

  test(
    'concurrent different accounts cannot create two unresolved physical owners',
    () async {
      final outcomes = await Future.wait(<Future<Object>>[
        repository
            .prepare(draft())
            .then<Object>((v) => v, onError: (Object e) => e),
        createRepository()
            .prepare(
              draft(id: 'submission-b', actor: 'admin-b', request: 'request-b'),
            )
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);
      expect(outcomes.whereType<DurableSubmission>(), hasLength(1));
      expect(
        outcomes.whereType<DurableSubmissionException>().single.code,
        'resource-pending',
      );
      expect(await database.durableSubmissionRecords.count(), 1);
      final owner = await repository.findUnresolvedForResource(
        'innerCoverAcceptance:cover-a',
      );
      expect(owner, isNotNull);
    },
  );

  test(
    'unchanged reuse returns owner; changed payload or request identity cannot replace it',
    () async {
      final saved = await repository.prepare(draft());
      expect(
        (await repository.prepare(draft())).submissionId,
        saved.submissionId,
      );
      final changed = jsonDecode(draft().envelopeJson) as Map<String, dynamic>;
      (changed['request'] as Map<String, dynamic>)['reason'] =
          'Different intent';
      await expectLater(
        repository.prepare(draft(envelope: jsonEncode(changed))),
        throwsA(code('identity-conflict')),
      );
      await expectLater(
        repository.prepare(draft(id: 'another', cover: 'different-cover')),
        throwsA(code('identity-conflict')),
      );
      expect(
        (await repository.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
      expect(await database.durableSubmissionRecords.count(), 1);
    },
  );

  test(
    'claim contention and actor mismatch grant exactly one dispatch',
    () async {
      await repository.prepare(draft());
      final wrong = await repository.claim(
        submissionId: 'submission-a',
        actorUid: 'admin-b',
      );
      expect(
        wrong.disposition,
        DurableSubmissionClaimDisposition.actorMismatch,
      );
      expect(wrong.mayDispatch, isFalse);
      final claims = await Future.wait([
        repository.claim(submissionId: 'submission-a', actorUid: 'admin-a'),
        createRepository().claim(
          submissionId: 'submission-a',
          actorUid: 'admin-a',
        ),
      ]);
      expect(claims.where((claim) => claim.mayDispatch), hasLength(1));
      expect((await repository.read('submission-a'))!.attemptCount, 1);
      await reopen();
      expect(
        (await repository.claim(
          submissionId: 'submission-a',
          actorUid: 'admin-a',
        )).disposition,
        DurableSubmissionClaimDisposition.claimedElsewhere,
      );
    },
  );

  test(
    'expired claim cannot overwrite newer claim and late acceptance wins every failure',
    () async {
      await repository.prepare(draft());
      final first = await repository.claim(
        submissionId: 'submission-a',
        actorUid: 'admin-a',
      );
      now = now.add(const Duration(minutes: 6));
      final second = await repository.claim(
        submissionId: 'submission-a',
        actorUid: 'admin-a',
      );
      expect(second.mayDispatch, isTrue);
      expect(second.token, isNot(first.token));
      expect(
        await repository.recordOutcome(
          first,
          state: DurableSubmissionState.rejected,
          message: 'Stale refusal',
        ),
        DurableSubmissionOutcome.staleClaim,
      );
      final accepted = await accept(first.submission);
      expect(accepted.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(
        await repository.recordOutcome(
          second,
          state: DurableSubmissionState.uncertain,
          message: 'Late transport error',
        ),
        DurableSubmissionOutcome.alreadyAccepted,
      );
      await reopen();
      final saved = (await repository.read('submission-a'))!;
      expect(saved.receiptJson, receipt());
      expect(saved.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(saved.claimToken, isNull);
      await expectLater(
        repository.prepare(draft(id: 'new-id', request: 'new-request')),
        throwsA(code('resource-pending')),
      );
    },
  );

  test(
    'receipt validation rejects wrong target before any acceptance settlement',
    () async {
      final saved = await repository.prepare(draft());
      await repository.claim(
        submissionId: saved.submissionId,
        actorUid: 'admin-a',
      );
      await expectLater(
        accept(saved, raw: receipt(request: 'wrong')),
        throwsA(code('invalid-receipt')),
      );
      expect((await repository.read(saved.submissionId))!.receiptJson, isNull);
      expect(
        (await repository.read(saved.submissionId))!.state,
        DurableSubmissionState.sending,
      );
      await expectLater(
        repository.settleAccepted(
          submissionId: saved.submissionId,
          envelopeSha256: saved.envelopeSha256,
          receiptJson: receipt(),
          validateReceipt: (_, _) =>
              throw StateError('Domain receipt mismatch'),
        ),
        throwsStateError,
      );
      expect((await repository.read(saved.submissionId))!.receiptJson, isNull);
      await accept(saved);
      await expectLater(
        repository.settleAccepted(
          submissionId: saved.submissionId,
          envelopeSha256: saved.envelopeSha256,
          receiptJson: receipt(version: 5),
          validateReceipt: (_, _) => true,
        ),
        throwsA(code('acceptance-conflict')),
      );
      expect(
        (await repository.read(saved.submissionId))!.receiptJson,
        receipt(),
      );
    },
  );

  test(
    'domain-normalized replay observation retains the same authoritative receipt',
    () async {
      final saved = await repository.prepare(draft());
      await repository.claim(
        submissionId: saved.submissionId,
        actorUid: 'admin-a',
      );
      String normalize(bool replay) {
        final value = jsonDecode(receipt()) as Map<String, dynamic>;
        value['idempotentReplay'] = replay;
        // Observation only: adapters normalize this; identifiers/version remain.
        value['idempotentReplay'] = false;
        return jsonEncode(value);
      }

      await accept(saved, raw: normalize(false));
      final again = await accept(saved, raw: normalize(true));
      expect(again.receiptJson, normalize(false));
      expect(again.attemptCount, 1);
    },
  );

  test('local adoption and reconciliation marker roll back together', () async {
    final pending = businessRow()
      ..firestoreId = 'local-business-row'
      ..description = 'Pending local evidence'
      ..isSynced = false;
    await database.writeTxn(() => database.maintenanceRecords.put(pending));
    final saved = await repository.prepare(draft());
    await repository.claim(
      submissionId: saved.submissionId,
      actorUid: 'admin-a',
    );
    final accepted = await accept(saved);
    await expectLater(
      repository.markReconciled(
        submissionId: saved.submissionId,
        envelopeSha256: saved.envelopeSha256,
        receiptSha256: accepted.receiptSha256!,
        adoptInTransaction: (store) async {
          final row = (await store.maintenanceRecords.get(pending.id))!
            ..isSynced = true;
          await store.maintenanceRecords.put(row);
          throw StateError('Local adoption could not finish');
        },
      ),
      throwsStateError,
    );
    await reopen();
    expect(
      (await database.maintenanceRecords.get(pending.id))!.isSynced,
      isFalse,
    );
    expect(
      (await repository.read(saved.submissionId))!.state,
      DurableSubmissionState.acceptedPendingAdoption,
    );
    await repository.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: accepted.receiptSha256!,
      adoptInTransaction: (store) async {
        final row = (await store.maintenanceRecords.get(pending.id))!
          ..isSynced = true;
        await store.maintenanceRecords.put(row);
      },
    );
    await reopen();
    expect(
      (await database.maintenanceRecords.get(pending.id))!.isSynced,
      isTrue,
    );
    expect(
      (await repository.read(saved.submissionId))!.state,
      DurableSubmissionState.reconciled,
    );
    expect(
      (await repository.prepare(
        draft(id: 'submission-b', request: 'request-b'),
      )).state,
      DurableSubmissionState.intent,
      reason: 'a separate intentional action may use new IDs after resolution',
    );
    expect(await database.durableSubmissionRecords.count(), 2);
  });

  test(
    'cancel before sending retains terminal identity; sending cannot be called unsent',
    () async {
      final saved = await repository.prepare(draft());
      await repository.cancelNeverSent(
        submissionId: saved.submissionId,
        actorUid: 'admin-a',
      );
      expect(
        (await repository.claim(
          submissionId: saved.submissionId,
          actorUid: 'admin-a',
        )).disposition,
        DurableSubmissionClaimDisposition.terminal,
      );
      expect(
        (await repository.prepare(draft())).state,
        DurableSubmissionState.cancelledBeforeSend,
      );
      final next = await repository.prepare(
        draft(id: 'submission-b', request: 'request-b'),
      );
      await repository.claim(
        submissionId: next.submissionId,
        actorUid: 'admin-a',
      );
      await expectLater(
        repository.cancelNeverSent(
          submissionId: next.submissionId,
          actorUid: 'admin-a',
        ),
        throwsA(code('cancellation-unproven')),
      );
      expect(
        (await repository.read(next.submissionId))!.state,
        DurableSubmissionState.sending,
      );
      expect(await database.durableSubmissionRecords.count(), 2);
    },
  );

  test(
    'late accepted response preserves receipt and fences a replacement owner for review',
    () async {
      final original = await repository.prepare(draft());
      final first = await repository.claim(
        submissionId: original.submissionId,
        actorUid: 'admin-a',
      );
      await repository.recordOutcome(
        first,
        state: DurableSubmissionState.rejected,
        message: 'Refused',
      );
      final replacement = await repository.prepare(
        draft(id: 'submission-b', request: 'request-b'),
      );
      final replacementClaim = await repository.claim(
        submissionId: replacement.submissionId,
        actorUid: 'admin-a',
      );
      final accepted = await accept(original);
      expect(accepted.receiptJson, receipt());
      expect(accepted.lastErrorCode, 'resource-conflict');
      expect(
        (await repository.read(replacement.submissionId))!.state,
        DurableSubmissionState.needsReview,
      );
      expect(
        await repository.recordOutcome(
          replacementClaim,
          state: DurableSubmissionState.uncertain,
          message: 'Late second request error',
        ),
        DurableSubmissionOutcome.staleClaim,
      );
      await expectLater(
        repository.markReconciled(
          submissionId: accepted.submissionId,
          envelopeSha256: accepted.envelopeSha256,
          receiptSha256: accepted.receiptSha256!,
        ),
        throwsA(code('resource-conflict')),
      );
      // If the second request was already in flight, its validated result is
      // retained too; neither acceptance can silently erase the other owner.
      final secondAccepted = await accept(replacement);
      expect(
        secondAccepted.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await reopen();
      expect(
        (await repository.read(original.submissionId))!.receiptJson,
        receipt(),
      );
      expect(
        (await repository.read(replacement.submissionId))!.receiptJson,
        receipt(request: 'request-b'),
      );
      await expectLater(
        repository.findUnresolvedForResource(original.resourceKey),
        throwsA(code('resource-conflict')),
      );
    },
  );

  test(
    'future retry deadline and terminal refusal do not rearm themselves',
    () async {
      await repository.prepare(draft());
      final first = await repository.claim(
        submissionId: 'submission-a',
        actorUid: 'admin-a',
      );
      await repository.recordOutcome(
        first,
        state: DurableSubmissionState.uncertain,
        message: 'Try later',
        nextRetryAt: now.add(const Duration(hours: 1)),
      );
      expect(
        (await repository.claim(
          submissionId: 'submission-a',
          actorUid: 'admin-a',
        )).disposition,
        DurableSubmissionClaimDisposition.notDue,
      );
      now = now.add(const Duration(hours: 1));
      final second = await repository.claim(
        submissionId: 'submission-a',
        actorUid: 'admin-a',
      );
      expect(second.mayDispatch, isTrue);
      await repository.recordOutcome(
        second,
        state: DurableSubmissionState.rejected,
        message: 'Rejected',
      );
      await reopen();
      expect(
        (await repository.claim(
          submissionId: 'submission-a',
          actorUid: 'admin-a',
        )).disposition,
        DurableSubmissionClaimDisposition.terminal,
      );
      expect((await repository.read('submission-a'))!.attemptCount, 2);
    },
  );

  test(
    'damaged stored evidence cannot be treated as no pending request',
    () async {
      await repository.prepare(draft());
      final raw = (await database.durableSubmissionRecords
          .where()
          .findFirst())!;
      final damaged = '${raw.immutableJson} changed';
      raw.immutableJson = damaged;
      await database.writeTxn(() => database.durableSubmissionRecords.put(raw));
      await reopen();
      await expectLater(
        repository.findUnresolvedForResource('innerCoverAcceptance:cover-a'),
        throwsA(code('checksum-mismatch')),
      );
      await expectLater(
        repository.claim(submissionId: 'submission-a', actorUid: 'admin-a'),
        throwsA(code('checksum-mismatch')),
      );
      await expectLater(
        repository.prepare(draft(id: 'new', request: 'new')),
        throwsA(code('checksum-mismatch')),
      );
      expect(
        (await database.durableSubmissionRecords.get(raw.id))!.immutableJson,
        damaged,
      );
    },
  );

  test(
    'legacy importer retains raw bytes without inventing an actor or dispatching',
    () async {
      final bytes = Uint8List.fromList(<int>[0xff, 0, 0x7b, 0x22, 0x78]);
      final saved = await repository.importLegacyNeedsReview(
        submissionId: 'legacy-a',
        resourceKey: 'innerCoverAcceptance:cover-a',
        sourceKey: 'old-key',
        sourceBytes: bytes,
      );
      await reopen();
      final found = (await repository.findUnresolvedForResource(
        saved.resourceKey,
      ))!;
      expect(base64Decode(found.legacySourceBase64!), bytes);
      expect(found.actorUid, isNull);
      expect(found.state, DurableSubmissionState.needsReview);
      expect(
        (await repository.claim(
          submissionId: found.submissionId,
          actorUid: 'admin-a',
        )).mayDispatch,
        isFalse,
      );
      await expectLater(
        repository.prepare(draft()),
        throwsA(code('resource-pending')),
      );
      await expectLater(
        repository.importLegacyNeedsReview(
          submissionId: 'legacy-a',
          resourceKey: found.resourceKey,
          sourceKey: 'old-key',
          sourceBytes: Uint8List.fromList([1]),
        ),
        throwsA(code('legacy-conflict')),
      );
      expect(
        (await repository.read('legacy-a'))!.legacySourceBase64,
        found.legacySourceBase64,
      );
    },
  );

  test('unsupported protocol or actor substitution cannot be saved', () async {
    final original = draft();
    final forged = jsonDecode(original.envelopeJson) as Map<String, dynamic>;
    forged['originActorUid'] = 'admin-b';
    await expectLater(
      repository.prepare(draft(envelope: jsonEncode(forged))),
      throwsA(code('invalid-protocol')),
    );
    await expectLater(
      repository.prepare(
        DurableSubmissionDraft(
          submissionId: 'new',
          actorUid: 'admin-a',
          requestId: 'request-a',
          aggregateId: 'cover-a',
          resourceKey: original.resourceKey,
          protocol: 'assetHierarchy.v1',
          envelopeJson: original.envelopeJson,
        ),
      ),
      throwsA(code('unsupported-protocol')),
    );
    expect(await database.durableSubmissionRecords.count(), 0);
  });

  for (final operation in [
    'RECORD_BURNER_CONDITION_ROUND',
    'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
  ]) {
    test(
      '$operation binds the furnace identity and preserves its exact envelope on reopen',
      () async {
        DurableSubmissionDraft burner({
          String? asset = 'furnace-7',
          String? cover,
        }) => DurableSubmissionDraft(
          submissionId: 'burner-submission',
          actorUid: 'admin-a',
          requestId: 'burner-request',
          aggregateId: 'furnace-7',
          resourceKey: 'burnerEvidence:furnace-7',
          protocol: 'assetHierarchy.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'admin-a',
            'request': {
              'requestId': 'burner-request',
              'operation': operation,
              'assetInstanceId': asset,
              'innerCoverId': cover,
              'expectedAssetVersion': 3,
              if (operation == 'COMPLETE_BURNER_RED_HOT_DIRECTIVE')
                'expectedDirectiveVersion': 2,
            },
          }),
        );
        await expectLater(
          repository.prepare(burner(asset: null, cover: 'furnace-7')),
          throwsA(code('invalid-protocol')),
        );
        await expectLater(
          repository.prepare(burner(asset: 'furnace-8')),
          throwsA(code('invalid-protocol')),
        );
        final saved = await repository.prepare(burner());
        await reopen();
        expect(
          (await repository.read(saved.submissionId))!.envelopeJson,
          saved.envelopeJson,
        );
        expect(
          (await repository.claim(
            submissionId: saved.submissionId,
            actorUid: 'admin-a',
          )).mayDispatch,
          isTrue,
        );
      },
    );
  }

  test(
    'quality protocol binds only new monitoring identity and zero baseline',
    () async {
      DurableSubmissionDraft quality({
        String operation = 'CREATE_QUALITY_MONITORING_REQUEST',
        String monitoringId = 'monitoring-1',
        int version = 0,
      }) => DurableSubmissionDraft(
        submissionId: 'quality-submission',
        actorUid: 'admin-a',
        requestId: 'quality-request',
        aggregateId: 'monitoring-1',
        resourceKey: 'qualityMonitoring:admin-a',
        protocol: 'chargeAbnormality.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': 'admin-a',
          'request': {
            'requestId': 'quality-request',
            'operation': operation,
            'monitoringRequestId': monitoringId,
            'expectedVersion': version,
          },
        }),
      );
      await expectLater(
        repository.prepare(
          quality(operation: 'CLOSE_QUALITY_MONITORING_REQUEST'),
        ),
        throwsA(code('invalid-protocol')),
      );
      await expectLater(
        repository.prepare(quality(monitoringId: 'wrong')),
        throwsA(code('invalid-protocol')),
      );
      await expectLater(
        repository.prepare(quality(version: 1)),
        throwsA(code('invalid-protocol')),
      );
      final saved = await repository.prepare(quality());
      await reopen();
      expect(
        (await repository.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
    },
  );

  const morningContracts = {
    'START_MORNING_REVIEW': false,
    'RECORD_MORNING_REVIEW_NOT_HELD': false,
    'JOIN_MORNING_REVIEW': false,
    'ADD_MORNING_REVIEW_ENTRY': false,
    'CREATE_MORNING_REVIEW_ACTION': false,
    'ACCEPT_MORNING_REVIEW_ACTION': true,
    'COMPLETE_MORNING_REVIEW_ACTION': true,
    'TAKE_OVER_MORNING_REVIEW': true,
    'FINALIZE_MORNING_REVIEW': true,
    'CREATE_MORNING_REVIEW_STANDING_CONCERN': false,
    'RESOLVE_MORNING_REVIEW_STANDING_CONCERN': true,
    'CHECK_MORNING_REVIEW_STANDING_CONCERN': false,
    'ADD_MORNING_REVIEW_ADDENDUM': false,
  };
  for (final entry in morningContracts.entries) {
    test(
      '${entry.key} preserves its exact session and native version contract',
      () async {
        final serverDerived = [
          'START_MORNING_REVIEW',
          'RECORD_MORNING_REVIEW_NOT_HELD',
        ].contains(entry.key);
        DurableSubmissionDraft morning({
          bool invalidVersion = false,
          bool wrongIdentity = false,
        }) => DurableSubmissionDraft(
          submissionId: 'morning-submission',
          actorUid: 'admin-a',
          requestId: 'morning-request',
          aggregateId: serverDerived ? 'morning-request' : 'session-1',
          resourceKey: 'morningReview:admin-a',
          protocol: 'assetHierarchy.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'admin-a',
            'request': {
              'requestId': serverDerived && wrongIdentity
                  ? 'wrong-request'
                  : 'morning-request',
              'operation': entry.key,
              if (!serverDerived)
                'sessionId': wrongIdentity ? 'wrong-session' : 'session-1',
              if (entry.value) 'expectedVersion': invalidVersion ? 0 : 3,
              if (!entry.value && invalidVersion) 'expectedVersion': 0,
            },
          }),
        );
        await expectLater(
          repository.prepare(morning(invalidVersion: true)),
          throwsA(code('invalid-protocol')),
        );
        await expectLater(
          repository.prepare(morning(wrongIdentity: true)),
          throwsA(code('invalid-protocol')),
        );
        final saved = await repository.prepare(morning());
        await reopen();
        expect(
          (await repository.read(saved.submissionId))!.envelopeJson,
          saved.envelopeJson,
        );
        expect(
          (await repository.claim(
            submissionId: saved.submissionId,
            actorUid: 'admin-a',
          )).mayDispatch,
          isTrue,
        );
      },
    );
  }

  test(
    'closed local store prevents a capable dispatch callback from running',
    () async {
      var calls = 0;
      await database.close();
      Future<void> submit() async {
        final saved = await repository.prepare(draft());
        final claim = await repository.claim(
          submissionId: saved.submissionId,
          actorUid: 'admin-a',
        );
        if (claim.mayDispatch) calls++; // Capable of succeeding if admitted.
      }

      await expectLater(submit(), throwsA(anything));
      expect(calls, 0);
    },
  );

  test(
    'additive collection open preserves an existing dirty maintenance record',
    () async {
      await database.close(deleteFromDisk: true);
      await open(includeSubmissions: false);
      final old = businessRow()
        ..firestoreId = 'pre-upgrade-ticket'
        ..description = 'Unsynced operator work'
        ..version = 7
        ..isSynced = false;
      await database.writeTxn(() => database.maintenanceRecords.put(old));
      await database.close();
      await open();
      final preserved = (await database.maintenanceRecords.get(old.id))!;
      expect(preserved.firestoreId, old.firestoreId);
      expect(preserved.description, old.description);
      expect(preserved.version, 7);
      expect(preserved.isSynced, isFalse);
      await repository.prepare(draft());
      await reopen();
      expect(
        (await database.maintenanceRecords.get(old.id))!.isSynced,
        isFalse,
      );
      expect(
        (await repository.read('submission-a'))!.state,
        DurableSubmissionState.intent,
      );
    },
  );
}
