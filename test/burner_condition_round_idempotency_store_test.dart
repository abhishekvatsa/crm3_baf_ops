import 'dart:convert';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_idempotency_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'unchanged payload reuses its request identity across store instances',
    () async {
      final firstStore = BurnerConditionRoundIdempotencyStore();
      final first = await firstStore.resolve(
        actorUid: 'operations-1',
        payloadFingerprint: 'a' * 64,
      );
      final resumedStore = BurnerConditionRoundIdempotencyStore();
      final resumed = await resumedStore.resolve(
        actorUid: 'operations-1',
        payloadFingerprint: 'a' * 64,
      );

      expect(resumed.requestId, first.requestId);
      expect(resumed.payloadFingerprint, first.payloadFingerprint);
    },
  );

  test(
    'payload change rotates request identity and success clears it',
    () async {
      final store = BurnerConditionRoundIdempotencyStore();
      final first = await store.resolve(
        actorUid: 'operations-1',
        payloadFingerprint: 'a' * 64,
      );
      final changed = await store.resolve(
        actorUid: 'operations-1',
        payloadFingerprint: 'b' * 64,
      );

      expect(changed.requestId, isNot(first.requestId));
      await store.clearIfMatches(
        actorUid: 'operations-1',
        requestId: changed.requestId,
      );
      expect(await store.read(actorUid: 'operations-1'), isNull);
    },
  );

  test('malformed pending identity fails closed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'PENDING_BURNER_CONDITION_ROUND::operations-1': jsonEncode(
        <String, dynamic>{
          'requestId': 'not-a-uuid',
          'payloadFingerprint': 'a' * 64,
        },
      ),
    });
    final store = BurnerConditionRoundIdempotencyStore();

    expect(
      () =>
          store.resolve(actorUid: 'operations-1', payloadFingerprint: 'a' * 64),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
