import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_record.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_review.dart';
import 'package:crm3_baf_ops/core/services/saved_submission_review_service.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

/// Adds deterministic account changes immediately after real native awaits.
/// Persistence and all state transitions still execute the production store.
class _AfterNativeAwaitStore extends DurableSubmissionRepository {
  _AfterNativeAwaitStore(super.isar, {required super.now});
  void Function()? afterRead;
  void Function()? afterList;
  void Function()? afterReview;

  @override
  Future<DurableSubmission?> read(String submissionId) async {
    final result = await super.read(submissionId);
    afterRead?.call();
    return result;
  }

  @override
  Future<List<DurableSubmission>> listForAdministrativeReview({
    required void Function() requireReviewer,
  }) async {
    final result = await super.listForAdministrativeReview(
      requireReviewer: requireReviewer,
    );
    afterList?.call();
    return result;
  }

  @override
  Future<DurableSubmission> settleReview({
    required String submissionId,
    required String evidenceSha256,
    required String reviewerUid,
    required String decisionJson,
    required void Function() requireReviewer,
  }) async {
    final result = await super.settleReview(
      submissionId: submissionId,
      evidenceSha256: evidenceSha256,
      reviewerUid: reviewerUid,
      decisionJson: decisionJson,
      requireReviewer: requireReviewer,
    );
    afterReview?.call();
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late AppUser reviewer;
  final instant = DateTime.utc(2026, 9, 13, 2);
  const resource = 'innerCoverAcceptance:cover-a';
  const reason = 'Checked the original evidence and the server result.';
  final token = 'a'.padRight(64, 'a');
  final receiptHash = 'b'.padRight(64, 'b');
  final legacyBytes = Uint8List.fromList(
    utf8.encode(
      ' {\n "journalVersion":1,"savedAtMicros":1234,\n'
      ' "record":{"requestId":"legacy-request","payloadHash":"original hash only",'
      '"note":"Original bytes π"}\n} ',
    ),
  );

  AppUser admin(String uid) => AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: instant,
  );
  void requireAdmin() {
    if (!reviewer.isApproved ||
        !reviewer.isAdmin ||
        reviewer.uid != 'admin-a') {
      throw const DurableSubmissionException(
        'review-admin-required',
        'Original approved administrator required.',
      );
    }
  }

