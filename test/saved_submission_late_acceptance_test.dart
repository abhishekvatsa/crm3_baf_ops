import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crm3_baf_ops/core/persistence/durable_submission_record.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_review_acceptance.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/inspections/services/inspection_campaign_submission_controller.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/legacy_v12_durable_submission_repository.dart';
import '../tool/test_support/inspection_campaign_submission_fixture.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final at = DateTime.utc(2026, 9, 12, 10);
  const resource = 'innerCoverAcceptance:cover-a';
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'late_review_acceptance',
      inspector: false,
    );
    store = DurableSubmissionRepository(database, now: () => at);
  }

  Future<void> restart() async {
    await database.close();
    await open();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('late_review_');
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  Matcher code(String value) =>
      isA<DurableSubmissionException>().having((e) => e.code, 'code', value);
  DurableSubmissionDraft draft([String id = 'a']) => DurableSubmissionDraft(
    submissionId: 'submission-$id',
    actorUid: 'origin',
    requestId: 'request-$id',
    aggregateId: 'cover-a',
    resourceKey: resource,
    protocol: 'assetHierarchy.v2',
    envelopeJson: jsonEncode({
      'protocolVersion': 2,
      'originActorUid': 'origin',
      'request': {
        'requestId': 'request-$id',
        'operation': 'ACCEPT_INNER_COVER',
        'innerCoverId': 'cover-a',
        'expectedVersion': 3,
        'reason': 'Physical inspection complete',
        'acceptanceDraft': {
          'inspectedOn': '2026-09-12T09:00:00.000Z',
          'acceptanceReference': 'REFERENCE',
          'leakTestReference': null,
          'ndtReference': null,
          'notes': null,
        },
      },
    }),
  );
  Future<DurableSubmission> attempted([String id = 'a']) async {
    final row = await store.prepare(draft(id));
    await store.claim(submissionId: row.submissionId, actorUid: 'origin');
    return (await store.read(row.submissionId))!;
  }

  Map<String, dynamic> acceptance(DurableSubmission row) => {
    'ok': true,
    'requestId': row.requestId,
    'operation': 'ACCEPT_INNER_COVER',
    'innerCoverId': 'cover-a',
    'version': 4,
    'secondaryVersion': null,
    'auditId': 'inner_cover_${row.requestId}',
    'committedAt': at.toIso8601String(),
    'idempotentReplay': false,
  };
  bool validate(DurableSubmission row, Map<String, dynamic> value) {
    AssetHierarchyMutationReceipt.fromMap(
      value,
      request: Map<String, dynamic>.from(row.envelope['request'] as Map),
    );
    return true;
  }

  Map<String, dynamic> decision(
    DurableSubmission row, {
    String outcome = 'reviewedExisting',
  }) => {
    'schemaVersion': 1,
    'domain': 'innerCoverAcceptance',
    'requestId': row.requestId,
    'evidenceSha256': row.reviewEvidenceSha256,
    'originalActorUid': row.actorUid,
    'reviewerUid': 'reviewer',
    'outcome': outcome,
    'decisionId': 'decision-${row.submissionId}',
    'decidedAt': at.toIso8601String(),
    'receiptSha256': outcome == 'reviewedExisting' ? 'b' * 64 : null,
    'receiptSummary': outcome == 'reviewedExisting'
        ? {
            'actorUid': 'origin',
            'operation': 'ACCEPT_INNER_COVER',
            'entityId': 'cover-a',
            'version': 4,
            'committedAt': at.toIso8601String(),
            'status': null,
          }
        : null,
    'reason': 'Inspected original receipt and retained evidence.',
  };
  Future<DurableSubmission> review(
    DurableSubmission row, [
    Map<String, dynamic>? proof,
  ]) => store.settleReview(
    submissionId: row.submissionId,
    evidenceSha256: row.reviewEvidenceSha256,
    reviewerUid: 'reviewer',
    decisionJson: jsonEncode(proof ?? decision(row)),
    requireReviewer: () {},
  );
  Future<DurableSubmission> accept(DurableSubmission row) =>
      store.settleAccepted(
        submissionId: row.submissionId,
        envelopeSha256: row.envelopeSha256,
        receiptJson: jsonEncode(acceptance(row)),
        validateReceipt: validate,
      );
  Future<DurableSubmissionRecord> raw(DurableSubmission row) async =>
      (await database.durableSubmissionRecords
          .where()
          .submissionIdEqualTo(row.submissionId)
          .findFirst())!;

  test(
    'matching delayed original receipt retains review and stays pending adoption across restart',
    () async {
      final sent = await attempted();
      final reviewed = await review(sent);
      final saved = await accept(sent);
      expect(saved.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(saved.receiptJson, jsonEncode(acceptance(sent)));
      expect(saved.reviewEvidenceSha256, sent.reviewEvidenceSha256);
      final history = jsonDecode(saved.reviewHistoryJson!) as Map;
      expect(
        history['decisions'],
        (jsonDecode(reviewed.receiptJson!) as Map)['decisions'],
      );
      expect((history['lateAcceptances'] as List).single, acceptance(sent));
      final native = await raw(saved);
      expect(native.acceptedAt?.toUtc(), at);
      expect(
        (jsonDecode(native.receiptJson!) as Map)['kind'],
        reviewedAcceptanceKind,
      );
      expect(
        native.receiptSha256,
        durableSubmissionSha256(native.receiptJson!),
      );
      expect(native.receiptSha256, isNot(saved.receiptSha256));
      await restart();
      final restored = (await store.findUnresolvedForResource(resource))!;
      expect(restored.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(restored.envelopeJson, sent.envelopeJson);
      expect(restored.reviewHistoryJson, saved.reviewHistoryJson);
      expect(
        (await store.claim(
          submissionId: sent.submissionId,
          actorUid: 'origin',
        )).disposition,
        DurableSubmissionClaimDisposition.accepted,
      );
      await expectLater(
        store.prepare(draft('b')),
        throwsA(code('resource-pending')),
      );
      expect((await accept(sent)).receiptJson, saved.receiptJson);
      final reconciled = await store.markReconciled(
        submissionId: saved.submissionId,
        envelopeSha256: saved.envelopeSha256,
        receiptSha256: saved.receiptSha256!,
      );
      expect(reconciled.state, DurableSubmissionState.reconciled);
      expect(reconciled.reviewHistoryJson, saved.reviewHistoryJson);
      await restart();
      expect(
        (await store.read(sent.submissionId))!.reviewHistoryJson,
        saved.reviewHistoryJson,
      );
      expect(
        (await store.prepare(draft('b'))).state,
        DurableSubmissionState.intent,
      );
    },
  );

  test(
    'actual old v12 repository characterizes false conflict; matching retained confirmation can recover',
    () async {
      final sent = await attempted();
      await review(sent);
      final old = LegacyV12DurableSubmissionRepository(database, now: () => at);
      final formerlyConflicted = await old.settleAccepted(
        submissionId: sent.submissionId,
        envelopeSha256: sent.envelopeSha256,
        receiptJson: jsonEncode(acceptance(sent)),
        validateReceipt: validate,
      );
      expect(formerlyConflicted.state, DurableSubmissionState.reviewConflict);
      await restart();
      final confirmed = await accept(sent);
      expect(confirmed.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(confirmed.reviewHistoryJson, formerlyConflicted.receiptJson);
    },
  );

  test(
    'actual old v12 reader retains capsule as accepted unresolved and cannot dispatch or decode it',
    () async {
      final sent = await attempted();
      await review(sent);
      final confirmed = await accept(sent);
      await restart();
      final old = LegacyV12DurableSubmissionRepository(database, now: () => at);
      final priorView = (await old.read(sent.submissionId))!;
      expect(priorView.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(priorView.state.isUnresolved, isTrue);
      await expectLater(
        old.findUnresolvedForResource(resource),
        completion(isNotNull),
      );
      expect(
        (await old.claim(
          submissionId: sent.submissionId,
          actorUid: 'origin',
        )).mayDispatch,
        isFalse,
      );
      expect(
        () => validate(
          priorView,
          jsonDecode(priorView.receiptJson!) as Map<String, dynamic>,
        ),
        throwsA(anything),
      );
      await expectLater(
        old.prepare(draft('b')),
        throwsA(code('resource-pending')),
      );
      await expectLater(
        old.settleAccepted(
          submissionId: sent.submissionId,
          envelopeSha256: sent.envelopeSha256,
          receiptJson: jsonEncode(acceptance(sent)),
          validateReceipt: validate,
        ),
        throwsA(code('acceptance-conflict')),
      );
      expect(
        (await store.read(sent.submissionId))!.reviewHistoryJson,
        confirmed.reviewHistoryJson,
      );
    },
  );

  for (final change in <String, Object?>{
    'actorUid': 'another',
    'operation': 'REGISTER_INNER_COVER',
    'entityId': 'other-cover',
    'version': 5,
    'committedAt': '2026-09-12T10:00:01.000Z',
    'status': 'other',
  }.entries) {
    test(
      'reviewed ${change.key} contradiction retains both outcomes without adoption',
      () async {
        final sent = await attempted();
        final proof = decision(sent);
        (proof['receiptSummary'] as Map)[change.key] = change.value;
        final reviewed = await review(sent, proof);
        final held = await accept(sent);
        expect(held.state, DurableSubmissionState.reviewConflict);
        expect((await raw(held)).acceptedAt, isNull);
        final history = jsonDecode(held.receiptJson!) as Map;
        expect(
          history['decisions'],
          (jsonDecode(reviewed.receiptJson!) as Map)['decisions'],
        );
        expect((history['lateAcceptances'] as List).single, acceptance(sent));
        await restart();
        expect(
          (await store.read(sent.submissionId))!.state,
          DurableSubmissionState.reviewConflict,
        );
        await expectLater(
          review(sent, proof),
          throwsA(code('review-conflict-investigation')),
        );
      },
    );
  }

  test(
    'cancellation remains a contradiction and cannot be cleared by a valid acceptance',
    () async {
      final sent = await attempted();
      final proof = decision(sent, outcome: 'cancelled');
      await review(sent, proof);
      final held = await accept(sent);
      expect(held.state, DurableSubmissionState.reviewConflict);
      await expectLater(
        review(sent, proof),
        throwsA(code('review-conflict-investigation')),
      );
      await expectLater(
        store.prepare(draft('b')),
        throwsA(code('resource-pending')),
      );
    },
  );

  for (final sendB in [false, true]) {
    test(
      'matching A refresh precedes intact ${sendB ? 'claimed' : 'unsent'} B and then B continues',
      () async {
        final a = await attempted();
        await review(a);
        final b = await store.prepare(draft('b'));
        final bClaim = sendB
            ? await store.claim(
                submissionId: b.submissionId,
                actorUid: 'origin',
              )
            : null;
        final beforeB = await raw(b);
        expect((await raw(a)).id, lessThan(beforeB.id));
        final confirmed = await accept(a);
        expect(confirmed.state, DurableSubmissionState.acceptedPendingAdoption);
        expect(confirmed.lastErrorCode, isNull);
        final stopped = (await store.read(b.submissionId))!;
        expect(
          stopped.state,
          sendB
              ? DurableSubmissionState.sending
              : DurableSubmissionState.intent,
        );
        expect(stopped.envelopeJson, b.envelopeJson);
        expect(stopped.claimToken, beforeB.claimToken);
        expect(
          (await store.findUnresolvedForResource(resource))!.submissionId,
          a.submissionId,
        );
        await expectLater(
          store.claim(submissionId: b.submissionId, actorUid: 'origin'),
          throwsA(code('prior-acceptance-pending')),
        );
        await restart();
        expect(
          (await store.read(a.submissionId))!.reviewHistoryJson,
          confirmed.reviewHistoryJson,
        );
        expect(
          (await store.findUnresolvedForResource(resource))!.submissionId,
          a.submissionId,
        );
        await store.markReconciled(
          submissionId: a.submissionId,
          envelopeSha256: a.envelopeSha256,
          receiptSha256: confirmed.receiptSha256!,
        );
        expect(
          (await store.findUnresolvedForResource(resource))!.submissionId,
          b.submissionId,
        );
        if (bClaim != null) {
          expect(
            await store.recordOutcome(
              bClaim,
              state: DurableSubmissionState.uncertain,
              message: 'The original B is still pending.',
            ),
            DurableSubmissionOutcome.recorded,
          );
        }
        expect(
          (await store.claim(
            submissionId: b.submissionId,
            actorUid: 'origin',
          )).mayDispatch,
          isTrue,
        );
        expect(
          (await store.read(b.submissionId))!.envelopeJson,
          b.envelopeJson,
        );
      },
    );
  }

  test(
    'legacy unknown origin and mismatched envelope never acquire acceptance',
    () async {
      final legacy = await store.importLegacyNeedsReview(
        submissionId: 'legacy',
        resourceKey: resource,
        sourceKey: 'legacy-key',
        sourceBytes: Uint8List.fromList(
          utf8.encode('{"requestId":"original-legacy"}'),
        ),
      );
      final proof = decision(legacy)..['requestId'] = 'original-legacy';
      await review(legacy, proof);
      await expectLater(accept(legacy), throwsA(code('invalid-receipt')));
      final row = await attempted();
      await review(row);
      await expectLater(
        store.settleAccepted(
          submissionId: row.submissionId,
          envelopeSha256: '0' * 64,
          receiptJson: jsonEncode(acceptance(row)),
          validateReceipt: validate,
        ),
        throwsA(code('identity-conflict')),
      );
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.reviewResolved,
      );
    },
  );

  test(
    'a second retained server receipt hash is not treated as consistent merely because its summary matches',
    () async {
      final row = await attempted();
      await review(row);
      final second = decision(row)..['receiptSha256'] = 'c' * 64;
      await review(row, second);
      expect((await accept(row)).state, DurableSubmissionState.reviewConflict);
    },
  );

  test(
    'domain rejection cannot be replaced by matching review summary',
    () async {
      final row = await attempted();
      final reviewed = await review(row);
      final invalid = acceptance(row)..['auditId'] = 'unrelated-audit';
      await expectLater(
        store.settleAccepted(
          submissionId: row.submissionId,
          envelopeSha256: row.envelopeSha256,
          receiptJson: jsonEncode(invalid),
          validateReceipt: validate,
        ),
        throwsA(anything),
      );
      expect(
        (await store.read(row.submissionId))!.receiptJson,
        reviewed.receiptJson,
      );
      expect((await raw(row)).acceptedAt, isNull);
    },
  );

  test(
    'different retained late receipt stays blocked even when six summary fields agree',
    () async {
      final row = await attempted();
      await review(row);
      final first = acceptance(row)..['secondaryVersion'] = 8;
      // Model damaged historical evidence, not a receipt accepted by today's
      // strict domain parser. It must not be erased to make the new reply fit.
      final record = await raw(row);
      final history = jsonDecode(record.receiptJson!) as Map<String, dynamic>;
      (history['lateAcceptances'] as List).add(first);
      record.stateKey = DurableSubmissionState.reviewConflict.name;
      record.receiptJson = jsonEncode(history);
      record.receiptSha256 = durableSubmissionSha256(record.receiptJson!);
      await database.writeTxn(
        () => database.durableSubmissionRecords.put(record),
      );
      final held = await accept(row);
      expect(held.state, DurableSubmissionState.reviewConflict);
      expect((jsonDecode(held.receiptJson!) as Map)['lateAcceptances'], [
        first,
        acceptance(row),
      ]);
      await restart();
      expect((await accept(row)).state, DurableSubmissionState.reviewConflict);
    },
  );

  test(
    'failed local adoption retains the capsule and original review on restart',
    () async {
      final row = await attempted();
      await review(row);
      final saved = await accept(row);
      await expectLater(
        store.markReconciled(
          submissionId: saved.submissionId,
          envelopeSha256: saved.envelopeSha256,
          receiptSha256: saved.receiptSha256!,
          adoptInTransaction: (_) async {
            throw StateError('native adoption refused');
          },
        ),
        throwsStateError,
      );
      await restart();
      final restored = (await store.read(row.submissionId))!;
      expect(restored.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(restored.receiptJson, saved.receiptJson);
      expect(restored.reviewHistoryJson, saved.reviewHistoryJson);
    },
  );

  test(
    'a contradictory capsule with a recomputed storage checksum is still refused',
    () async {
      final row = await attempted();
      await review(row);
      await accept(row);
      final record = await raw(row);
      final capsule = jsonDecode(record.receiptJson!) as Map<String, dynamic>;
      final history = capsule['reviewHistory'] as Map;
      (((history['decisions'] as List).single as Map)['receiptSummary']
              as Map)['version'] =
          44;
      record.receiptJson = jsonEncode(capsule);
      record.receiptSha256 = durableSubmissionSha256(record.receiptJson!);
      await database.writeTxn(
        () => database.durableSubmissionRecords.put(record),
      );
      await restart();
      await expectLater(
        store.read(row.submissionId),
        throwsA(code('invalid-review-acceptance')),
      );
      await expectLater(store.prepare(draft('b')), throwsA(anything));
      expect((await raw(row)).receiptJson, record.receiptJson);
    },
  );

  test(
    'an earlier ordinary acceptance has no reviewed-release ordering proof',
    () async {
      final older = await store.prepare(draft('b'));
      final olderClaim = await store.claim(
        submissionId: older.submissionId,
        actorUid: 'origin',
      );
      await store.recordOutcome(
        olderClaim,
        state: DurableSubmissionState.rejected,
        message: 'Apparent refusal.',
      );
      final a = await attempted();
      await review(a);
      await accept((await store.read(older.submissionId))!);
      final saved = await accept(a);
      expect(saved.state, DurableSubmissionState.acceptedPendingAdoption);
      await expectLater(
        store.findUnresolvedForResource(resource),
        throwsA(code('resource-conflict')),
      );
      await expectLater(
        store.markReconciled(
          submissionId: a.submissionId,
          envelopeSha256: a.envelopeSha256,
          receiptSha256: saved.receiptSha256!,
        ),
        throwsA(code('resource-conflict')),
      );
      expect(
        (await store.read(older.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    },
  );

  test(
    'a later imported legacy neighbour cannot be treated as normally admitted B',
    () async {
      final a = await attempted();
      await review(a);
      final legacy = await store.importLegacyNeedsReview(
        submissionId: 'legacy-neighbour',
        resourceKey: resource,
        sourceKey: 'legacy-key',
        sourceBytes: Uint8List.fromList(
          utf8.encode('unattributed original bytes'),
        ),
      );
      final saved = await accept(a);
      await expectLater(
        store.findUnresolvedForResource(resource),
        throwsA(code('resource-conflict')),
      );
      await expectLater(
        store.markReconciled(
          submissionId: a.submissionId,
          envelopeSha256: a.envelopeSha256,
          receiptSha256: saved.receiptSha256!,
        ),
        throwsA(code('resource-conflict')),
      );
      expect(
        (await store.read(legacy.submissionId))!.legacySourceBase64,
        legacy.legacySourceBase64,
      );
    },
  );

  test(
    'real campaign controller adopts delayed reviewed A at current server revision before accepted B, without another send',
    () async {
      final server = _DelayedCampaignServer();
      var probes = 0;
      InspectionCampaignSubmissionController controller() =>
          InspectionCampaignSubmissionController(
            store: store,
            gateway: server,
            reader: server,
            requireActor: () => campaignManager('origin'),
            requireCapability: (_) async {
              probes++;
            },
          );
      final initial = controller();
      Future<DurableSubmission> prepareCampaign(String id) => initial.prepare(
        originActorUid: 'origin',
        payload: campaignCreationPayload(),
        definitionCode: 'FURNACE_PT',
        definitionTitle: 'Pressure setting',
        commandId: 'command-$id',
        campaignId: 'campaign-$id',
      );
      final a = await prepareCampaign('a');
      final aResult = expectLater(
        initial.check(a.submissionId),
        throwsStateError,
      );
      await server.acceptedA.future;
      final attemptedA = (await store.read(a.submissionId))!;
      final proof = decision(attemptedA)
        ..['domain'] = 'inspectionCampaign'
        ..['receiptSummary'] = {
          'actorUid': 'origin',
          'operation': 'createInspectionCampaign',
          'entityId': 'campaign-a',
          'version': 1,
          'committedAt': at.toIso8601String(),
          'status': null,
        };
      await review(attemptedA, proof);
      final b = await prepareCampaign('b');
      server.failRead = true;
      await expectLater(initial.check(b.submissionId), throwsStateError);
      final bAccepted = (await store.read(b.submissionId))!;
      expect(bAccepted.state, DurableSubmissionState.acceptedPendingAdoption);
      // The server has legitimately advanced A since its original creation.
      server.campaigns['campaign-a']!['version'] = 2;
      final exactB = jsonEncode(server.campaigns['campaign-b']);
      server.deliverA.complete();
      await aResult;
      final aAccepted = (await store.read(a.submissionId))!;
      expect(aAccepted.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(aAccepted.reviewHistoryJson, isNotNull);
      expect(
        (await store.read(b.submissionId))!.receiptJson,
        bAccepted.receiptJson,
      );
      final old = LegacyV12DurableSubmissionRepository(database, now: () => at);
      await expectLater(
        old.findUnresolvedForResource(a.resourceKey),
        throwsA(code('resource-conflict')),
      );
      await restart();
      server.failRead = false;
      final resumed = controller();
      expect((await resumed.restore())!.submissionId, a.submissionId);
      final adoptedA = await resumed.check(a.submissionId);
      expect(adoptedA.version, 2);
      expect(jsonEncode(server.campaigns['campaign-b']), exactB);
      expect((await resumed.restore())!.submissionId, b.submissionId);
      final adoptedB = await resumed.check(b.submissionId);
      expect(adoptedB.id, 'campaign-b');
      expect(await resumed.restore(), isNull);
      expect(server.envelopes.length, 2);
      expect(server.campaigns.length, 2);
      expect(probes, 2);
      expect(
        (await store.read(a.submissionId))!.reviewHistoryJson,
        aAccepted.reviewHistoryJson,
      );
    },
  );
}

class _DelayedCampaignServer extends CampaignCreationServer {
  final acceptedA = Completer<void>();
  final deliverA = Completer<void>();

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    final receipt = await super.executeOriginBoundEnvelope(envelopeJson);
    if (receipt.commandId == 'command-a' && !acceptedA.isCompleted) {
      acceptedA.complete();
      await deliverA.future;
    }
    return receipt;
  }
}
