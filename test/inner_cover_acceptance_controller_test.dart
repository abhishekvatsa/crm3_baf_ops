import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_acceptance_input.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/assets/services/inner_cover_acceptance_controller.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late _AcceptanceServer server;
  late AppUser actor;
  late DateTime now;
  late InnerCoverAcceptanceController controller;
  var capabilityCalls = 0;
  Future<void> Function(String)? probe;

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      name: 'acceptance_controller',
      directory: directory.path,
      inspector: false,
    );
    store = DurableSubmissionRepository(database, now: () => now);
    controller = InnerCoverAcceptanceController(
      store: store,
      repository: server,
      requireActor: () => actor,
      requireCapability: (uid) async {
        capabilityCalls++;
        await probe?.call(uid);
      },
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acceptance_controller_');
    now = DateTime.utc(2026, 9, 12, 9);
    server = _AcceptanceServer();
    actor = _admin('admin-a');
    capabilityCalls = 0;
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

  Future<InnerCoverProfile> submit({
    String id = 'acceptance-a',
    InnerCoverAcceptanceInput? input,
  }) => controller.submit(
    cover: server.profile,
    input: input ?? _input,
    requestId: id,
  );

  test(
    'lost response survives database reopen and repeats exactly one accepted command',
    () async {
      server.loseNextResponse = true;
      await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
      final saved = await store.read('acceptance-a');
      expect(saved!.state, DurableSubmissionState.uncertain);
      expect(server.acceptedMutations, 1);
      final frozenBytes = saved.envelopeJson;
      await reopen();
      final recovered = await controller.restore('cover-a');
      expect(recovered!.envelopeJson, frozenBytes);
      final result = await controller.check(recovered.submissionId);
      expect(result.isAvailable, isTrue);
      expect(server.requests.length, 2);
      expect(server.requests.last, server.requests.first);
      expect(server.acceptedMutations, 1);
      final settled = await store.read('acceptance-a');
      expect(settled!.state, DurableSubmissionState.reconciled);
      expect(settled.envelopeJson, frozenBytes);
      expect(settled.receiptJson, isNotNull);
    },
  );

  test(
    'receipt is durable before readback; restart confirms later state without another send or probe',
    () async {
      server.failNextRead = true;
      await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
      expect(
        (await store.read('acceptance-a'))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect(server.requests.length, 1);
      await reopen();
      server.currentVersion = 3;
      capabilityCalls = 0;
      probe = (_) async => throw StateError('backend probe unavailable');
      final result = await controller.check('acceptance-a');
      expect(result.version, 3);
      expect(server.requests.length, 1);
      expect(capabilityCalls, 0);
    },
  );

  test(
    'account switch during capability check leaves the original intent unsent',
    () async {
      probe = (_) async => actor = _admin('admin-b');
      await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
      final saved = await store.read('acceptance-a');
      expect(saved!.actorUid, 'admin-a');
      expect(saved.state, DurableSubmissionState.intent);
      expect(saved.attemptCount, 0);
      expect(server.requests, isEmpty);
      await expectLater(
        controller.restore('cover-a'),
        throwsA(isA<AssetHierarchyException>()),
      );
      actor = _admin('admin-a');
      probe = null;
      await controller.check('acceptance-a');
      expect(server.acceptedMutations, 1);
    },
  );

  test(
    'account switch after server acceptance cannot discard the receipt',
    () async {
      server.afterAccepted = () => actor = _admin('admin-b');
      await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
      final saved = await store.read('acceptance-a');
      expect(saved!.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(saved.receiptJson, isNotNull);
      await reopen();
      await expectLater(
        controller.check('acceptance-a'),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(server.requests.length, 1);
      actor = _admin('admin-a');
      await controller.check('acceptance-a');
      expect(server.requests.length, 1);
    },
  );

  test(
    'another account cannot create a second acceptance while an earlier outcome is uncertain',
    () async {
      server.loseNextResponse = true;
      await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
      actor = _admin('admin-b');
      await expectLater(
        submit(id: 'acceptance-b'),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(await store.read('acceptance-b'), isNull);
      expect(server.requests.length, 1);
    },
  );

  test(
    'account change during local reconciliation withholds the result but preserves acceptance',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final gatedStore = _GatedReconciliationStore(database, entered, release);
      controller = InnerCoverAcceptanceController(
        store: gatedStore,
        repository: server,
        requireActor: () => actor,
        requireCapability: (_) async {},
      );
      final pending = submit();
      final assertion = expectLater(
        pending,
        throwsA(isA<AssetHierarchyException>()),
      );
      await entered.future;
      actor = _admin('admin-b');
      release.complete();
      await assertion;
      expect(
        (await store.read('acceptance-a'))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(server.requests.length, 1);
      await reopen();
      actor = _admin('admin-a');
      await controller.check('acceptance-a');
      expect(server.requests.length, 1);
    },
  );

  test('changed inspection data cannot reuse the saved request ID', () async {
    server.loseNextResponse = true;
    await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
    await expectLater(
      submit(
        input: InnerCoverAcceptanceInput(
          inspectedOn: _input.inspectedOn,
          acceptanceReference: 'Different evidence',
          reason: _input.reason,
        ),
      ),
      throwsA(isA<AssetHierarchyException>()),
    );
    expect(server.requests.length, 1);
    expect(
      (await store.read('acceptance-a'))!.state,
      DurableSubmissionState.uncertain,
    );
  });

  test(
    'a wrong receipt cannot settle despite having the right request and cover',
    () async {
      server.invalidReceiptVersion = 7;
      await expectLater(submit(), throwsA(anything));
      final saved = await store.read('acceptance-a');
      expect(saved!.state.isAccepted, isFalse);
      expect(saved.receiptJson, isNull);
      expect(server.readCalls, 0);
    },
  );

  test(
    'contradictory exact readback keeps acceptance pending for review',
    () async {
      server.wrongReadbackActor = true;
      await expectLater(submit(), throwsA(isA<AssetHierarchyException>()));
      expect(
        (await store.read('acceptance-a'))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await reopen();
      await expectLater(
        controller.check('acceptance-a'),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(server.requests.length, 1);
    },
  );

  test('unavailable native journal prevents dispatch', () async {
    await database.close();
    await expectLater(submit(), throwsA(anything));
    expect(server.requests, isEmpty);
    expect(capabilityCalls, 0);
  });
}

class _GatedReconciliationStore extends DurableSubmissionRepository {
  _GatedReconciliationStore(super.isar, this.entered, this.release);
  final Completer<void> entered;
  final Completer<void> release;

  @override
  Future<DurableSubmission> markReconciled({
    required String submissionId,
    required String envelopeSha256,
    required String receiptSha256,
    Future<void> Function(Isar transactionStore)? adoptInTransaction,
  }) async {
    entered.complete();
    await release.future;
    return super.markReconciled(
      submissionId: submissionId,
      envelopeSha256: envelopeSha256,
      receiptSha256: receiptSha256,
      adoptInTransaction: adoptInTransaction,
    );
  }
}

final _input = InnerCoverAcceptanceInput(
  inspectedOn: DateTime.utc(2026, 8, 20, 10),
  acceptanceReference: 'Inspection IC-A',
  reason: 'Reviewed complete inspection evidence',
  leakTestReference: 'Leak A',
);

AppUser _admin(String uid) => AppUser(
  uid: uid,
  name: 'Admin',
  email: 'admin@example.com',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _AcceptanceServer extends Fake implements AssetHierarchyRepository {
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? acceptedRequest;
  var acceptedMutations = 0;
  var readCalls = 0;
  var currentVersion = 1;
  bool loseNextResponse = false;
  bool failNextRead = false;
  bool wrongReadbackActor = false;
  int? invalidReceiptVersion;
  void Function()? afterAccepted;

  InnerCoverProfile get profile => InnerCoverProfile(
    id: 'cover-a',
    assetClassId: 'class-inner',
    assetClassCode: 'INNER_COVER',
    assetClassName: 'Inner Cover',
    serialNumber: 'IC-A',
    normalizedSerialNumber: 'ICA',
    sourceType: InnerCoverSourceType.purchased,
    originClassification: InnerCoverOriginClassification.documentedPurchase,
    lifecycleState: acceptedRequest == null
        ? InnerCoverLifecycleState.awaitingInspection
        : InnerCoverLifecycleState.available,
    traceabilityGrade: InnerCoverTraceabilityGrade.t3,
    version: currentVersion,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 9, 12),
    lastMutationId: acceptedRequest?['requestId'] as String? ?? 'registration',
    acceptedByUid: acceptedRequest == null
        ? null
        : wrongReadbackActor
        ? 'other-admin'
        : 'admin-a',
    acceptedByName: acceptedRequest == null ? null : 'Admin',
    acceptedAt: acceptedRequest == null
        ? null
        : DateTime.parse(
            (acceptedRequest!['acceptanceDraft'] as Map)['inspectedOn']
                as String,
          ),
    acceptanceReference: acceptedRequest == null
        ? null
        : (acceptedRequest!['acceptanceDraft'] as Map)['acceptanceReference']
              as String,
  );

  @override
  Future<AssetHierarchyMutationReceipt> dispatchFrozenInnerCoverAcceptance(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) async {
    expect(originActorUid, 'admin-a');
    final replay = acceptedRequest != null;
    if (replay) expect(request, acceptedRequest);
    requests.add(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(request)) as Map),
    );
    if (!replay) {
      acceptedMutations++;
      acceptedRequest = requests.last;
      currentVersion = (request['expectedVersion'] as int) + 1;
    }
    afterAccepted?.call();
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const AssetHierarchyException('Response lost');
    }
    return AssetHierarchyMutationReceipt(
      requestId: request['requestId'] as String,
      operation: 'ACCEPT_INNER_COVER',
      entityId: 'cover-a',
      version: invalidReceiptVersion ?? (request['expectedVersion'] as int) + 1,
      auditId: 'inner_cover_${request['requestId']}',
      committedAt: DateTime.utc(2026, 9, 12),
      idempotentReplay: replay,
    );
  }

  @override
  Future<InnerCoverProfile> readInnerCoverFromServer(
    String id, {
    int? minimumVersion,
  }) async {
    readCalls++;
    expect(id, 'cover-a');
    if (failNextRead) {
      failNextRead = false;
      throw const AssetHierarchyException('Readback unavailable');
    }
    return profile;
  }
}
