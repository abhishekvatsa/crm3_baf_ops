import 'dart:async';
import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/test_support/in_memory_durable_submission_store.dart';

DurableSubmissionDraft _draft(String request) => DurableSubmissionDraft(
  submissionId: request,
  actorUid: 'actor-a',
  requestId: request,
  aggregateId: 'item',
  resourceKey: 'shared-item',
  protocol: 'maintenanceWorkflow.v2',
  envelopeJson: jsonEncode({
    'protocolVersion': 2,
    'originActorUid': 'actor-a',
    'command': {
      'commandId': request,
      'commandType': 'upsertAbnormalityType',
      'aggregateId': 'item',
      'expectedVersion': 0,
      'payload': {'projectId': 'demo-test', 'record': {}},
    },
  }),
);

void main() {
  test(
    'projection failure leaves no journal identity or resource reservation',
    () async {
      final store = InMemoryDurableSubmissionStore();
      await expectLater(
        store.prepareAtomically(
          prepareDraft: () async => _draft('failed'),
          persistProjection: () async {
            throw StateError('projection failed');
          },
        ),
        throwsStateError,
      );
      expect(await store.read('failed'), isNull);
      expect(await store.findUnresolvedForResource('shared-item'), isNull);
      expect((await store.prepare(_draft('retry'))).submissionId, 'retry');
    },
  );

  test(
    'projection completes before journal is visible; identical retry does not rerun projection',
    () async {
      final store = InMemoryDurableSubmissionStore();
      var writes = 0;
      final draft = _draft('same');
      Future<void> project() async {
        expect(await store.read('same'), isNull);
        writes++;
      }

      await store.prepareAtomically(
        prepareDraft: () async => draft,
        persistProjection: project,
      );
      await store.prepareAtomically(
        prepareDraft: () async => draft,
        persistProjection: project,
      );
      expect(writes, 1);
      expect((await store.read('same'))!.state, DurableSubmissionState.intent);
    },
  );

  test('concurrent preparations cannot both own the shared resource', () async {
    final store = InMemoryDurableSubmissionStore();
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = store.prepareAtomically(
      prepareDraft: () async => _draft('first'),
      persistProjection: () async {
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    final second = store.prepare(_draft('second'));
    final refused = expectLater(
      second,
      throwsA(isA<DurableSubmissionException>()),
    );
    release.complete();
    await first;
    await refused;
    expect(await store.read('second'), isNull);
    expect(
      (await store.findUnresolvedForResource('shared-item'))!.submissionId,
      'first',
    );
  });
}
