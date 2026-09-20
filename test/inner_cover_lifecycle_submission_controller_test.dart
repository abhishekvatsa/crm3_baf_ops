import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/assets/services/inner_cover_lifecycle_submission_controller.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

// Actual native journal + actual lifecycle controller. The fake remote controls
// response timing/read availability; backend custody is tested independently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late _LifecycleServer server;
  late InnerCoverLifecycleSubmissionController controller;
  late AppUser actor;
  late DateTime now;

  InnerCoverLifecycleSubmissionController owner(
    DurableSubmissionRepository journal,
  ) => InnerCoverLifecycleSubmissionController(
    store: journal,
    repository: server,
    requireActor: () => actor,
    requireCapability: (_) async {},
  );

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      name: 'inner_cover_lifecycle_controller',
      directory: directory.path,
      inspector: false,
    );
    store = DurableSubmissionRepository(database, now: () => now);
    controller = owner(store);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ic_lifecycle_');
    now = DateTime.utc(2026, 9, 20, 8);
    actor = _admin('admin-a');
    server = _LifecycleServer();
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

  Future<InnerCoverProfile> submit(Map<String, dynamic> request) =>
      controller.submit(request: request, originActorUid: 'admin-a');

  for (final acceptedBeforeLoss in [false, true]) {
    test(
      'registration recovers after reopen without a visible profile; accepted=$acceptedBeforeLoss',
      () async {
        server.failBeforeAcceptance = !acceptedBeforeLoss;
        server.loseReply = acceptedBeforeLoss;
        await expectLater(
          submit(_registration()),
          throwsA(isA<AssetHierarchyException>()),
        );
        final saved = (await store.read('register-a'))!;
        expect(saved.state, DurableSubmissionState.uncertain);
        expect(server.profiles.containsKey('cover-a'), acceptedBeforeLoss);
        await reopen();
        final pending = await controller.pendingRegistrations();
        expect(pending.map((row) => row.submissionId), ['register-a']);
        expect(pending.single.envelopeJson, saved.envelopeJson);
        final result = await controller.check(pending.single.submissionId);
        expect(result.id, 'cover-a');
        expect(server.acceptedCount, 1);
        expect(server.requests[1], server.requests[0]);
        expect(
          (await store.read('register-a'))!.state,
          DurableSubmissionState.reconciled,
        );
        expect(await controller.pendingRegistrations(), isEmpty);
      },
    );
  }

  test(
    'same request ID with changed instructions is refused without dispatch',
    () async {
      server.loseReply = true;
      await expectLater(
        submit(_registration()),
        throwsA(isA<AssetHierarchyException>()),
      );
      final before = (await store.read('register-a'))!.envelopeJson;
      await expectLater(
        submit({..._registration(), 'reason': 'Different instruction'}),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(server.requests, hasLength(1));
      expect((await store.read('register-a'))!.envelopeJson, before);
    },
  );

  test('pending registrations never move to a different account', () async {
    server.failBeforeAcceptance = true;
    await expectLater(
      submit(_registration()),
      throwsA(isA<AssetHierarchyException>()),
    );
    final saved = (await controller.pendingRegistrations()).single;
    actor = _admin('admin-b');
    expect(await controller.pendingRegistrations(), isEmpty);
    expect(
      () => controller.registrationRequestOf(saved),
      throwsA(isA<AssetHierarchyException>()),
    );
    await expectLater(
      controller.check(saved.submissionId),
      throwsA(isA<AssetHierarchyException>()),
    );
    expect(server.requests, hasLength(1));
  });

  test(
    'account change during native pending-list read withholds old-account rows',
    () async {
      server.failBeforeAcceptance = true;
      await expectLater(
        submit(_registration()),
        throwsA(isA<AssetHierarchyException>()),
      );
      final gated = _GatedListStore(database);
      final result = owner(gated).pendingRegistrations();
      final assertion = expectLater(
        result,
        throwsA(isA<AssetHierarchyException>()),
      );
      await gated.entered.future;
      actor = _admin('admin-b');
      gated.release.complete();
      await assertion;
    },
  );

  for (final replayFirst in [false, true]) {
    test(
      'expired claims settle original and replay in either order; replayFirst=$replayFirst',
      () async {
        server.gateReplies = true;
        final original = submit(_registration());
        await _until(() => server.replyGates.length == 1);
        now = now.add(const Duration(minutes: 6));
        final retry = controller.check('register-a');
        await _until(() => server.replyGates.length == 2);
        final first = replayFirst ? 1 : 0;
        server.replyGates[first].complete(server.receipts[first]);
        await (replayFirst ? retry : original);
        final capsule = (await store.read('register-a'))!.receiptJson;
        server.replyGates[1 - first].complete(server.receipts[1 - first]);
        await (replayFirst ? original : retry);
        expect((await store.read('register-a'))!.receiptJson, capsule);
        expect(jsonDecode(capsule!)['idempotentReplay'], isFalse);
        expect(server.acceptedCount, 1);
        await reopen();
        await controller.check('register-a');
        expect(server.requests, hasLength(2));
      },
    );
  }

  test('an authoritative receipt mismatch cannot settle acceptance', () async {
    server.corruptReceiptVersion = true;
    await expectLater(
      submit(_registration()),
      throwsA(isA<AssetHierarchyException>()),
    );
    final saved = (await store.read('register-a'))!;
    expect(saved.state.isAccepted, isFalse);
    expect(saved.receiptJson, isNull);
    expect(server.reads, isEmpty);
  });

  for (final operation in ['REPLACE_INNER_COVER', 'SWAP_INNER_COVERS']) {
    test(
      '$operation keeps acceptance until both affected profiles are confirmed',
      () async {
        server.unreadable.add('cover-b');
        final request = _movement(operation);
        await expectLater(
          submit(request),
          throwsA(isA<AssetHierarchyException>()),
        );
        expect(
          (await store.read('move-a'))!.state,
          DurableSubmissionState.acceptedPendingAdoption,
        );
        await reopen();
        server.unreadable.clear();
        // Later legitimate work must not force today's view to equal old after-images.
        server.profiles['cover-b'] = _profile('cover-b', 7, 'later-movement');
        await controller.check('move-a');
        expect(server.reads, contains('cover-b'));
        expect(server.requests, hasLength(1));
        expect(
          (await store.read('move-a'))!.state,
          DurableSubmissionState.reconciled,
        );
      },
    );
  }

  test(
    'same-revision contradictory secondary evidence stays pending',
    () async {
      server.wrongMutationFor.add('cover-b');
      await expectLater(
        submit(_movement('SWAP_INNER_COVERS')),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(
        (await store.read('move-a'))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect(server.requests, hasLength(1));
    },
  );

  test(
    'fabrication confirms each changed donor once before adoption',
    () async {
      server.unreadable.add('donor-a');
      await expectLater(
        submit(_registration(withDonor: true)),
        throwsA(isA<AssetHierarchyException>()),
      );
      final saved = (await store.read('register-a'))!;
      expect(saved.state, DurableSubmissionState.acceptedPendingAdoption);
      await reopen();
      server.unreadable.clear();
      server.reads.clear();
      await controller.check('register-a');
      expect(server.reads, ['cover-a', 'donor-a']);
      expect(server.requests, hasLength(1));
      expect(
        (await store.read('register-a'))!.envelopeJson,
        saved.envelopeJson,
      );
    },
  );
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Expected response boundary was not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Map<String, dynamic> _registration({bool withDonor = false}) => {
  'requestId': 'register-a',
  'operation': 'REGISTER_INNER_COVER',
  'innerCoverId': 'cover-a',
  'innerCoverAssetClassId': 'class-inner',
  'reason': 'Register the documented cover',
  'registrationDraft': {
    'serialNumber': 'IC-A',
    'sourceType': withDonor ? 'fabricated' : 'purchased',
    'fabricationSections': withDonor
        ? [
            for (final part in ['top', 'shell'])
              {
                'sectionId': part,
                'materialSource': 'reusedKnownDonor',
                'donorInnerCoverId': 'donor-a',
                'donorExpectedVersion': 4,
                'donorSectionKey': part,
              },
          ]
        : [],
  },
};

Map<String, dynamic> _movement(String operation) => {
  'requestId': 'move-a',
  'operation': operation,
  'innerCoverId': 'cover-a',
  'expectedVersion': 2,
  'displacedInnerCoverId': 'cover-b',
  'expectedDisplacedVersion': 4,
  'sourceBaseAssetInstanceId': 'base-a',
  'expectedSourceAssignmentVersion': 1,
  'targetBaseAssetInstanceId': 'base-b',
  'expectedTargetAssignmentVersion': 1,
  'targetState': 'awaitingInspection',
  'reason': 'Reviewed physical change',
};

AppUser _admin(String uid) => AppUser(
  uid: uid,
  name: 'Admin',
  email: 'admin@example.com',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

InnerCoverProfile _profile(String id, int version, String mutation) =>
    InnerCoverProfile(
      id: id,
      assetClassId: 'class-inner',
      assetClassCode: 'INNER_COVER',
      assetClassName: 'Inner Cover',
      serialNumber: id,
      normalizedSerialNumber: id.toUpperCase(),
      sourceType: InnerCoverSourceType.purchased,
      originClassification: InnerCoverOriginClassification.documentedPurchase,
      lifecycleState: InnerCoverLifecycleState.awaitingInspection,
      traceabilityGrade: InnerCoverTraceabilityGrade.t3,
      version: version,
      createdAt: DateTime.utc(2026, 8),
      updatedAt: DateTime.utc(2026, 9, 20),
      lastMutationId: mutation,
    );

class _GatedListStore extends DurableSubmissionRepository {
  _GatedListStore(super.isar);
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<DurableSubmission>> listForActor(
    String actorUid, {
    bool includeTerminal = false,
  }) async {
    final rows = await super.listForActor(
      actorUid,
      includeTerminal: includeTerminal,
    );
    entered.complete();
    await release.future;
    return rows;
  }
}

class _LifecycleServer extends Fake implements AssetHierarchyRepository {
  final requests = <Map<String, dynamic>>[];
  final profiles = <String, InnerCoverProfile>{};
  final reads = <String>[];
  final unreadable = <String>{};
  final wrongMutationFor = <String>{};
  final replyGates = <Completer<AssetHierarchyMutationReceipt>>[];
  final receipts = <AssetHierarchyMutationReceipt>[];
  int acceptedCount = 0;
  bool failBeforeAcceptance = false;
  bool loseReply = false;
  bool gateReplies = false;
  bool corruptReceiptVersion = false;

  @override
  Future<AssetHierarchyMutationReceipt> dispatchFrozenInnerCoverLifecycle(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) async {
    expect(originActorUid, 'admin-a');
    requests.add(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(request)) as Map),
    );
    if (failBeforeAcceptance) {
      failBeforeAcceptance = false;
      throw const AssetHierarchyException('Connection lost before acceptance');
    }
    final replay = acceptedCount > 0;
    final version = request['operation'] == 'REGISTER_INNER_COVER'
        ? 1
        : (request['expectedVersion'] as int) + 1;
    final secondary = request['expectedDisplacedVersion'] as int?;
    final requestId = request['requestId'] as String;
    if (!replay) {
      acceptedCount++;
      profiles['cover-a'] = _profile('cover-a', version, requestId);
      if (secondary != null) {
        profiles['cover-b'] = _profile('cover-b', secondary + 1, requestId);
      }
      final draft = request['registrationDraft'];
      if (draft is Map && (draft['fabricationSections'] as List).isNotEmpty) {
        profiles['donor-a'] = _profile('donor-a', 5, requestId);
      }
    }
    if (loseReply) {
      loseReply = false;
      throw const AssetHierarchyException('Accepted response lost');
    }
    final receipt = AssetHierarchyMutationReceipt(
      requestId: requestId,
      operation: request['operation'] as String,
      entityId: 'cover-a',
      version: corruptReceiptVersion ? version + 1 : version,
      secondaryVersion: secondary == null ? null : secondary + 1,
      auditId: 'inner_cover_$requestId',
      committedAt: DateTime.utc(2026, 9, 20, 8),
      idempotentReplay: replay,
    );
    if (gateReplies) {
      final gate = Completer<AssetHierarchyMutationReceipt>();
      receipts.add(receipt);
      replyGates.add(gate);
      return gate.future;
    }
    return receipt;
  }

  @override
  Future<InnerCoverProfile> readInnerCoverFromServer(
    String id, {
    int? minimumVersion,
  }) async {
    reads.add(id);
    if (unreadable.contains(id) || !profiles.containsKey(id)) {
      throw const AssetHierarchyException(
        'Affected profile readback unavailable',
      );
    }
    final profile = profiles[id]!;
    return wrongMutationFor.contains(id)
        ? _profile(id, profile.version, 'contradictory-mutation')
        : profile;
  }
}
