import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/operational_events/repositories/operational_event_amendment_repository.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_amendment_service.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';
import '../tool/test_support/operational_event_amendment_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late OperationalEventAmendmentService service;
  late String actor;
  late DateTime clock;
  late List<String> envelopes;
  late Map<String, Map<String, dynamic>> evidence;
  late bool readbackAvailable;
  late int readbacks;
  Object? dispatchError;
  Future<void> Function()? beforeReply;
  void Function(Map<String, dynamic>)? mutateReceipt;
  final review = amendmentReview();

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      name: 'operational_amendment',
      directory: directory.path,
      inspector: false,
    );
    store = DurableSubmissionRepository(database, now: () => clock);
    service = OperationalEventAmendmentService(
      store: store,
      requireActor: () => amendmentActor(actor),
      requireCapability: (_) async {},
      invoke: (envelope) async {
        envelopes.add(envelope);
        final request =
            (jsonDecode(envelope) as Map<String, dynamic>)['request']
                as Map<String, dynamic>;
        final saved = (await store.read(request['requestId'] as String))!;
        expect(saved.envelopeJson, envelope);
        expect(saved.state, DurableSubmissionState.sending);
        if (dispatchError != null) throw dispatchError!;
        evidence[request['requestId'] as String] = amendmentEvidence(
          request,
          review.originalIntervalJson,
        );
        await beforeReply?.call();
        final result = amendmentReceipt(request, review.originalIntervalJson);
        mutateReceipt?.call(result);
        return result;
      },
      confirmReadback: (saved, receipt) async {
        readbacks++;
        if (!readbackAvailable) throw StateError('Readback offline');
        OperationalEventAmendmentRepository.verifyReadback(
          evidence[saved.requestId]!,
          saved,
          receipt,
        );
      },
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('operational_amendment_');
    actor = 'admin-a';
    clock = DateTime.utc(2025, 8, 14, 17);
    envelopes = [];
    evidence = {};
    readbackAvailable = true;
    readbacks = 0;
    dispatchError = null;
    beforeReply = null;
    mutateReceipt = null;
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });
  Future<OperationalEventAmendmentReceipt> submit() => service.submit(
    review: review,
    correctedResolvedAt: amendmentTime(11),
    reason: 'Verified actual restoration.',
  );
  Future<DurableSubmission> pending() async =>
      (await service.pending(amendmentEventId, 0))!;
  const refused = OperationalEventCommandException(
    'Review changed',
    code: 'failed-precondition',
    details: {'reasonCode': 'operational-interval-amendment-stale'},
  );

  test(
    'native ownership precedes dispatch and exact retained evidence completes reconciliation',
    () async {
      final result = await submit();
      expect(
        (await store.read(result.amendmentId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(readbacks, 1);
      final envelope = jsonDecode(envelopes.single) as Map;
      expect(envelope['originActorUid'], 'admin-a');
      expect(envelope['request']['intervalAmendment']['occurrenceIndex'], 0);
    },
  );

  test(
    'accepted reply lost after commit resumes exact envelope after native restart',
    () async {
      beforeReply = () async => throw StateError('Reply lost');
      await expectLater(submit(), throwsStateError);
      final saved = await pending();
      expect(evidence[saved.requestId], isNotNull);
      await database.close();
      await open();
      beforeReply = null;
      await service.resume(saved.submissionId);
      expect(envelopes, [saved.envelopeJson, saved.envelopeJson]);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test('unresolved request blocks fresh identity for its ordinal', () async {
    dispatchError = StateError('Offline');
    await expectLater(submit(), throwsStateError);
    final saved = await pending();
    await expectLater(submit(), throwsA(anything));
    expect(envelopes, hasLength(1));
    expect((await pending()).requestId, saved.requestId);
  });

  test('wrong account cannot read or resume the saved amendment', () async {
    dispatchError = StateError('Offline');
    await expectLater(submit(), throwsStateError);
    final saved = await pending();
    actor = 'admin-b';
    await expectLater(
      service.pending(amendmentEventId, 0),
      throwsA(isA<OperationalEventCommandException>()),
    );
    await expectLater(
      service.resume(saved.submissionId),
      throwsA(isA<OperationalEventCommandException>()),
    );
    expect(envelopes, hasLength(1));
  });

  test(
    'late response after account switch retains acceptance for original actor',
    () async {
      beforeReply = () async {
        actor = 'admin-b';
      };
      await expectLater(
        submit(),
        throwsA(isA<OperationalEventCommandException>()),
      );
      final id =
          (jsonDecode(envelopes.single) as Map)['request']['requestId']
              as String;
      expect((await store.read(id))!.state.isAccepted, isTrue);
      expect(readbacks, 0);
      actor = 'admin-a';
      await service.resume(id);
      expect(envelopes, hasLength(1));
      expect(readbacks, 1);
    },
  );

  test(
    'accepted readback outage retries evidence without dispatching again',
    () async {
      readbackAvailable = false;
      await expectLater(submit(), throwsStateError);
      final saved = await pending();
      expect(saved.state.isAccepted, isTrue);
      await database.close();
      await open();
      readbackAvailable = true;
      await service.resume(saved.submissionId);
      expect(envelopes, hasLength(1));
    },
  );

  test(
    'first explicit refusal releases request but later refusal cannot fence earlier attempt',
    () async {
      dispatchError = refused;
      await expectLater(
        submit(),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pending(amendmentEventId, 0), isNull);
      dispatchError = StateError('Offline');
      await expectLater(submit(), throwsStateError);
      final saved = await pending();
      dispatchError = refused;
      await expectLater(
        service.resume(saved.submissionId),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect((await pending()).state, DurableSubmissionState.uncertain);
    },
  );

  test(
    'expired first dispatch can settle late acceptance after a retry refusal',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      beforeReply = () async {
        started.complete();
        await release.future;
      };
      final first = submit();
      await started.future;
      final saved = await pending();
      clock = clock.add(const Duration(hours: 1));
      dispatchError = refused;
      await expectLater(
        service.resume(saved.submissionId),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect((await pending()).state, DurableSubmissionState.uncertain);
      release.complete();
      await first;
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test('receipt with wrong ordinal never becomes accepted', () async {
    mutateReceipt = (raw) => raw['occurrenceIndex'] = 1;
    await expectLater(
      submit(),
      throwsA(isA<OperationalEventCommandException>()),
    );
    expect((await pending()).receiptJson, isNull);
    expect(readbacks, 0);
  });

  test(
    'readback rejects digest, actor, original interval, timestamps and unknown fields',
    () async {
      readbackAvailable = false;
      await expectLater(submit(), throwsStateError);
      final saved = await pending();
      final receipt = OperationalEventAmendmentReceipt.fromMap(
        durableSubmissionJsonObject(saved.receiptJson!),
        OperationalEventAmendmentService.requestFor(saved),
      );
      final original = evidence[saved.requestId]!;
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (raw) => raw['reason'] = 'Other',
        (raw) => raw['amendedByUid'] = 'admin-b',
        (raw) => raw['occurrenceIndex'] = 1,
        (raw) => raw['unexpected'] = true,
        (raw) => raw['originalIntervalJson'] = '{}',
        (raw) => raw['amendedAt'] = Timestamp(
          amendmentTime(16).millisecondsSinceEpoch ~/ 1000,
          1,
        ),
        (raw) => raw['priorEffectiveResolvedAt'] = amendmentTime(13),
        (raw) => raw['evidenceDigest'] = 'tampered',
      ]) {
        final damaged = Map<String, dynamic>.from(original);
        mutation(damaged);
        expect(
          () => OperationalEventAmendmentRepository.verifyReadback(
            damaged,
            saved,
            receipt,
          ),
          throwsA(anything),
        );
      }
      final native = Map<String, dynamic>.from(original);
      for (final field in [
        'amendedAt',
        'priorEffectiveResolvedAt',
        'correctedResolvedAt',
      ]) {
        native[field] = Timestamp.fromDate(
          DateTime.parse(native[field] as String),
        );
      }
      OperationalEventAmendmentRepository.verifyReadback(
        native,
        saved,
        receipt,
      );
    },
  );

  test('unavailable native store prevents network dispatch', () async {
    await database.close(deleteFromDisk: true);
    await expectLater(submit(), throwsA(anything));
    expect(envelopes, isEmpty);
  });
}