  Matcher code(String expected) => isA<DurableSubmissionException>().having(
    (error) => error.code,
    'code',
    expected,
  );

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'saved_submission_review',
      inspector: false,
    );
    store = DurableSubmissionRepository(database, now: () => instant);
  }

  Future<void> reopen() async {
    await database.close();
    await open();
  }

  Future<DurableSubmissionRecord> persisted(DurableSubmission row) async =>
      (await database.durableSubmissionRecords
          .where()
          .submissionIdEqualTo(row.submissionId)
          .findFirst())!;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('submission_review_');
    reviewer = admin('admin-a');
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<DurableSubmission> legacy() => store.importLegacyNeedsReview(
    submissionId: 'legacy-a',
    resourceKey: resource,
    sourceKey: 'saved_acceptance_legacy_key',
    sourceBytes: legacyBytes,
  );

  DurableSubmissionDraft draft({String id = 'a'}) => DurableSubmissionDraft(
    submissionId: 'submission-$id',
    actorUid: 'admin-a',
    requestId: 'request-$id',
    aggregateId: 'cover-a',
    resourceKey: resource,
    protocol: 'assetHierarchy.v2',
    envelopeJson: jsonEncode({
      'protocolVersion': 2,
      'originActorUid': 'admin-a',
      'request': {
        'requestId': 'request-$id',
        'operation': 'ACCEPT_INNER_COVER',
        'innerCoverId': 'cover-a',
        'expectedVersion': 3,
        'reason': 'Inspection complete',
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

  Future<DurableSubmission> attempted({String id = 'a'}) async {
    final saved = await store.prepare(draft(id: id));
    final claim = await store.claim(
      submissionId: saved.submissionId,
      actorUid: 'admin-a',
    );
    expect(claim.mayDispatch, isTrue);
    await store.recordOutcome(
      claim,
      state: DurableSubmissionState.uncertain,
      message: 'The original response was not received.',
    );
    return (await store.read(saved.submissionId))!;
  }

  Map<String, dynamic> decision(
    DurableSubmission row, {
    String outcome = 'cancelled',
    Map<String, dynamic> changes = const {},
  }) => {
    'schemaVersion': 1,
    'domain': DurableSubmissionReviewTarget.from(row).domain,
    'requestId': DurableSubmissionReviewTarget.from(row).requestId,
    'evidenceSha256': row.reviewEvidenceSha256,
    'originalActorUid': row.actorUid,
    'reviewerUid': 'admin-a',
    'outcome': outcome,
    'decisionId': 'review-decision-${row.submissionId}',
    'decidedAt': instant.toIso8601String(),
    'receiptSha256': outcome == 'reviewedExisting' ? receiptHash : null,
    'receiptSummary': outcome == 'reviewedExisting'
        ? {
            'requestId': DurableSubmissionReviewTarget.from(row).requestId,
            'version': 4,
          }
        : null,
    'reason': reason,
    ...changes,
  };

  Future<DurableSubmission> settle(
    DurableSubmission row, {
    Map<String, dynamic>? proof,
    void Function()? guard,
    String? evidenceHash,
  }) => store.settleReview(
    submissionId: row.submissionId,
    evidenceSha256: evidenceHash ?? row.reviewEvidenceSha256,
    reviewerUid: 'admin-a',
    decisionJson: jsonEncode(proof ?? decision(row)),
    requireReviewer: guard ?? requireAdmin,
  );

  Map<String, dynamic> acceptance(DurableSubmission row) => {
    'ok': true,
    'requestId': row.requestId,
    'operation': 'ACCEPT_INNER_COVER',
    'innerCoverId': 'cover-a',
    'version': 4,
    'secondaryVersion': null,
    'auditId': 'inner_cover_${row.requestId}',
    'committedAt': instant.toIso8601String(),
    'idempotentReplay': false,
  };
  Future<DurableSubmission> accept(DurableSubmission row) =>
      store.settleAccepted(
        submissionId: row.submissionId,
        envelopeSha256: row.envelopeSha256,
        receiptJson: jsonEncode(acceptance(row)),
        validateReceipt: (saved, response) {
          AssetHierarchyMutationReceipt.fromMap(
            response,
            request: Map<String, dynamic>.from(
              saved.envelope['request'] as Map,
            ),
          );
          return true;
        },
      );

  Map<String, dynamic> inspectionResponse(
    DurableSubmission row, {
    bool existing = false,
    Map<String, dynamic> changes = const {},
  }) => {
    'schemaVersion': 1,
    'domain': DurableSubmissionReviewTarget.from(row).domain,
    'requestId': DurableSubmissionReviewTarget.from(row).requestId,
    'evidenceSha256': row.reviewEvidenceSha256,
    'originalActorUid': row.actorUid,
    'reviewerUid': 'admin-a',
    'reviewToken': token,
    'observation': existing ? 'receiptPresent' : 'receiptAbsent',
    'receiptSha256': existing ? receiptHash : null,
    'receiptSummary': existing
        ? {
            'requestId': DurableSubmissionReviewTarget.from(row).requestId,
            'version': 4,
          }
        : null,
    ...changes,
  };

  SavedSubmissionReviewService service({
    DurableSubmissionRepository? repository,
    Future<void> Function(String callable, String uid)? capability,
    required Future<Object?> Function(
      String callable,
      Map<String, dynamic> data,
    )
    invoke,
  }) => SavedSubmissionReviewService(
    store: repository ?? store,
    requireReviewer: () => reviewer,
    requireCapability: capability ?? (_, _) async {},
    invoke: invoke,
  );

  test(
    'legacy review retains NULL origin and exact bytes across reopen and reimport, then permits a new owner',
    () async {
      final row = await legacy();
      final originalEvidenceHash = row.reviewEvidenceSha256;
      final resolved = await settle(row);
      expect(resolved.state, DurableSubmissionState.reviewResolved);
      expect(resolved.state.isAccepted, isFalse);
      expect(resolved.actorUid, isNull);
      expect(
        resolved.requestId,
        'unknown',
        reason: 'Review target extraction never rewrites imported identity.',
      );
      expect(resolved.envelopeJson, '{}');
      expect(base64Decode(resolved.legacySourceBase64!), legacyBytes);
      expect((await persisted(resolved)).acceptedAt, isNull);
      expect(await store.findUnresolvedForResource(resource), isNull);
      await reopen();
      final restored = (await store.read(row.submissionId))!;
      expect(restored.reviewEvidenceSha256, originalEvidenceHash);
      expect(restored.receiptJson, resolved.receiptJson);
      expect((await legacy()).state, DurableSubmissionState.reviewResolved);
      expect(base64Decode((await legacy()).legacySourceBase64!), legacyBytes);
      expect((await store.prepare(draft())).resourceKey, resource);
      expect(await database.durableSubmissionRecords.count(), 2);
    },
  );

  test(
    'reviewed existing server result is a review proof, not invented local business acceptance',
    () async {
      final row = await legacy();
      final resolved = await settle(
        row,
        proof: decision(row, outcome: 'reviewedExisting'),
      );
      expect(resolved.state, DurableSubmissionState.reviewResolved);
      expect((await persisted(resolved)).acceptedAt, isNull);
      final history = jsonDecode(resolved.receiptJson!) as Map;
      expect(history['kind'], 'savedSubmissionReview');
      expect(
        (history['decisions'] as List).single['receiptSha256'],
        receiptHash,
      );
      await reopen();
      expect(
        (await store.read(row.submissionId))!.receiptJson,
        resolved.receiptJson,
      );
      await expectLater(
        store.markReconciled(
          submissionId: row.submissionId,
          envelopeSha256: row.envelopeSha256,
          receiptSha256: resolved.receiptSha256!,
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
    },
  );

  for (final change in <String, Map<String, dynamic>>{
    'wrong original actor': {'originalActorUid': 'invented-origin'},
    'wrong reviewer': {'reviewerUid': 'admin-b'},
    'wrong evidence': {'evidenceSha256': '0'.padRight(64, '0')},
    'wrong request': {'requestId': 'another-request'},
    'wrong domain': {'domain': 'morningReview'},
    'impossible calendar date': {'decidedAt': '2026-02-30T00:00:00.000Z'},
    'offset timestamp instead of canonical UTC': {
      'decidedAt': '2026-09-13T02:00:00.000+00:00',
    },
    'timestamp without milliseconds': {'decidedAt': '2026-09-13T02:00:00Z'},
    'unproved cancellation with receipt': {
      'receiptSummary': {'accepted': true},
    },
  }.entries) {
    test('${change.key} cannot release a legacy hold', () async {
      final row = await legacy();
      await expectLater(
        settle(row, proof: decision(row, changes: change.value)),
        throwsA(code('invalid-review-decision')),
      );
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.needsReview,
      );
      expect(
        (await store.findUnresolvedForResource(resource))!.submissionId,
        row.submissionId,
      );
      expect((await store.read(row.submissionId))!.receiptJson, isNull);
    });
  }

  test('changed caller evidence hash keeps original proof and hold', () async {
    final row = await legacy();
    await expectLater(
      settle(row, evidenceHash: 'wrong'),
      throwsA(code('review-evidence-changed')),
    );
    expect(
      (await store.read(row.submissionId))!.legacySourceBase64,
      row.legacySourceBase64,
    );
    expect(
      (await store.read(row.submissionId))!.state,
      DurableSubmissionState.needsReview,
    );
  });

  for (final checkpoint in [1, 2, 3]) {
    test(
      'admin change at native review guard $checkpoint leaves the transaction unresolved',
      () async {
        final row = await legacy();
        var calls = 0;
        await expectLater(
          settle(
            row,
            guard: () {
              calls++;
              if (calls == checkpoint) reviewer = admin('admin-b');
              requireAdmin();
            },
          ),
          throwsA(code('review-admin-required')),
        );
        expect(calls, checkpoint);
        await reopen();
        final restored = (await store.read(row.submissionId))!;
        expect(restored.state, DurableSubmissionState.needsReview);
        expect(restored.receiptJson, isNull);
        expect(restored.legacySourceBase64, row.legacySourceBase64);
      },
    );
  }

  test(
    'accepted before local review settlement always keeps acceptance',
    () async {
      final row = await attempted();
      final oldDecision = decision(row);
      final accepted = await accept(row);
      await expectLater(
        settle(row, proof: oldDecision),
        throwsA(code('accepted-needs-adoption')),
      );
      await reopen();
      final restored = (await store.read(row.submissionId))!;
      expect(restored.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(restored.receiptJson, accepted.receiptJson);
      expect((await persisted(restored)).acceptedAt, isNotNull);
    },
  );

  test(
    'review followed by valid late acceptance retains both and stale review cannot release the conflict',
    () async {
      final row = await attempted();
      final oldDecision = decision(row);
      final resolved = await settle(row, proof: oldDecision);
      final conflict = await accept(row);
      expect(conflict.state, DurableSubmissionState.reviewConflict);
      expect((await persisted(conflict)).acceptedAt, isNull);
      final history = jsonDecode(conflict.receiptJson!) as Map;
      expect(
        history['decisions'],
        (jsonDecode(resolved.receiptJson!) as Map)['decisions'],
      );
      expect((history['lateAcceptances'] as List).single, acceptance(row));
      await expectLater(
        settle(row, proof: oldDecision),
        throwsA(code('review-conflict-investigation')),
      );
      await expectLater(
        store.prepare(draft(id: 'b')),
        throwsA(code('resource-pending')),
      );
      await reopen();
      expect(
        (await store.read(row.submissionId))!.receiptJson,
        conflict.receiptJson,
      );
      expect(
        (await store.claim(
          submissionId: row.submissionId,
          actorUid: 'admin-a',
        )).mayDispatch,
        isFalse,
      );
    },
  );

  test(
    'late A and replacement B acceptance leave both readable without demoting reviewed proof',
    () async {
      final a = await attempted();
      await settle(a);
      final b = await attempted(id: 'b');
      final lateA = await accept(a);
      expect(lateA.state, DurableSubmissionState.reviewConflict);
      final acceptedB = await accept(b);
      expect(acceptedB.state, DurableSubmissionState.acceptedPendingAdoption);
      await reopen();
      final restoredA = (await store.read(a.submissionId))!;
      final restoredB = (await store.read(b.submissionId))!;
      expect(restoredA.state, DurableSubmissionState.reviewConflict);
      expect(restoredA.receiptJson, lateA.receiptJson);
      expect(restoredB.receiptJson, acceptedB.receiptJson);
      await expectLater(
        store.findUnresolvedForResource(resource),
        throwsA(code('resource-conflict')),
      );
      await expectLater(
        store.markReconciled(
          submissionId: b.submissionId,
          envelopeSha256: b.envelopeSha256,
          receiptSha256: restoredB.receiptSha256!,
        ),
        throwsA(code('resource-conflict')),
      );
    },
  );

  test(
    'service inspect and finalize preserve reason, exact evidence and server token',
    () async {
      final row = await legacy();
      final calls = <Map<String, dynamic>>[];
      final probes = <String>[];
      final owner = service(
        capability: (callable, uid) async {
          probes.add('$callable/$uid');
        },
        invoke: (callable, data) async {
          expect(callable, 'mutateAssetHierarchyV2');
          calls.add(
            Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map),
          );
          final request = data['recovery'] as Map;
          return request['phase'] == 'inspect'
              ? inspectionResponse(row)
              : decision(row);
        },
      );
      final inspected = await owner.inspect(row, '  $reason  ');
      expect(inspected.reason, reason);
      expect(
        () => inspected.response['reviewToken'] = 'changed',
        throwsUnsupportedError,
      );
      await owner.finalize(inspected);
      expect(probes, [
        'mutateAssetHierarchyV2/admin-a',
        'mutateAssetHierarchyV2/admin-a',
      ]);
      expect(calls, hasLength(2));
      final first = calls.first['recovery'] as Map;
      final last = calls.last['recovery'] as Map;
      expect(calls.last['originActorUid'], 'admin-a');
      expect(first['originalActorUid'], isNull);
      expect(last['originalActorUid'], isNull);
      expect(first['requestId'], 'legacy-request');
      expect(last['requestId'], 'legacy-request');
      expect(last['evidenceSha256'], row.reviewEvidenceSha256);
      expect(last['reason'], reason);
      expect(first.containsKey('reviewToken'), isFalse);
      expect(last['reviewToken'], token);
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.reviewResolved,
      );
    },
  );

  for (final field in [
    'originalActorUid',
    'evidenceSha256',
    'requestId',
    'reviewToken',
  ]) {
    test(
      'service rejects changed $field at inspection before finalization',
      () async {
        final row = await legacy();
        final owner = service(
          invoke: (_, _) async => inspectionResponse(
            row,
            changes: {field: field == 'reviewToken' ? 'not-a-token' : 'other'},
          ),
        );
        await expectLater(
          owner.inspect(row, reason),
          throwsA(code('invalid-review-inspection')),
        );
        expect(
          (await store.read(row.submissionId))!.state,
          DurableSubmissionState.needsReview,
        );
      },
    );
  }

  for (final change in <String, Map<String, dynamic>>{
    'reason': {'reason': 'A different decision reason'},
    'original actor': {'originalActorUid': 'invented-origin'},
    'evidence': {'evidenceSha256': '0'.padRight(64, '0')},
    'request': {'requestId': 'different-request'},
  }.entries) {
    test(
      'service finalization rejects changed ${change.key} and retains hold',
      () async {
        final row = await legacy();
        final owner = service(
          invoke: (_, data) async =>
              (data['recovery'] as Map)['phase'] == 'inspect'
              ? inspectionResponse(row)
              : decision(row, changes: change.value),
        );
        final inspected = await owner.inspect(row, reason);
        await expectLater(
          owner.finalize(inspected),
          throwsA(isA<DurableSubmissionException>()),
        );
        expect(
          (await store.read(row.submissionId))!.state,
          DurableSubmissionState.needsReview,
        );
        expect((await store.read(row.submissionId))!.receiptJson, isNull);
      },
    );
  }

  test(
    'late acceptance between inspect and finalize blocks stale service decision without invoking finalize',
    () async {
      final row = await attempted();
      var calls = 0;
      final owner = service(
        invoke: (_, _) async {
          calls++;
          return inspectionResponse(row);
        },
      );
      final inspected = await owner.inspect(row, reason);
      await settle(row);
      await accept(row);
      await expectLater(
        owner.finalize(inspected),
        throwsA(code('review-outcome-changed')),
      );
      expect(calls, 1);
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.reviewConflict,
      );
    },
  );

  test(
    'account changes after native list/read awaits prevent administrative disclosure or finalization',
    () async {
      final row = await legacy();
      final guarded = _AfterNativeAwaitStore(database, now: () => instant);
      var invocations = 0;
      final owner = service(
        repository: guarded,
        invoke: (_, _) async {
          invocations++;
          return inspectionResponse(row);
        },
      );
      guarded.afterList = () => reviewer = admin('admin-b');
      await expectLater(owner.list(), throwsA(code('review-admin-required')));
      reviewer = admin('admin-a');
      guarded.afterList = null;
      final inspected = await owner.inspect(row, reason);
      guarded.afterRead = () => reviewer = admin('admin-b');
      await expectLater(
        owner.finalize(inspected),
        throwsA(code('review-admin-required')),
      );
      expect(invocations, 1);
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.needsReview,
      );
    },
  );

  test(
    'account changes after committed native review withhold result but preserve authorized proof',
    () async {
      final row = await legacy();
      final guarded = _AfterNativeAwaitStore(database, now: () => instant);
      final owner = service(
        repository: guarded,
        invoke: (_, data) async =>
            (data['recovery'] as Map)['phase'] == 'inspect'
            ? inspectionResponse(row)
            : decision(row),
      );
      final inspected = await owner.inspect(row, reason);
      guarded.afterReview = () => reviewer = admin('admin-b');
      await expectLater(
        owner.finalize(inspected),
        throwsA(code('review-admin-required')),
      );
      await reopen();
      final restored = (await store.read(row.submissionId))!;
      expect(restored.state, DurableSubmissionState.reviewResolved);
      expect(restored.actorUid, isNull);
      expect(
        (jsonDecode(restored.receiptJson!)['decisions'] as List)
            .single['reviewerUid'],
        'admin-a',
      );
    },
  );

  test(
    'account change during capability probing cannot dispatch review',
    () async {
      final row = await legacy();
      var calls = 0;
      final owner = service(
        capability: (_, _) async => reviewer = admin('admin-b'),
        invoke: (_, _) async {
          calls++;
          return inspectionResponse(row);
        },
      );
      await expectLater(
        owner.inspect(row, reason),
        throwsA(code('review-admin-required')),
      );
      expect(calls, 0);
    },
  );

  test(
    'malformed legacy bytes remain retained and cannot be assigned a guessed origin or request',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('{ malformed legacy bytes'));
      final row = await store.importLegacyNeedsReview(
        submissionId: 'bad-legacy',
        resourceKey: resource,
        sourceKey: 'bad-source',
        sourceBytes: bytes,
      );
      var calls = 0;
      final owner = service(
        invoke: (_, _) async {
          calls++;
          return {};
        },
      );
      await expectLater(
        owner.inspect(row, reason),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(calls, 0);
      await reopen();
      final restored = (await store.read(row.submissionId))!;
      expect(restored.actorUid, isNull);
      expect(restored.requestId, 'unknown');
      expect(base64Decode(restored.legacySourceBase64!), bytes);
      expect(restored.state, DurableSubmissionState.needsReview);
    },
  );

  test(
    'lost final reply is recovered by fresh inspection without repeating cancellation or replacing original reason',
    () async {
      final row = await legacy();
      Map<String, dynamic>? committedDecision;
      var finalizations = 0;
      final calls = <Map<String, dynamic>>[];
      Future<Object?> invoke(String callable, Map<String, dynamic> data) async {
        final request = Map<String, dynamic>.from(data['recovery'] as Map);
        calls.add(request);
        if (request['phase'] == 'inspect') {
          return committedDecision ?? inspectionResponse(row);
        }
        finalizations++;
        committedDecision = decision(row);
        throw StateError('The server committed, but its final reply was lost.');
      }

      final first = service(invoke: invoke);
      final inspection = await first.inspect(row, reason);
      await expectLater(first.finalize(inspection), throwsStateError);
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.needsReview,
      );
      expect(finalizations, 1);
      await reopen();
      final restarted = service(invoke: invoke);
      final retained = (await store.read(row.submissionId))!;
      const newNote =
          'Rechecked this saved item after restarting the application.';
      final recovered = await restarted.inspect(retained, newNote);
      expect(recovered.alreadyResolved, isTrue);
      expect(recovered.reason, reason);
      expect(recovered.response['reason'], reason);
      expect(calls.last['reason'], newNote);
      expect(calls.last['phase'], 'inspect');
      final settled = await restarted.finalize(recovered);
      expect(
        finalizations,
        1,
        reason: 'Completed-proof replay never creates another cancellation.',
      );
      expect(calls, hasLength(3));
      expect(settled.state, DurableSubmissionState.reviewResolved);
      expect(settled.actorUid, isNull);
      final decisions = jsonDecode(settled.receiptJson!)['decisions'] as List;
      expect(decisions, [committedDecision]);
      expect(await store.findUnresolvedForResource(resource), isNull);
      await reopen();
      expect(
        (await store.read(row.submissionId))!.receiptJson,
        settled.receiptJson,
      );
    },
  );

  test(
    'completed inspection proof with a fabricated legacy origin cannot clear the hold',
    () async {
      final row = await legacy();
      final owner = service(
        invoke: (_, _) async => decision(
          row,
          changes: {'originalActorUid': 'guessed-original-actor'},
        ),
      );
      await expectLater(
        owner.inspect(row, reason),
        throwsA(code('invalid-review-decision')),
      );
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.needsReview,
      );
      expect((await store.read(row.submissionId))!.receiptJson, isNull);
    },
  );
}
