import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_submission_controller.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_service.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_idempotency_store.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late DurableSubmissionRepository store;
  late BurnerConditionSubmissionController controller;
  late AppUser actor;
  late Map<String, Uint8List> legacy;
  late List<Map<String, dynamic>> sent;
  late Map<String, Map<String, dynamic>> receipts;
  late DateTime now;
  var serial = 0;
  var probeCount = 0;
  bool lose = false;
  bool malformed = false;
  Future<void> Function()? probe;
  Future<void> Function()? responseHook;

  AppUser user(String uid) => AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.com',
    roles: const [AppRole.operations],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );

  Map<String, dynamic> command({bool compliance = false}) => compliance
      ? {
          'operation': 'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
          'assetClassId': 'furnace-class',
          'assetInstanceId': 'furnace-a',
          'expectedAssetVersion': 4,
          'expectedCurrentRoundId': 'original-round',
          'directiveId': 'burner_round_red_hot_source',
          'expectedDirectiveVersion': 3,
          'dispositions': [
            {'position': 1, 'disposition': 'restoredInService'},
          ],
          'closureRemarks': 'Original inspection result',
        }
      : {
          'operation': 'RECORD_BURNER_CONDITION_ROUND',
          'assetClassId': 'furnace-class',
          'assetInstanceId': 'furnace-a',
          'expectedAssetVersion': 4,
          'observations': [
            for (var n = 1; n <= 8; n++)
              {
                'position': n,
                'flameObservation': 'seen',
                'redHotObserved': false,
                'microampReading': n == 1 ? 3.7 : null,
                'remarks': n == 1 ? 'Original entry' : null,
              },
          ],
          'roundNote': 'Original round note',
        };

  Future<void> open() async {
    db = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'burner_submission',
      inspector: false,
    );
    store = DurableSubmissionRepository(db, now: () => now);
    controller = BurnerConditionSubmissionController(
      store: store,
      requireActor: () => actor,
      requireCapability: (_) async {
        probeCount++;
        await probe?.call();
      },
      readLegacy: (_) async => legacy,
      newRequestId: () =>
          '00000000-0000-4000-8000-${(++serial).toString().padLeft(12, '0')}',
      invoke: (envelope) async {
        sent.add(jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>);
        final request = envelope['request'] as Map;
        final id = request['requestId'] as String;
        final receipt = receipts.putIfAbsent(
          id,
          () => {
            'ok': true,
            'requestId': id,
            'operation': request['operation'],
            'roundId': id,
            'assetClassId': request['assetClassId'],
            'assetInstanceId': request['assetInstanceId'],
            'committedAt': '2026-09-12T09:00:00.000Z',
            'idempotentReplay': false,
            if (request['operation'] == 'RECORD_BURNER_CONDITION_ROUND')
              'directiveId': null
            else ...{
              'closedDirectiveId': request['directiveId'],
              'closedDirectiveVersion': 4,
              'newDirectiveId': null,
            },
          },
        );
        await responseHook?.call();
        if (lose) {
          lose = false;
          throw StateError('response lost after server commit');
        }
        if (malformed) {
          return {...receipt, 'assetInstanceId': 'another-furnace'};
        }
        return Map<String, dynamic>.from(receipt);
      },
    );
  }

  Future<void> reopen() async {
    await db.close();
    await open();
  }

  Future<Map<String, dynamic>> submit({bool compliance = false}) =>
      controller.submit(
        requestWithoutId: command(compliance: compliance),
        actorUid: actor.uid,
        furnaceName: 'Furnace A',
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('burner_submission_');
    actor = user('operations-a');
    legacy = {};
    sent = [];
    receipts = {};
    now = DateTime.utc(2026, 9, 12, 9);
    serial = 0;
    probeCount = 0;
    lose = false;
    malformed = false;
    probe = null;
    responseHook = null;
    await open();
  });
  tearDown(() async {
    if (db.isOpen) await db.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });

  test(
    'lost response restores full original round after native reopen without creating a second action',
    () async {
      lose = true;
      await expectLater(
        submit(),
        throwsA(isA<BurnerConditionRoundException>()),
      );
      final pending = (await controller.pending()).single;
      final bytes = pending.envelopeJson;
      expect(pending.state, DurableSubmissionState.uncertain);
      await reopen();
      final restored = (await controller.pending()).single;
      expect(restored.envelopeJson, bytes);
      expect(
        controller.requestOf(restored)['roundNote'],
        'Original round note',
      );
      await controller.check(restored.submissionId);
      expect(sent, hasLength(2));
      expect(sent.first, sent.last);
      expect(receipts, hasLength(1));
      expect(
        (await store.read(restored.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'changed entries cannot silently replace an unresolved furnace request',
    () async {
      lose = true;
      await expectLater(
        submit(),
        throwsA(isA<BurnerConditionRoundException>()),
      );
      await expectLater(
        controller.submit(
          requestWithoutId: {...command(), 'roundNote': 'Edited next draft'},
          actorUid: actor.uid,
          furnaceName: 'Furnace A',
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(sent, hasLength(1));
      expect(
        (await controller.pending()).single.envelopeJson,
        contains('Original round note'),
      );
    },
  );

  test(
    'identical later intentional rounds get distinct IDs after prior reconciliation',
    () async {
      await submit();
      await submit();
      expect(receipts, hasLength(2));
      expect(
        sent[0]['request']['requestId'],
        isNot(sent[1]['request']['requestId']),
      );
    },
  );

  test('failed capability leaves native intent unsent and unclaimed', () async {
    probe = () async => throw StateError('old backend');
    await expectLater(submit(), throwsStateError);
    final row = (await controller.pending()).single;
    expect(row.state, DurableSubmissionState.intent);
    expect(row.attemptCount, 0);
    expect(sent, isEmpty);
  });

  test(
    'account switch during probe cannot send or rebind the original envelope',
    () async {
      probe = () async => actor = user('operations-b');
      await expectLater(
        submit(),
        throwsA(isA<BurnerConditionRoundException>()),
      );
      final rows = await store.listForActor('operations-a');
      expect(rows.single.state, DurableSubmissionState.intent);
      expect(rows.single.actorUid, 'operations-a');
      expect(sent, isEmpty);
    },
  );

  test(
    'valid late response remains owned by original actor when account switches during send',
    () async {
      responseHook = () async => actor = user('operations-b');
      await expectLater(
        submit(),
        throwsA(isA<BurnerConditionRoundException>()),
      );
      final row = (await store.listForActor('operations-a')).single;
      expect(row.state, DurableSubmissionState.acceptedPendingAdoption);
      actor = user('operations-a');
      probe = () async => throw StateError('must not probe');
      await controller.check(row.submissionId);
      expect(sent, hasLength(1));
    },
  );

  test('malformed receipt cannot settle the durable intent', () async {
    malformed = true;
    await expectLater(submit(), throwsA(isA<BurnerConditionRoundException>()));
    final row = (await controller.pending()).single;
    expect(row.state, DurableSubmissionState.uncertain);
    expect(row.receiptJson, isNull);
  });

  test(
    'compliance keeps exact original versions and receipt through restart until device adoption',
    () async {
      await submit(compliance: true);
      final row = (await controller.pending()).single;
      expect(row.state, DurableSubmissionState.acceptedPendingAdoption);
      await reopen();
      probe = () async => throw StateError('receipt-known path must not probe');
      final result = await controller.check(row.submissionId);
      expect(result['closedDirectiveVersion'], 4);
      expect(sent, hasLength(1));
      expect(
        controller.requestOf(
          (await controller.pending()).single,
        )['expectedCurrentRoundId'],
        'original-round',
      );
      await controller.finalizeDirective(row.submissionId, actor.uid);
      expect(
        (await store.read(row.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test('simultaneous checks acquire one native dispatch claim', () async {
    probe = () async => throw StateError('hold before first dispatch');
    await expectLater(submit(), throwsStateError);
    final row = (await controller.pending()).single;
    probe = null;
    final barrier = Completer<void>();
    responseHook = () => barrier.future;
    final first = controller.check(row.submissionId);
    while (sent.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(
      controller.check(row.submissionId),
      throwsA(isA<BurnerConditionRoundException>()),
    );
    barrier.complete();
    await first;
    expect(sent, hasLength(1));
  });

  test(
    'real legacy preference bytes including malformed text are retained without invented origin or dispatch',
    () async {
      const key = 'PENDING_BURNER_CONDITION_ROUND::operations-a';
      const raw = ' { malformed old retry bytes \n';
      SharedPreferences.setMockInitialValues({key: raw});
      final preferences = await SharedPreferences.getInstance();
      final reader = BurnerConditionRoundIdempotencyStore(
        preferencesLoader: () async => preferences,
      );
      legacy = await reader.readRawEvidence(actor.uid);
      final row = (await controller.pending()).single;
      expect(row.state, DurableSubmissionState.needsReview);
      expect(row.actorUid, isNull);
      expect(utf8.decode(base64Decode(row.legacySourceBase64!)), raw);
      expect(preferences.getString(key), raw);
      await expectLater(
        submit(),
        throwsA(isA<BurnerConditionRoundException>()),
      );
      expect(sent, isEmpty);
      expect(probeCount, 0);
    },
  );
}
