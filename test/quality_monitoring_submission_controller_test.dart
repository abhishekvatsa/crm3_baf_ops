import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/services/quality_command_service.dart';
import 'package:crm3_baf_ops/features/quality/services/quality_monitoring_submission_controller.dart';
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
  late QualityMonitoringSubmissionController controller;
  late _MonitoringServer server;
  late AppUser actor;
  var probes = 0;
  Future<void> Function(String)? probe;
  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'quality_monitoring_submission',
      inspector: false,
    );
    store = DurableSubmissionRepository(database);
    controller = QualityMonitoringSubmissionController(
      store: store,
      projectId: 'project',
      requireActor: () => actor,
      requireCapability: (uid) async {
        probes++;
        await probe?.call(uid);
      },
      invoke: server.invoke,
      readFromServer: server.read,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'quality_monitoring_submission_',
    );
    server = _MonitoringServer();
    actor = _manager('si-1');
    probes = 0;
    probe = null;
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });
  Future<void> reopen() async {
    await database.close();
    await open();
  }

  Future<DurableSubmission> saved() async =>
      (await store.listForActor('si-1', includeTerminal: true)).single;

  test(
    'lost response plus database restart preserves exact envelope and both IDs; one business creation',
    () async {
      server.loseResponse = true;
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      final original = await saved();
      expect(original.state, DurableSubmissionState.uncertain);
      expect(server.mutations, 1);
      await reopen();
      expect(
        (await controller.pending())!['monitoringRequestId'],
        original.aggregateId,
      );
      await controller.retry();
      expect(server.requests.length, 2);
      expect(server.requests.last, server.requests.first);
      expect(server.mutations, 1);
      expect((await saved()).envelopeJson, original.envelopeJson);
      expect((await saved()).state, DurableSubmissionState.reconciled);
      await controller.create(_payload);
      expect(server.mutations, 2);
      expect(
        (server.requests.last['request'] as Map)['requestId'],
        isNot(original.requestId),
      );
      expect(
        (server.requests.last['request'] as Map)['monitoringRequestId'],
        isNot(original.aggregateId),
      );
    },
  );

  test(
    'lost creation response can be recovered after a later valid closure',
    () async {
      server.loseResponse = true;
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      final original = await saved();
      server.closeAfterCreation = true;
      await reopen();
      final result = await controller.retry();
      expect(result.version, 1);
      expect(result.requestId, original.requestId);
      expect(server.requests.last, server.requests.first);
      expect(server.mutations, 1);
      expect((await saved()).state, DurableSubmissionState.reconciled);
    },
  );

  test(
    'accepted receipt is durable before readback; restart checks a later valid state without send or probe',
    () async {
      server.failRead = true;
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      expect(
        (await saved()).state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect((await saved()).receiptJson, isNotNull);
      await reopen();
      probes = 0;
      probe = (_) async => throw StateError('old backend');
      server.closeAfterCreation = true;
      await controller.retry();
      expect(server.requests.length, 1);
      expect(probes, 0);
      expect((await saved()).state, DurableSubmissionState.reconciled);
    },
  );

  test(
    'origin changes during capability check: zero sends and original unsent intent retained',
    () async {
      probe = (_) async => actor = _manager('si-2');
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      expect(server.requests, isEmpty);
      final retained = (await store.listForActor('si-1')).single;
      expect(retained.state, DurableSubmissionState.intent);
      expect(retained.attemptCount, 0);
      await expectLater(
        controller.check(retained.submissionId),
        throwsA(isA<QualityCommandException>()),
      );
      actor = _manager('si-1');
      probe = null;
      await controller.retry();
      expect(server.mutations, 1);
    },
  );

  test(
    'origin changes after acceptance: receipt survives, original account later reads without another send',
    () async {
      server.afterAccept = () => actor = _manager('si-2');
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      final retained = await saved();
      expect(retained.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(retained.receiptJson, isNotNull);
      await reopen();
      await expectLater(
        controller.check(retained.submissionId),
        throwsA(isA<QualityCommandException>()),
      );
      actor = _manager('si-1');
      await controller.retry();
      expect(server.requests.length, 1);
    },
  );

  test(
    'changed entries cannot mint a replacement while acceptance is uncertain',
    () async {
      server.loseResponse = true;
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      await expectLater(
        controller.create({..._payload, 'reason': 'Different reason'}),
        throwsA(isA<QualityCommandException>()),
      );
      expect(server.requests.length, 1);
      expect((await store.listForActor('si-1')).length, 1);
      expect((await controller.pending())!['reason'], _payload['reason']);
    },
  );

  test(
    'wrong receipt business identity never settles even with matching command IDs',
    () async {
      server.wrongReceipt = true;
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      expect((await saved()).receiptJson, isNull);
      expect((await saved()).state, DurableSubmissionState.uncertain);
      expect(server.reads, 0);
    },
  );

  test(
    'contradictory server read keeps validated receipt for review and never resends creation',
    () async {
      server.wrongRead = true;
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      expect(
        (await saved()).state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await reopen();
      await expectLater(
        controller.retry(),
        throwsA(isA<QualityCommandException>()),
      );
      expect(server.requests.length, 1);
    },
  );

  test('simultaneous explicit checks have one active dispatcher', () async {
    probe = (_) async => throw StateError('capability unavailable');
    await expectLater(controller.create(_payload), throwsStateError);
    probe = null;
    final entered = Completer<void>();
    final release = Completer<void>();
    server.beforeSend = () async {
      entered.complete();
      await release.future;
    };
    final first = controller.retry();
    await entered.future;
    await expectLater(
      controller.retry(),
      throwsA(isA<QualityCommandException>()),
    );
    release.complete();
    await first;
    expect(server.requests.length, 1);
    expect(server.mutations, 1);
  });

  test('only a never-sent intent can be cancelled', () async {
    probe = (_) async => throw StateError('capability unavailable');
    await expectLater(controller.create(_payload), throwsStateError);
    await controller.cancelNeverSent();
    expect((await saved()).state, DurableSubmissionState.cancelledBeforeSend);
    expect(server.requests, isEmpty);
    probe = null;
    server.loseResponse = true;
    await expectLater(
      controller.create(_payload),
      throwsA(isA<QualityCommandException>()),
    );
    await expectLater(
      controller.cancelNeverSent(),
      throwsA(isA<DurableSubmissionException>()),
    );
    expect(server.requests.length, 1);
  });

  test(
    'invalid form and unavailable native persistence both prevent dispatch',
    () async {
      await expectLater(
        controller.create({..._payload, 'grade': ''}),
        throwsFormatException,
      );
      expect(await store.listForActor('si-1'), isEmpty);
      await database.close();
      await expectLater(controller.create(_payload), throwsA(anything));
      expect(server.requests, isEmpty);
      expect(probes, 0);
    },
  );

  test(
    'malformed legacy evidence is preserved byte for byte and never upgraded into a send',
    () async {
      final key =
          'PENDING_QUALITY_MONITORING::${Uri.encodeComponent('project:si-1')}';
      const raw = '{ damaged old submission \\n ';
      SharedPreferences.setMockInitialValues({key: raw});
      await expectLater(
        controller.create(_payload),
        throwsA(isA<QualityCommandException>()),
      );
      final retained = (await store.findUnresolvedForResource(
        'qualityMonitoringCreation:project:si-1',
      ))!;
      expect(retained.state, DurableSubmissionState.needsReview);
      expect(retained.actorUid, isNull);
      expect(utf8.decode(base64Decode(retained.legacySourceBase64!)), raw);
      expect((await SharedPreferences.getInstance()).getString(key), raw);
      expect(server.requests, isEmpty);
      expect(probes, 0);
      await reopen();
      await expectLater(
        controller.retry(),
        throwsA(isA<QualityCommandException>()),
      );
      expect(
        (await store.read(retained.submissionId))!.legacySourceBase64,
        retained.legacySourceBase64,
      );
    },
  );
}

const _payload = <String, dynamic>{
  'baseNumber': 4,
  'baseAssetClassId': 'base-class',
  'baseAssetInstanceId': 'base-4',
  'baseAssetInstanceVersion': 3,
  'grade': 'CRCA',
  'cycleReference': 'Cycle 4412',
  'chargeNumbers': <int>[12345, 12346],
  'reason': 'Monitor temperature uniformity',
};

AppUser _manager(String uid) => AppUser(
  uid: uid,
  name: 'SI One',
  email: 'si@example.com',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _MonitoringServer {
  final requests = <Map<String, dynamic>>[];
  final committed = <String, Map<String, dynamic>>{};
  var mutations = 0;
  var reads = 0;
  bool loseResponse = false,
      failRead = false,
      wrongReceipt = false,
      wrongRead = false,
      closeAfterCreation = false;
  void Function()? afterAccept;
  Future<void> Function()? beforeSend;

  Future<Map<String, dynamic>> invoke(Map<String, dynamic> envelope) async {
    await beforeSend?.call();
    expect(envelope.keys.toSet(), {
      'protocolVersion',
      'originActorUid',
      'request',
    });
    expect(envelope['protocolVersion'], 2);
    expect(envelope['originActorUid'], 'si-1');
    requests.add(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(envelope)) as Map),
    );
    final request = Map<String, dynamic>.from(envelope['request'] as Map);
    final id = request['requestId'] as String;
    final replay = committed.containsKey(id);
    final result = committed.putIfAbsent(id, () {
      mutations++;
      return {
        'ok': true,
        'requestId': id,
        'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
        'entityId': request['monitoringRequestId'],
        'version': 1,
        'auditId': 'server_quality_$id',
        'committedAt': '2026-09-12T09:00:00.000Z',
        'idempotentReplay': false,
        'entity': {
          'schemaVersion': 3,
          ..._payload,
          'requestId': request['monitoringRequestId'],
          'reason': request['reason'],
          'status': 'active',
          'visibilityState': 'active',
          'visibleUntil': null,
          'archivedAt': null,
          'createdAt': '2026-09-12T09:00:00.000Z',
          'createdByUid': 'si-1',
          'createdByName': 'SI One',
          'updatedAt': '2026-09-12T09:00:00.000Z',
          'updatedByUid': 'si-1',
          'updatedByName': 'SI One',
          'version': 1,
          'lastMutationId': id,
        },
      };
    });
    afterAccept?.call();
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Response lost');
    }
    return {
      ...result,
      'idempotentReplay': replay,
      if (wrongReceipt)
        'entity': {
          ...result['entity'] as Map,
          'baseAssetInstanceId': 'different-base',
        },
    };
  }

  Future<Map<String, dynamic>> read(String id) async {
    reads++;
    if (failRead) {
      failRead = false;
      throw StateError('Server unavailable');
    }
    final result = committed.values.singleWhere(
      (value) => value['entityId'] == id,
    );
    return {
      ...result['entity'] as Map<String, dynamic>,
      if (wrongRead) 'createdByUid': 'other-si',
      if (closeAfterCreation) ...{
        'version': 2,
        'status': 'closed',
        'visibilityState': 'recent',
        'visibleUntil': '2026-09-20T09:00:00.000Z',
        'closedAt': '2026-09-13T09:00:00.000Z',
        'closedByUid': 'other-si',
        'closedByName': 'Other SI',
        'closeReason': 'Cycle complete',
        'updatedAt': '2026-09-13T09:00:00.000Z',
        'updatedByUid': 'other-si',
        'lastMutationId': 'closure',
      },
    };
  }
}
