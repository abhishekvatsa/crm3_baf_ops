import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/assets/services/asset_registry_submission_controller.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import '../tool/test_support/test_isar_core.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> request([String id = requestId]) => {
  'requestId': id,
  'operation': 'CREATE_COMPONENT_INSTANCE',
  'assetClassId': 'furnace',
  'assetInstanceId': 'furnace-7',
  'componentInstanceId': 'physical-component-1',
  'expectedAssetInstanceVersion': 3,
  'reason': 'Install the reviewed replacement',
  'componentDraft': {'serialNumber': 'ABC-123'},
};
AppUser user(String uid) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@test.local',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory dir;
  late Isar db;
  late DurableSubmissionRepository store;
  late AssetRegistrySubmissionController controller;
  late _Server server;
  late AppUser actor;
  Future<void> open() async {
    db = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: dir.path,
      name: 'registry_recovery',
      inspector: false,
    );
    store = DurableSubmissionRepository(db);
    controller = AssetRegistrySubmissionController(
      store: store,
      repository: server,
      requireActor: () => actor,
      requireCapability: (_) async {},
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('registry_recovery_');
    server = _Server();
    actor = user('original');
    await open();
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });
  test(
    'lost reply survives storage reopen and does not issue another physical identity',
    () async {
      server.loseReply = true;
      await expectLater(
        controller.submit(request(), actor),
        throwsA(isA<AssetHierarchyException>()),
      );
      final original = (await store.read(requestId))!.envelopeJson;
      await db.close();
      await open();
      server.loseReply = false;
      final receipt = await controller.check(requestId);
      expect(receipt.entityId, 'physical-component-1');
      expect(
        (await store.read(requestId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect((await store.read(requestId))!.envelopeJson, original);
      expect(server.requests.map(jsonEncode).toSet(), hasLength(1));
    },
  );
  test(
    'uncertain creation blocks a new UUID and another account cannot retry it',
    () async {
      server.loseReply = true;
      await expectLater(
        controller.submit(request(), actor),
        throwsA(isA<AssetHierarchyException>()),
      );
      await expectLater(
        controller.submit(
          request('22222222-2222-4222-8222-222222222222'),
          actor,
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      actor = user('different');
      await expectLater(
        controller.check(requestId),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(server.requests, hasLength(1));
    },
  );
  test(
    'wrong receipt identity is retained as uncertain and never reported accepted',
    () async {
      server.wrongReceipt = true;
      await expectLater(
        controller.submit(request(), actor),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(
        (await store.read(requestId))!.state,
        DurableSubmissionState.uncertain,
      );
    },
  );
  test(
    'tag collision releases the pending slot but preserves original intent',
    () async {
      server.tagCollision = true;
      await expectLater(
        controller.submit(request(), actor),
        throwsA(isA<AssetTagCollisionException>()),
      );
      expect(
        (await store.read(requestId))!.state,
        DurableSubmissionState.rejected,
      );
      expect(
        await store.findUnresolvedForResource(
          AssetRegistrySubmissionController.resource,
        ),
        isNull,
      );
      expect((await store.read(requestId))!.envelope['request'], request());
    },
  );
}

class _Server implements AssetHierarchyRepository {
  bool loseReply = false, wrongReceipt = false, tagCollision = false;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<AssetHierarchyMutationReceipt> dispatchFrozenRegistry(
    Map<String, dynamic> request, {
    required String originActorUid,
  }) async {
    requests.add(Map<String, dynamic>.from(request));
    if (tagCollision) {
      throw const AssetTagCollisionException(
        normalizedTag: 'TAG',
        existingNodeId: 'node',
        existingNodeName: 'Other',
        existingAssetClassId: 'furnace',
        existingAssetClassName: 'Furnace',
        existingPath: [],
      );
    }
    if (loseReply) throw StateError('response lost');
    return AssetHierarchyMutationReceipt.fromMap({
      'ok': true,
      'requestId': request['requestId'],
      'operation': request['operation'],
      'assetClassId': request['assetClassId'],
      'nodeId': wrongReceipt
          ? 'wrong-physical-identity'
          : request['componentInstanceId'],
      'version': 1,
      'auditId': 'asset_registry_${request['requestId']}',
      'committedAt': '2026-09-20T00:00:00.000Z',
      'idempotentReplay': requests.length > 1,
    }, request: request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
