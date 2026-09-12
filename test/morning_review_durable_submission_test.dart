import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_service.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_idempotency_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late MorningReviewCommandService service;
  late AppUser actor;
  late Map<String, dynamic> accepted;
  late Map<String, dynamic> subject;
  final envelopes = <String>[];
  var mutations = 0;
  var probes = 0;
  var reads = 0;
  var loseResponse = false;
  var failRead = false;
  var badResponse = false;
  var accountUnavailable = false;
  Future<void> Function()? duringProbe;
  Future<void> Function()? duringInvoke;
  const session = '2026-08-31';
  const input = MorningReviewEntryInput(
    section: MorningReviewSection.plantWide,
    kind: MorningReviewEntryKind.update,
    text: 'Original retained contribution',
  );
  AppUser user(String uid) => AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'morning_durable',
      inspector: false,
    );
    store = DurableSubmissionRepository(database);
    service = MorningReviewCommandService(
      actorScope: 'actor-a',
      durableStore: store,
      requireActor: () {
        if (accountUnavailable) {
          throw const MorningReviewCommandException(
            'Account refresh unavailable',
          );
        }
        return actor;
      },
      requireCapability: (uid) async {
        probes++;
        await duringProbe?.call();
      },
      callableInvoker: (envelope) async {
        envelopes.add(jsonEncode(envelope));
        final request = Map<String, dynamic>.from(envelope['request'] as Map);
        if (mutations == 0) {
          mutations++;
          accepted = {
            'ok': true,
            'requestId': request['requestId'],
            'operation': request['operation'],
            'sessionId': request['sessionId'] ?? session,
            'entityId': request['requestId'],
            'status': 'recorded',
            'version': 2,
            'committedAt': '2026-08-31T03:00:00.000Z',
            'idempotentReplay': false,
          };
          subject = {
            'schemaVersion': 1,
            'entryId': request['requestId'],
            'sessionId': session,
            'plantDay': session,
            ...Map<String, dynamic>.from(request['entryDraft'] as Map),
            'authorUid': 'actor-a',
            'authorName': 'actor-a',
            'authorRoleKeys': ['admin'],
            'createdAt': accepted['committedAt'],
            'addendumReason': null,
            'expiresAt': '2026-09-14T03:00:00.000Z',
          };
        }
        await duringInvoke?.call();
        if (loseResponse) {
          loseResponse = false;
          throw StateError('response lost after commit');
        }
        return {
          ...accepted,
          'idempotentReplay': envelopes.length > 1,
          if (badResponse) 'entityId': 'wrong-entry',
        };
      },
      readSubject: (collection, id) async {
        reads++;
        expect(collection, 'morning_review_entries');
        expect(id, accepted['entityId']);
        if (failRead) throw StateError('offline readback');
        return subject;
      },
    );
  }

  Future<void> reopen() async {
    await database.close();
    await open();
  }

  Future<MorningReviewCommandResult> send() =>
      service.addEntry(sessionId: session, entry: input);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('morning_durable_');
    actor = user('actor-a');
    accepted = {};
    subject = {};
    envelopes.clear();
    mutations = 0;
    probes = 0;
    reads = 0;
    loseResponse = false;
    failRead = false;
    badResponse = false;
    accountUnavailable = false;
    duringProbe = null;
    duringInvoke = null;
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });

  test(
    'lost response has one dispatch; reopen restores exact payload and explicit check replays once',
    () async {
      loseResponse = true;
      await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
      expect(envelopes, hasLength(1));
      final original = await service.pendingSubmission();
      expect(original!.state, DurableSubmissionState.uncertain);
      await reopen();
      final restored = await service.pendingSubmission();
      expect(restored!.envelopeJson, original.envelopeJson);
      expect(envelopes, hasLength(1)); // reading saved state cannot dispatch
      final result = await service.reconcilePending();
      expect(result!.requestId, original.requestId);
      expect(envelopes, [original.envelopeJson, original.envelopeJson]);
      expect(mutations, 1);
      expect(
        (await store.read(original.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect((await store.read(original.submissionId))!.receiptJson, isNotNull);
    },
  );

  test(
    'accepted response is durable before readback; reopen does not probe or resend',
    () async {
      failRead = true;
      await expectLater(send(), throwsA(isA<StateError>()));
      final saved = (await service.pendingSubmission())!;
      expect(saved.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(saved.receiptJson, isNotNull);
      await reopen();
      failRead = false;
      await service.reconcilePending();
      expect(envelopes, hasLength(1));
      expect(probes, 1);
      expect(mutations, 1);
    },
  );

  test(
    'changed new input does not replay old work or allocate a replacement',
    () async {
      loseResponse = true;
      await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
      final saved = (await service.pendingSubmission())!;
      await expectLater(
        service.join(session),
        throwsA(
          isA<MorningReviewCommandException>().having(
            (error) => error.code,
            'code',
            'prior-command-pending',
          ),
        ),
      );
      expect(envelopes, hasLength(1));
      expect(
        (await service.pendingSubmission())!.envelopeJson,
        saved.envelopeJson,
      );
    },
  );

  test(
    'origin changes during capability check: prepared intent retained, zero business calls',
    () async {
      duringProbe = () async {
        actor = user('actor-b');
      };
      await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
      expect(envelopes, isEmpty);
      expect(
        (await store.findUnresolvedForResource('morningReview:actor-a'))!.state,
        DurableSubmissionState.intent,
      );
      actor = user('actor-a');
      duringProbe = null;
      await service.reconcilePending();
      expect(mutations, 1);
    },
  );

  test(
    'account error refuses saved dispatch and does not replace old actor',
    () async {
      loseResponse = true;
      await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
      accountUnavailable = true;
      await expectLater(
        service.reconcilePending(),
        throwsA(isA<MorningReviewCommandException>()),
      );
      expect(envelopes, hasLength(1));
      accountUnavailable = false;
      await service.reconcilePending();
      expect(mutations, 1);
    },
  );

  test(
    'valid late receipt survives account change and next original actor only adopts',
    () async {
      duringInvoke = () async {
        actor = user('actor-b');
      };
      await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
      final saved = await store.findUnresolvedForResource(
        'morningReview:actor-a',
      );
      expect(saved!.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(saved.receiptJson, isNotNull);
      expect(reads, 0);
      actor = user('actor-a');
      duringInvoke = null;
      await service.reconcilePending();
      expect(envelopes, hasLength(1));
      expect(probes, 1);
    },
  );

  test(
    'wrong receipt entity cannot settle and same original request remains retryable',
    () async {
      badResponse = true;
      await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
      expect(
        (await service.pendingSubmission())!.state,
        DurableSubmissionState.uncertain,
      );
      badResponse = false;
      await service.reconcilePending();
      expect(envelopes.toSet(), hasLength(1));
      expect(mutations, 1);
    },
  );

  test(
    'corrupt subject attribution leaves accepted receipt pending with no resubmission',
    () async {
      failRead = true;
      await expectLater(send(), throwsA(isA<StateError>()));
      failRead = false;
      subject['authorUid'] = 'actor-b';
      await expectLater(
        service.reconcilePending(),
        throwsA(isA<MorningReviewCommandException>()),
      );
      expect(
        (await service.pendingSubmission())!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect(envelopes, hasLength(1));
      expect(probes, 1);
    },
  );

  test('concurrent explicit checks share one durable dispatch claim', () async {
    loseResponse = true;
    await expectLater(send(), throwsA(isA<MorningReviewCommandException>()));
    final gate = Completer<void>();
    final entered = Completer<void>();
    duringInvoke = () {
      entered.complete();
      return gate.future;
    };
    final first = service.reconcilePending();
    await entered.future;
    await expectLater(
      service.reconcilePending(),
      throwsA(isA<MorningReviewCommandException>()),
    );
    gate.complete();
    await first;
    expect(envelopes, hasLength(2));
    expect(mutations, 1);
  });

  test(
    'old preference bytes imported needsReview without inventing origin or dispatch',
    () async {
      final legacy = MorningReviewCommandIdempotencyStore();
      await legacy.resolve(
        actorUid: 'actor-a',
        operation: MorningReviewCommand.start.wireName,
        sessionId: null,
        extra: {},
      );
      final preferences = await SharedPreferences.getInstance();
      final key = preferences.getKeys().single;
      final bytes = preferences.getString(key)!;
      final saved = (await service.pendingSubmission())!;
      expect(saved.isLegacy, isTrue);
      expect(saved.actorUid, isNull);
      expect(utf8.decode(base64Decode(saved.legacySourceBase64!)), bytes);
      await expectLater(
        service.reconcilePending(),
        throwsA(isA<MorningReviewCommandException>()),
      );
      expect(envelopes, isEmpty);
      expect(probes, 0);
      expect(preferences.getString(key), bytes);
      await reopen();
      expect(
        (await service.pendingSubmission())!.submissionId,
        saved.submissionId,
      );
    },
  );

  test(
    'late original response and accepted replay normalize only replay flag without conflicting',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      duringInvoke = () {
        entered.complete();
        return release.future;
      };
      final first = send();
      await entered.future;
      final saved = (await service.pendingSubmission())!;
      final laterStore = DurableSubmissionRepository(
        database,
        now: () => DateTime.now().add(const Duration(minutes: 10)),
      );
      final laterService = MorningReviewCommandService(
        actorScope: 'actor-a',
        durableStore: laterStore,
        requireActor: () => actor,
        requireCapability: (_) async {},
        callableInvoker: (envelope) async {
          expect(jsonEncode(envelope), saved.envelopeJson);
          return {...accepted, 'idempotentReplay': true};
        },
        readSubject: (_, __) async => subject,
      );
      await laterService.reconcilePending();
      release.complete();
      await first;
      final reconciled = (await store.read(saved.submissionId))!;
      expect(reconciled.state, DurableSubmissionState.reconciled);
      final receipt =
          jsonDecode(reconciled.receiptJson!) as Map<String, dynamic>;
      expect(receipt, accepted);
      expect(receipt['idempotentReplay'], false);
      expect(mutations, 1);
    },
  );

  for (final attempted in [false, true]) {
    test(
      'sessionless older-day ${attempted ? 'unknown' : 'unsent'} cannot create a new day',
      () async {
        final originalDay = DateTime.utc(2026, 8, 31, 3);
        final dayStore = DurableSubmissionRepository(
          database,
          now: () => originalDay,
        );
        const id = '12345678-1111-4111-8111-111111111111';
        final saved = await dayStore.prepare(
          DurableSubmissionDraft(
            submissionId: id,
            actorUid: 'actor-a',
            requestId: id,
            aggregateId: id,
            resourceKey: 'morningReview:actor-a',
            protocol: 'assetHierarchy.v2',
            envelopeJson: jsonEncode({
              'protocolVersion': 2,
              'originActorUid': 'actor-a',
              'request': {'requestId': id, 'operation': 'START_MORNING_REVIEW'},
            }),
          ),
        );
        if (attempted) {
          final claim = await dayStore.claim(
            submissionId: id,
            actorUid: 'actor-a',
          );
          await dayStore.recordOutcome(
            claim,
            state: DurableSubmissionState.uncertain,
            errorCode: 'lost',
            message: 'Unknown outcome',
          );
        }
        final nextDayService = MorningReviewCommandService(
          actorScope: 'actor-a',
          durableStore: dayStore,
          requireActor: () => actor,
          requireCapability: (_) async {
            probes++;
          },
          callableInvoker: (envelope) async {
            expect(envelope.keys, contains('receiptLookup'));
            expect(envelope.keys, isNot(contains('request')));
            reads++;
            throw StateError(
              'No receipt found; absence does not authorize a new request',
            );
          },
          now: () => originalDay.add(const Duration(days: 1)),
        );
        await expectLater(
          nextDayService.reconcilePending(),
          throwsA(
            isA<MorningReviewCommandException>().having(
              (error) => error.code,
              'code',
              attempted ? 'outcome-uncertain' : 'sessionless-day-changed',
            ),
          ),
        );
        expect(mutations, 0);
        expect(probes, attempted ? 1 : 0);
        expect(reads, attempted ? 1 : 0);
        if (attempted) {
          await expectLater(
            nextDayService.cancelNeverSent(),
            throwsA(isA<DurableSubmissionException>()),
          );
          expect(
            (await dayStore.read(saved.submissionId))!.state,
            DurableSubmissionState.uncertain,
          );
        } else {
          await nextDayService.cancelNeverSent();
          expect(
            (await dayStore.read(saved.submissionId))!.state,
            DurableSubmissionState.cancelledBeforeSend,
          );
        }
      },
    );
  }

  final fixture =
      jsonDecode(
            File(
              'test/fixtures/morning_review_durable_actual_handler.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final records = (fixture['records'] as List).cast<Map<String, dynamic>>();
  final advanced = (fixture['advancedSubjects'] as List)
      .cast<Map<String, dynamic>>();

  for (final intendedDay in [false, true]) {
    test(
      'lost sessionless reply crosses India day through receipt lookup only (date-bound=$intendedDay)',
      () async {
        final record = records.singleWhere(
          (row) => row['request']['operation'] == 'START_MORNING_REVIEW',
        );
        final request = Map<String, dynamic>.from(record['request'] as Map);
        final receipt = Map<String, dynamic>.from(record['receipt'] as Map);
        final acceptedAt = DateTime.parse(receipt['committedAt'] as String);
        if (intendedDay) request['expectedPlantDay'] = receipt['sessionId'];
        final uid = record['actorUid'] as String;
        final id = request['requestId'] as String;
        final dayStore = DurableSubmissionRepository(
          database,
          now: () => acceptedAt,
        );
        final saved = await dayStore.prepare(
          DurableSubmissionDraft(
            submissionId: id,
            actorUid: uid,
            requestId: id,
            aggregateId: id,
            resourceKey: 'morningReview:$uid',
            protocol: 'assetHierarchy.v2',
            envelopeJson: jsonEncode({
              'protocolVersion': 2,
              'originActorUid': uid,
              'request': request,
            }),
          ),
        );
        final claim = await dayStore.claim(submissionId: id, actorUid: uid);
        await dayStore.recordOutcome(
          claim,
          state: DurableSubmissionState.uncertain,
          errorCode: 'reply-lost',
          message: 'Acceptance reply lost',
        );
        await database.close();
        await open();
        final nextDay = MorningReviewCommandService(
          actorScope: uid,
          durableStore: store,
          requireActor: () => user(uid),
          requireCapability: (_) async {},
          now: () => acceptedAt.add(const Duration(days: 1)),
          callableInvoker: (envelope) async {
            expect(envelope, {
              'protocolVersion': 2,
              'originActorUid': uid,
              'receiptLookup': request,
            });
            reads++;
            return {...receipt, 'idempotentReplay': true};
          },
          readSubject: (collection, entityId) async =>
              Map<String, dynamic>.from(record['subject'] as Map),
        );
        expect((await nextDay.reconcilePending())!.requestId, id);
        final recovered = (await store.read(id))!;
        expect(recovered.state, DurableSubmissionState.reconciled);
        expect(recovered.envelopeJson, saved.envelopeJson);
        expect(reads, 1);
        expect(mutations, 0);
      },
    );
  }

  test(
    'accepted sessionless receipt crosses India day with readback only',
    () async {
      final record = records.singleWhere(
        (row) => row['request']['operation'] == 'START_MORNING_REVIEW',
      );
      final request = Map<String, dynamic>.from(record['request'] as Map);
      final uid = record['actorUid'] as String;
      final id = request['requestId'] as String;
      final saved = await store.prepare(
        DurableSubmissionDraft(
          submissionId: id,
          actorUid: uid,
          requestId: id,
          aggregateId: id,
          resourceKey: 'morningReview:$uid',
          protocol: 'assetHierarchy.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': uid,
            'request': request,
          }),
        ),
      );
      await store.claim(submissionId: id, actorUid: uid);
      await store.settleAccepted(
        submissionId: id,
        envelopeSha256: saved.envelopeSha256,
        receiptJson: jsonEncode(record['receipt']),
        validateReceipt: (_, __) => true,
      );
      var calls = 0;
      final later = MorningReviewCommandService(
        actorScope: uid,
        durableStore: store,
        requireActor: () => user(uid),
        requireCapability: (_) async {
          calls++;
        },
        callableInvoker: (_) async {
          calls++;
          return null;
        },
        now: () => saved.createdAt.add(const Duration(days: 2)),
        readSubject: (_, __) async =>
            Map<String, dynamic>.from(record['subject'] as Map),
      );
      expect((await later.reconcilePending())!.sessionId, '2026-08-31');
      expect(calls, 0);
      expect((await store.read(id))!.state, DurableSubmissionState.reconciled);
    },
  );

  for (final record in records) {
    for (final afterAdvance in [
      false,
      if (record['request']['operation'] != 'RECORD_MORNING_REVIEW_NOT_HELD')
        true,
    ]) {
      test(
        'actual handler ${record['request']['operation']} native receipt/readback ${afterAdvance ? 'after legitimate advancement' : 'at acceptance'}',
        () async {
          final request = Map<String, dynamic>.from(record['request'] as Map);
          final uid = record['actorUid'] as String;
          final id = request['requestId'] as String;
          final envelope = {
            'protocolVersion': 2,
            'originActorUid': uid,
            'request': request,
          };
          final saved = await store.prepare(
            DurableSubmissionDraft(
              submissionId: id,
              actorUid: uid,
              requestId: id,
              aggregateId: (request['sessionId'] ?? id) as String,
              resourceKey: 'morningReview:$uid',
              protocol: 'assetHierarchy.v2',
              envelopeJson: jsonEncode(envelope),
            ),
          );
          final unpinnedSessionless = request['sessionId'] == null;
          if (unpinnedSessionless) {
            // These producer fixtures predate expectedPlantDay. Preserve their
            // original fingerprint and model a lost reply from that attempt.
            final firstClaim = await store.claim(
              submissionId: id,
              actorUid: uid,
            );
            await store.recordOutcome(
              firstClaim,
              state: DurableSubmissionState.uncertain,
              errorCode: 'reply-lost',
              message: 'The original acceptance reply was lost.',
            );
          }
          var dispatches = 0;
          final subjectData = afterAdvance
              ? advanced.singleWhere(
                  (value) => value['operation'] == request['operation'],
                )['subject']
              : record['subject'];
          final captured = MorningReviewCommandService(
            actorScope: uid,
            durableStore: store,
            requireActor: () => user(uid),
            requireCapability: (_) async {},
            callableInvoker: (received) async {
              dispatches++;
              expect(
                received,
                unpinnedSessionless
                    ? {
                        'protocolVersion': 2,
                        'originActorUid': uid,
                        'receiptLookup': request,
                      }
                    : envelope,
              );
              return record['receipt'];
            },
            readSubject: (collection, entityId) async {
              expect(collection, record['collection']);
              expect(entityId, record['receipt']['entityId']);
              return Map<String, dynamic>.from(subjectData as Map);
            },
          );
          final result = await captured.reconcilePending();
          expect(result!.requestId, id);
          expect(dispatches, 1);
          final reconciled = (await store.read(saved.submissionId))!;
          expect(reconciled.state, DurableSubmissionState.reconciled);
          expect(jsonDecode(reconciled.receiptJson!), record['receipt']);
        },
      );
    }
  }

  for (final operation in const [
    'START_MORNING_REVIEW',
    'RECORD_MORNING_REVIEW_NOT_HELD',
  ]) {
    test(
      'unpinned $operation recovery paused across India midnight only looks up its original receipt',
      () async {
        final record = records.singleWhere(
          (row) => row['request']['operation'] == operation,
        );
        final request = Map<String, dynamic>.from(record['request'] as Map);
        final receipt = Map<String, dynamic>.from(record['receipt'] as Map);
        final uid = record['actorUid'] as String;
        final id = request['requestId'] as String;
        var clock = DateTime.utc(2026, 8, 31, 18, 29, 59);
        final originalStore = DurableSubmissionRepository(
          database,
          now: () => clock,
        );
        final saved = await originalStore.prepare(
          DurableSubmissionDraft(
            submissionId: id,
            actorUid: uid,
            requestId: id,
            aggregateId: id,
            resourceKey: 'morningReview:$uid',
            protocol: 'assetHierarchy.v2',
            envelopeJson: jsonEncode({
              'protocolVersion': 2,
              'originActorUid': uid,
              'request': request,
            }),
          ),
        );
        final firstClaim = await originalStore.claim(
          submissionId: id,
          actorUid: uid,
        );
        await originalStore.recordOutcome(
          firstClaim,
          state: DurableSubmissionState.uncertain,
          errorCode: 'reply-lost',
          message: 'Original acceptance reply was lost.',
        );
        await reopen();
        final reopenedStore = DurableSubmissionRepository(
          database,
          now: () => clock,
        );
        final enteredProbe = Completer<void>();
        final releaseProbe = Completer<void>();
        final calls = <Map<String, dynamic>>[];
        var subjectReads = 0;
        final recovery = MorningReviewCommandService(
          actorScope: uid,
          durableStore: reopenedStore,
          requireActor: () => user(uid),
          now: () => clock,
          requireCapability: (_) async {
            expect(currentIndiaPlantDay(clock), '2026-08-31');
            enteredProbe.complete();
            await releaseProbe.future;
          },
          callableInvoker: (envelope) async {
            expect(currentIndiaPlantDay(clock), '2026-09-01');
            calls.add(Map<String, dynamic>.from(envelope));
            expect(envelope, {
              'protocolVersion': 2,
              'originActorUid': uid,
              'receiptLookup': request,
            });
            return {...receipt, 'idempotentReplay': true};
          },
          readSubject: (collection, entityId) async {
            subjectReads++;
            expect(collection, record['collection']);
            expect(entityId, receipt['entityId']);
            return Map<String, dynamic>.from(record['subject'] as Map);
          },
        );
        final pending = recovery.reconcilePending();
        await enteredProbe.future;
        expect(calls, isEmpty);
        clock = DateTime.utc(2026, 8, 31, 18, 30, 1);
        releaseProbe.complete();
        final result = await pending;
        expect(result!.requestId, id);
        expect(result.sessionId, '2026-08-31');
        expect(calls, hasLength(1));
        expect(subjectReads, 1);
        final restored = (await reopenedStore.read(id))!;
        expect(restored.state, DurableSubmissionState.reconciled);
        expect(restored.envelopeJson, saved.envelopeJson);
        expect(restored.requestId, saved.requestId);
        expect(jsonDecode(restored.receiptJson!), receipt);
      },
    );

    test(
      'unpinned never-attempted $operation remains unsent on its original day and can be explicitly cancelled',
      () async {
        final record = records.singleWhere(
          (row) => row['request']['operation'] == operation,
        );
        final request = Map<String, dynamic>.from(record['request'] as Map);
        final uid = record['actorUid'] as String;
        final id = request['requestId'] as String;
        final clock = DateTime.utc(2026, 8, 31, 3);
        final dayStore = DurableSubmissionRepository(
          database,
          now: () => clock,
        );
        final saved = await dayStore.prepare(
          DurableSubmissionDraft(
            submissionId: id,
            actorUid: uid,
            requestId: id,
            aggregateId: id,
            resourceKey: 'morningReview:$uid',
            protocol: 'assetHierarchy.v2',
            envelopeJson: jsonEncode({
              'protocolVersion': 2,
              'originActorUid': uid,
              'request': request,
            }),
          ),
        );
        var capabilityCalls = 0;
        var invokeCalls = 0;
        final recovery = MorningReviewCommandService(
          actorScope: uid,
          durableStore: dayStore,
          requireActor: () => user(uid),
          now: () => clock,
          requireCapability: (_) async {
            capabilityCalls++;
          },
          callableInvoker: (_) async {
            invokeCalls++;
            throw StateError('Unpinned unsent requests must not dispatch.');
          },
        );
        await expectLater(
          recovery.reconcilePending(),
          throwsA(isA<MorningReviewCommandException>()),
        );
        expect(capabilityCalls, 0);
        expect(invokeCalls, 0);
        final retained = (await dayStore.read(id))!;
        expect(retained.state, DurableSubmissionState.intent);
        expect(retained.attemptCount, 0);
        expect(retained.envelopeJson, saved.envelopeJson);
        await recovery.cancelNeverSent();
        final cancelled = (await dayStore.read(id))!;
        expect(cancelled.state, DurableSubmissionState.cancelledBeforeSend);
        expect(cancelled.envelopeJson, saved.envelopeJson);
      },
    );
  }
}
