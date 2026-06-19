import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_idempotency_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'reuses request identity for unchanged payload after store recreation',
    () async {
      final firstStore = PublishedTemplateAssignmentIdempotencyStore();
      final first = await firstStore.resolve(
        actorUid: 'actor-1',
        payloadFingerprint: 'fingerprint-1',
      );

      final secondStore = PublishedTemplateAssignmentIdempotencyStore();
      final second = await secondStore.resolve(
        actorUid: 'actor-1',
        payloadFingerprint: 'fingerprint-1',
      );

      expect(second.requestId, first.requestId);
      expect(second.payloadFingerprint, first.payloadFingerprint);
    },
  );

  test('changed assignment meaning receives a new request identity', () async {
    final store = PublishedTemplateAssignmentIdempotencyStore();
    final first = await store.resolve(
      actorUid: 'actor-1',
      payloadFingerprint: 'fingerprint-1',
    );
    final second = await store.resolve(
      actorUid: 'actor-1',
      payloadFingerprint: 'fingerprint-2',
    );

    expect(second.requestId, isNot(first.requestId));
  });

  test('successful request clears only the matching identity', () async {
    final store = PublishedTemplateAssignmentIdempotencyStore();
    final pending = await store.resolve(
      actorUid: 'actor-1',
      payloadFingerprint: 'fingerprint-1',
    );

    await store.clearIfMatches(
      actorUid: 'actor-1',
      requestId: 'different-request',
    );
    expect(await store.read(actorUid: 'actor-1'), isNotNull);

    await store.clearIfMatches(
      actorUid: 'actor-1',
      requestId: pending.requestId,
    );
    expect(await store.read(actorUid: 'actor-1'), isNull);
  });
}
