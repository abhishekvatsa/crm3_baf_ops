import 'dart:io';
import 'package:crm3_baf_ops/core/persistence/durable_submission_review.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/assets/services/asset_condition_submission_controller.dart';
import '../tool/test_support/test_isar_core.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> request() => {
  'requestId': requestId,
  'operation': 'DECLARE_ASSET_CONDITION',
  'assetClassId': 'furnace',
  'assetInstanceId': 'furnace-7',
  'expectedVersion': 0,
  'condition': 'down',
  'causeKeys': ['breakdown'],
  'reason': 'Drive failed',
  'linkedIssueIds': <String>[],
};
AppUser user([String id = 'original', AppRole role = AppRole.admin]) => AppUser(
  uid: id,
  name: id,
  email: '$id@test.invalid',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Isar db;
  late Directory dir;
  late DurableSubmissionRepository store;
  late AssetConditionSubmissionController controller;
  late _Server server;
  late AppUser actor;
  Future<void> open() async {
    db = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: dir.path,
      name: 'condition_recovery',
      inspector: false,
    );
    store = DurableSubmissionRepository(db);
    controller = AssetConditionSubmissionController(
      store: store,
      repository: server,
      requireActor: () => actor,
      requireCapability: (_) async {},
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('condition_recovery');
    server = _Server();
    actor = user();
    await open();
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    assert(
      dir.path.startsWith(Directory.systemTemp.path) &&
          dir.path.contains('condition_recovery'),
    );
    await dir.delete(recursive: true);
  });
  test(
    'lost reply survives restart; original acceptance recovers after later restoration',
    () async {
      server.loseReply = true;
      await expectLater(
        controller.submit(request: request(), originActorUid: actor.uid),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(
        DurableSubmissionReviewTarget.from(
          (await store.read(requestId))!,
        ).domain,
        'assetCondition',
      );
      final bytes = (await store.read(requestId))!.envelopeJson;
      await db.close();
      await open();
      server.loseReply = false;
      server.currentVersion = 2;
      final current = await controller.check(requestId);
      expect(current.version, 2);
      expect(current.condition, AssetOperationalCondition.available);
      expect((await store.read(requestId))!.envelopeJson, bytes);
      expect(
        (await store.read(requestId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(server.sent.every((r) => r['requestId'] == requestId), isTrue);
    },
  );
  test('replacement account cannot dispatch the saved request', () async {
    server.loseReply = true;
    await expectLater(
      controller.submit(request: request(), originActorUid: actor.uid),
      throwsA(isA<AssetHierarchyException>()),
    );
    actor = user('replacement');
    expect(await controller.pending('furnace-7'), isNull);
    await expectLater(
      controller.check(requestId),
      throwsA(isA<AssetHierarchyException>()),
    );
    expect(server.sent.length, 1);
  });
  test(
    'accepted readback survives role loss and never rewrites later state',
    () async {
      server.failRead = true;
      await expectLater(
        controller.submit(request: request(), originActorUid: actor.uid),
        throwsA(isA<AssetHierarchyException>()),
      );
      actor = user('original', AppRole.contractSupervisor);
      server.failRead = false;
      server.currentVersion = 2;
      expect((await controller.check(requestId)).version, 2);
      expect(server.sent.length, 1);
    },
  );
  test(
    'equal-version contradictory readback stays accepted awaiting review',
    () async {
      server.wrongMutation = true;
      await expectLater(
        controller.submit(request: request(), originActorUid: actor.uid),
        throwsA(isA<AssetHierarchyException>()),
      );
      expect(
        (await store.read(requestId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
    },
  );
}

class _Server extends Fake implements AssetHierarchyRepository {
  bool loseReply = false, failRead = false, wrongMutation = false;
  int currentVersion = 1;
  final sent = <Map<String, dynamic>>[];
  @override
  Future<AssetHierarchyMutationReceipt> dispatchFrozenAssetCondition(
    Map<String, dynamic> value, {
    required String originActorUid,
  }) async {
    sent.add({...value});
    if (loseReply) throw const AssetHierarchyException('Lost response');
    return AssetHierarchyMutationReceipt(
      requestId: requestId,
      operation: 'DECLARE_ASSET_CONDITION',
      entityId: 'furnace-7',
      version: 1,
      auditId: 'asset_condition_$requestId',
      committedAt: DateTime.utc(2026, 9, 20),
      idempotentReplay: sent.length > 1,
    );
  }

  @override
  Future<AssetOperationalConditionRecord> readAssetConditionFromServer(
    String assetInstanceId, {
    int? minimumVersion,
  }) async {
    if (failRead) throw const AssetHierarchyException('Read unavailable');
    final later = currentVersion > 1;
    return AssetOperationalConditionRecord(
      assetInstanceId: 'furnace-7',
      assetClassId: 'furnace',
      assetClassCode: 'FURNACE',
      assetClassName: 'Furnace',
      assetNumber: 7,
      assetName: 'Furnace 7',
      condition: later
          ? AssetOperationalCondition.available
          : AssetOperationalCondition.down,
      active: !later,
      causes: later ? [] : [AssetConditionCause.breakdown],
      reason: later ? 'Restored' : 'Drive failed',
      linkedIssueIds: [],
      declaredAt: DateTime.utc(2026, 9, 20),
      declaredByUid: 'original',
      declaredByName: 'Original',
      restoredAt: later ? DateTime.utc(2026, 9, 21) : null,
      restoredByUid: later ? 'supervisor' : null,
      restoredByName: later ? 'Supervisor' : null,
      previousCondition: AssetOperationalCondition.available,
      version: currentVersion,
      updatedAt: DateTime.utc(2026, 9, 21),
      updatedByUid: 'original',
      updatedByName: 'Original',
      lastMutationId: later
          ? 'later-restoration'
          : wrongMutation
          ? 'wrong'
          : requestId,
    );
  }
}
