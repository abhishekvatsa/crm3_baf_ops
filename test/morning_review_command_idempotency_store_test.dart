import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_idempotency_store.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const actorUid = 'operator-1';
  const secondFingerprint =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const operation = 'ADD_MORNING_REVIEW_ENTRY';
  const sessionId = '2026-09-05';
  const firstExtra = <String, dynamic>{
    'entryDraft': <String, dynamic>{'text': 'Current compliance statement'},
  };
  const secondExtra = <String, dynamic>{
    'entryDraft': <String, dynamic>{'text': 'A different statement'},
  };

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'reuses an unresolved request identity across store instances',
    () async {
      final firstStore = MorningReviewCommandIdempotencyStore();
      final first = await firstStore.resolve(
        actorUid: actorUid,
        operation: operation,
        sessionId: sessionId,
        extra: firstExtra,
      );

      final restored = await MorningReviewCommandIdempotencyStore().resolve(
        actorUid: actorUid,
        operation: operation,
        sessionId: sessionId,
        extra: firstExtra,
      );

      expect(restored.requestId, first.requestId);
      expect(restored.operation, operation);
      expect(restored.sessionId, sessionId);
      expect(restored.extra, firstExtra);
    },
  );

  test(
    'does not replace uncertain evidence with a different command',
    () async {
      final store = MorningReviewCommandIdempotencyStore();
      await store.resolve(
        actorUid: actorUid,
        operation: operation,
        sessionId: sessionId,
        extra: firstExtra,
      );

      await expectLater(
        store.resolve(
          actorUid: actorUid,
          operation: operation,
          sessionId: sessionId,
          extra: secondExtra,
        ),
        throwsA(isA<MorningReviewCommandIdempotencyException>()),
      );
      expect((await store.pending(actorUid))!.extra, firstExtra);
    },
  );

  test('clears only the matching confirmed command identity', () async {
    final store = MorningReviewCommandIdempotencyStore();
    final pending = await store.resolve(
      actorUid: actorUid,
      operation: operation,
      sessionId: sessionId,
      extra: firstExtra,
    );

    await store.clearIfMatches(
      actorUid: actorUid,
      requestId: pending.requestId,
      payloadFingerprint: secondFingerprint,
    );
    expect(await store.pending(actorUid), isNotNull);

    await store.clearIfMatches(
      actorUid: actorUid,
      requestId: pending.requestId,
      payloadFingerprint: pending.payloadFingerprint,
    );
    expect(await store.pending(actorUid), isNull);
  });

  test('stores a recoverable payload under a hashed actor key', () async {
    final store = MorningReviewCommandIdempotencyStore();
    final pending = await store.resolve(
      actorUid: actorUid,
      operation: operation,
      sessionId: sessionId,
      extra: firstExtra,
    );

    final preferences = await SharedPreferences.getInstance();
    final serialized = preferences.getKeys().map(preferences.getString).join();
    expect(preferences.getKeys().single, isNot(contains(actorUid)));
    expect(serialized, contains('Current compliance statement'));
    expect(serialized, contains(pending.payloadFingerprint));
  });

  test('replays an exact submitted request after service recreation', () async {
    final store = MorningReviewCommandIdempotencyStore();
    final pending = await store.resolve(
      actorUid: actorUid,
      operation: MorningReviewCommand.start.wireName,
      sessionId: null,
      extra: const <String, dynamic>{},
    );
    final requests = <Map<String, dynamic>>[];
    final recreatedService = MorningReviewCommandService(
      actorScope: actorUid,
      idempotencyStore: MorningReviewCommandIdempotencyStore(),
      callableInvoker: (request) async {
        requests.add(Map<String, dynamic>.from(request));
        return _receipt(request, status: 'open', entityId: '2026-09-05');
      },
    );

    final result = await recreatedService.reconcilePending();

    expect(result?.requestId, pending.requestId);
    expect(requests, hasLength(1));
    expect(requests.single['requestId'], pending.requestId);
    expect(requests.single['operation'], MorningReviewCommand.start.wireName);
    expect(await store.pending(actorUid), isNull);
  });

  test(
    'reconciles an older intent before allowing a different command',
    () async {
      final store = MorningReviewCommandIdempotencyStore();
      final pending = await store.resolve(
        actorUid: actorUid,
        operation: MorningReviewCommand.start.wireName,
        sessionId: null,
        extra: const <String, dynamic>{},
      );
      final requests = <Map<String, dynamic>>[];
      final service = MorningReviewCommandService(
        actorScope: actorUid,
        idempotencyStore: store,
        callableInvoker: (request) async {
          requests.add(Map<String, dynamic>.from(request));
          return _receipt(request, status: 'open', entityId: '2026-09-05');
        },
      );

      await expectLater(
        service.join('2026-09-05'),
        throwsA(
          isA<MorningReviewCommandException>().having(
            (error) => error.code,
            'code',
            'prior-command-reconciled',
          ),
        ),
      );

      expect(requests, hasLength(1));
      expect(requests.single['requestId'], pending.requestId);
      expect(requests.single['operation'], MorningReviewCommand.start.wireName);
      expect(await store.pending(actorUid), isNull);
    },
  );
}

Map<String, dynamic> _receipt(
  Map<String, dynamic> request, {
  required String status,
  required String entityId,
}) => <String, dynamic>{
  'ok': true,
  'requestId': request['requestId'],
  'operation': request['operation'],
  'sessionId': request['sessionId'] ?? '2026-09-05',
  'entityId': entityId,
  'status': status,
  'version': 1,
  'committedAt': '2026-09-05T03:00:00.000Z',
  'idempotentReplay': true,
};
