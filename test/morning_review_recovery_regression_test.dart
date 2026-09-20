import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/morning_review/data/morning_review_rows.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/morning_review_recovery_actual_handler.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final uid = fixture['actorUid'] as String;
  late Directory directory;
  late Isar db;
  late DurableSubmissionRepository store;
  Future<void> open() async {
    db = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'morning_audit',
      inspector: false,
    );
    store = DurableSubmissionRepository(db);
  }

  Future<void> reopen() async {
    await db.close();
    await open();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('morning_audit_');
    await open();
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<DurableSubmission> saved(
    String key, {
    Map<String, dynamic>? receipt,
  }) async {
    final request = fixture[key] as Map;
    final id = request['requestId'] as String;
    final row = await store.prepare(
      DurableSubmissionDraft(
        submissionId: id,
        actorUid: uid,
        requestId: id,
        aggregateId: request['sessionId'] as String? ?? id,
        resourceKey: 'morningReview:$uid',
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': uid,
          'request': request,
        }),
      ),
    );
    final claim = await store.claim(submissionId: id, actorUid: uid);
    if (receipt == null) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message: 'Reply lost',
      );
    } else {
      await store.settleAccepted(
        submissionId: id,
        envelopeSha256: row.envelopeSha256,
        receiptJson: jsonEncode(receipt),
        validateReceipt: (_, __) => true,
      );
    }
    return (await store.read(id))!;
  }

  MorningReviewCommandService service(
    Future<Object?> Function(Map<String, dynamic>) invoke,
  ) => MorningReviewCommandService(
    actorScope: uid,
    durableStore: store,
    verifyAcceptanceEvidence: true,
    requireActor: () => AppUser(
      uid: uid,
      name: 'Admin',
      email: 'admin@example.test',
      roles: [AppRole.admin],
      isApproved: true,
      createdAt: DateTime.utc(2026),
    ),
    requireCapability: (_) async {},
    callableInvoker: invoke,
    readSubject: (_, __) async => throw StateError(
      'Display record expired; must use exact acceptance proof',
    ),
  );

  test(
    'actual canonical acceptance reconciles after native restart without comparing outdated registry labels',
    () async {
      final row = await saved(
        'normalizedRequest',
        receipt: fixture['normalizedReceipt'] as Map<String, dynamic>,
      );
      await reopen();
      var calls = 0;
      final result = await service((envelope) async {
        calls++;
        expect(envelope['receiptLookup'], {
          'acceptanceEvidence': true,
          'request': fixture['normalizedRequest'],
        });
        return fixture['normalizationProof'];
      }).reconcilePending();
      expect(
        result!.entityId,
        (fixture['normalizedReceipt'] as Map)['entityId'],
      );
      expect(calls, 1);
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(
        (row.envelope['request'] as Map)['actionDraft']['assetClassName'],
        'Old registry label',
      );
    },
  );

  test(
    'a proof for different wording cannot release accepted pending adoption',
    () async {
      final row = await saved(
        'normalizedRequest',
        receipt: fixture['normalizedReceipt'] as Map<String, dynamic>,
      );
      final proof =
          jsonDecode(jsonEncode(fixture['normalizationProof']))
              as Map<String, dynamic>;
      (proof['acceptanceBasis']['request']['actionDraft'] as Map)['text'] =
          'Other work';
      await expectLater(
        service((_) async => proof).reconcilePending(),
        throwsA(isA<MorningReviewCommandException>()),
      );
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    },
  );

  test(
    'actual server-fenced refusal preserves original text and frees the resource after native restart',
    () async {
      final row = await saved('refusedRequest');
      await reopen();
      final refusal = fixture['refusal'] as Map;
      final commands = service((envelope) async {
        expect(envelope['request'], fixture['refusedRequest']);
        throw FirebaseFunctionsException(
          code: refusal['code'] as String,
          message: refusal['message'] as String,
          details: refusal['details'],
        );
      });
      await expectLater(
        commands.reconcilePending(),
        throwsA(
          isA<MorningReviewCommandException>().having(
            (e) => e.code,
            'code',
            'business-refused',
          ),
        ),
      );
      await reopen();
      final retained = (await store.read(row.submissionId))!;
      expect(retained.state, DurableSubmissionState.rejected);
      expect(retained.envelopeJson, row.envelopeJson);
      expect(
        (retained.envelope['request'] as Map)['summary'],
        'Carefully written original summary',
      );
      expect(await store.findUnresolvedForResource(row.resourceKey), isNull);
    },
  );

  test(
    'an unproven aborted response remains uncertain and retains the same identity',
    () async {
      final row = await saved('refusedRequest');
      await expectLater(
        service(
          (_) async => throw FirebaseFunctionsException(
            code: 'aborted',
            message: 'Conflict without proof',
          ),
        ).reconcilePending(),
        throwsA(
          isA<MorningReviewCommandException>().having(
            (e) => e.code,
            'code',
            'outcome-uncertain',
          ),
        ),
      );
      expect(
        (await store.findUnresolvedForResource(row.resourceKey))!.requestId,
        row.requestId,
      );
    },
  );

  test(
    'actual cancellation is separate from completion and reconciles by immutable proof',
    () async {
      final action = MorningReviewAction.fromMap(
        fixture['cancelledAction'] as Map<String, dynamic>,
        (fixture['cancelledAction'] as Map)['actionId'] as String,
      );
      expect(action.status, MorningReviewActionStatus.cancelled);
      expect(action.isTerminal, isTrue);
      expect(action.completedAt, isNull);
      final row = await saved(
        'cancelRequest',
        receipt: fixture['cancelReceipt'] as Map<String, dynamic>,
      );
      await reopen();
      await service((_) async => fixture['cancelProof']).reconcilePending();
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
      final damaged = Map<String, dynamic>.from(
        fixture['cancelledAction'] as Map,
      )..remove('cancellation');
      expect(
        () => MorningReviewAction.fromMap(damaged, action.actionId),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'unfinished modern session accepts explicit retained expiry and rejects missing retention field',
    () {
      final map = fixture['openSession'] as Map<String, dynamic>;
      expect(
        MorningReviewSession.fromMap(map, map['sessionId'] as String).expiresAt,
        isNull,
      );
      expect(
        () => MorningReviewSession.fromMap(
          {...map}..remove('expiresAt'),
          map['sessionId'] as String,
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'one malformed action preserves valid rows and exposes incompleteness',
    () {
      final good = fixture['normalizedAction'] as Map<String, dynamic>;
      final rows = decodeMorningReviewRows([
        (id: good['actionId'] as String, data: good),
        (id: 'broken', data: <String, dynamic>{'status': 'completed'}),
      ], MorningReviewAction.fromMap);
      expect(rows, hasLength(1));
      expect(rows.rejectedIds, ['broken']);
      expect(morningReviewRejectedCount(rows), 1);
    },
  );
}
