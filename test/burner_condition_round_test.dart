import 'dart:convert';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_idempotency_store.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> roundMap({
  List<Map<String, dynamic>>? observations,
  List<int>? redHotPositions,
  List<int>? microampPositions,
  Object? directiveId = 'burner_round_red_hot_round-1',
}) => <String, dynamic>{
  'schemaVersion': 1,
  'roundId': 'round-1',
  'operation': burnerConditionRoundOperation,
  'assetClassId': 'furnace-class',
  'assetClassCode': 'FURNACE',
  'assetClassName': 'Furnace',
  'assetInstanceId': 'furnace-2',
  'assetInstanceVersion': 4,
  'assetNumber': 2,
  'assetName': 'Furnace 2',
  'observations':
      observations ??
      List<Map<String, dynamic>>.generate(
        8,
        (index) => <String, dynamic>{
          'position': index + 1,
          'flameObservation': index == 7 ? 'notOperating' : 'seen',
          'redHotObserved': index == 2,
          'microampReading': index == 0 ? 3.7 : null,
          'remarks': null,
        },
      ),
  'redHotPositions': redHotPositions ?? <int>[3],
  'microampPositions': microampPositions ?? <int>[1],
  'roundNote': 'Routine shift condition round.',
  'observedAt': DateTime.utc(2026, 8, 16, 18, 30),
  'recordedByUid': 'ops-1',
  'recordedByName': 'Operations One',
  'directiveId': directiveId,
  'fingerprint': 'burnerround1-sha256:${'a' * 64}',
};

Map<String, dynamic> roundMapV2() => <String, dynamic>{
  ...roundMap(),
  'schemaVersion': 2,
  'draftSealRedHotObserved': true,
  'hotAirAtDraftSealObserved': false,
  'uvObservations': List<Map<String, dynamic>>.generate(
    8,
    (index) => <String, dynamic>{
      'position': index + 1,
      'condition': 'serviceable',
      'remarks': null,
    },
  ),
  'directivePositions': <int>[3],
  'fingerprint': 'burnerround2-sha256:${'b' * 64}',
};

const requestId = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> resultMap() => <String, dynamic>{
  'ok': true,
  'requestId': requestId,
  'operation': burnerConditionRoundOperation,
  'roundId': requestId,
  'assetClassId': 'furnace-class',
  'assetInstanceId': 'furnace-2',
  'directiveId': 'burner_round_red_hot_$requestId',
  'committedAt': DateTime.utc(2026, 8, 16, 18, 30),
  'idempotentReplay': false,
};

Map<String, dynamic> complianceResultMap() => <String, dynamic>{
  'ok': true,
  'requestId': requestId,
  'operation': burnerDirectiveComplianceOperation,
  'roundId': requestId,
  'assetClassId': 'furnace-class',
  'assetInstanceId': 'furnace-2',
  'closedDirectiveId': 'burner_round_red_hot_source-round',
  'closedDirectiveVersion': 4,
  'newDirectiveId': null,
  'committedAt': DateTime.utc(2026, 8, 16, 18, 30),
  'idempotentReplay': false,
};

void main() {
  test('strict decoder retains complete eight-position round evidence', () {
    final round = BurnerConditionRound.fromMap(roundMap(), 'round-1');

    expect(round.observations, hasLength(8));
    expect(round.redHotPositions, <int>[3]);
    expect(round.microampPositions, <int>[1]);
    expect(round.observations.first.microampReading, 3.7);
    expect(round.directiveId, 'burner_round_red_hot_round-1');
  });

  test('derived position projections must agree with observations', () {
    for (final malformed in <Map<String, dynamic>>[
      roundMap(redHotPositions: <int>[]),
      roundMap(microampPositions: <int>[]),
      roundMap(directiveId: null),
      roundMap()..['roundId'] = 'different-round',
      roundMap()..remove('recordedByUid'),
    ]) {
      expect(
        () => BurnerConditionRound.fromMap(malformed, 'round-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('schema two retains UV and draft-seal condition authority', () {
    final round = BurnerConditionRound.fromMap(roundMapV2(), 'round-1');
    expect(round.draftSealRedHotObserved, isTrue);
    expect(round.hotAirAtDraftSealObserved, isFalse);
    expect(round.uvObservations, hasLength(8));
    expect(round.uvObservations[2].condition, BurnerUvCondition.serviceable);
    expect(round.directivePositions, <int>[3]);

    for (final malformed in <Map<String, dynamic>>[
      {...roundMapV2()}..remove('uvObservations'),
      {...roundMapV2(), 'directivePositions': <int>[]},
      {
        ...roundMapV2(),
        'uvObservations': List<Map<String, dynamic>>.from(
          roundMapV2()['uvObservations']! as List,
        )..removeLast(),
      },
    ]) {
      expect(
        () => BurnerConditionRound.fromMap(malformed, 'round-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('burner directive binding is exact and canonical', () {
    final binding = BurnerRedHotDirectiveBinding.tryDecode(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'trigger': 'burnerConditionRoundRedHot',
        'sourceRoundId': 'round-1',
        'burnerPositions': <int>[2, 4],
        'automaticPlantActuation': false,
      }),
    );

    expect(binding, isNotNull);
    expect(binding!.sourceRoundId, 'round-1');
    expect(binding.burnerPositions, <int>[2, 4]);
    expect(
      () => BurnerRedHotDirectiveBinding.tryDecode(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'trigger': 'burnerConditionRoundRedHot',
          'sourceRoundId': 'round-1',
          'burnerPositions': <int>[4, 2],
          'automaticPlantActuation': false,
        }),
      ),
      throwsFormatException,
    );
  });

  test(
    'directive compliance projects UV disposition without rewriting history',
    () {
      final current = BurnerConditionRound.fromMap(roundMapV2(), 'round-1');
      const binding = BurnerRedHotDirectiveBinding(
        sourceRoundId: 'round-1',
        burnerPositions: <int>[3],
      );
      final removed = projectBurnerDirectiveCompliance(
        current: current,
        binding: binding,
        dispositions: const <int, BurnerDirectiveComplianceDisposition>{
          3: BurnerDirectiveComplianceDisposition.uvHungRemoved,
        },
      );
      expect(removed.changed, isTrue);
      expect(removed.observations[2].redHotObserved, isTrue);
      expect(
        removed.observations[2].flameObservation,
        BurnerRoundFlameObservation.notOperating,
      );
      expect(removed.observations[2].microampReading, isNull);
      expect(removed.uvObservations[2].condition, BurnerUvCondition.hanging);

      final restored = projectBurnerDirectiveCompliance(
        current: current,
        binding: binding,
        dispositions: const <int, BurnerDirectiveComplianceDisposition>{
          3: BurnerDirectiveComplianceDisposition.restoredInService,
        },
      );
      expect(restored.changed, isTrue);
      expect(restored.observations[2].redHotObserved, isFalse);
      expect(
        restored.uvObservations[2].condition,
        BurnerUvCondition.serviceable,
      );
    },
  );

  test('partial, duplicate, and contradictory observations fail closed', () {
    final partial = List<Map<String, dynamic>>.from(
      roundMap()['observations']! as List,
    )..removeLast();
    final duplicate = List<Map<String, dynamic>>.from(
      roundMap()['observations']! as List,
    );
    duplicate[7] = <String, dynamic>{...duplicate[7], 'position': 7};
    final contradictory = List<Map<String, dynamic>>.from(
      roundMap()['observations']! as List,
    );
    contradictory[7] = <String, dynamic>{
      ...contradictory[7],
      'microampReading': 2.0,
    };

    for (final observations in [partial, duplicate, contradictory]) {
      expect(
        () => BurnerConditionRound.fromMap(
          roundMap(observations: observations),
          'round-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('callable result retains exact identity and commit evidence', () {
    final result = BurnerConditionRoundResult.fromMap(
      resultMap(),
      expectedRequestId: requestId,
      expectedAssetClassId: 'furnace-class',
      expectedAssetInstanceId: 'furnace-2',
    );

    expect(result.roundId, requestId);
    expect(result.directiveId, 'burner_round_red_hot_$requestId');
    expect(result.committedAt, DateTime.utc(2026, 8, 16, 18, 30));
    expect(result.idempotentReplay, isFalse);
  });

  test('callable result rejects extra, mismatched, or partial evidence', () {
    final malformedResults = <Map<String, dynamic>>[
      resultMap()..['unsupported'] = true,
      resultMap()..['assetClassId'] = 'different-class',
      resultMap()..['directiveId'] = 'different-directive',
      resultMap()..remove('committedAt'),
    ];
    for (final malformed in malformedResults) {
      expect(
        () => BurnerConditionRoundResult.fromMap(
          malformed,
          expectedRequestId: requestId,
          expectedAssetClassId: 'furnace-class',
          expectedAssetInstanceId: 'furnace-2',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('callable result translates non-object responses into data loss', () {
    for (final malformed in <Object?>[null, true, 'not-a-map', <Object?>[]]) {
      expect(
        () => BurnerConditionRoundResult.fromCallableData(
          malformed,
          expectedRequestId: requestId,
          expectedAssetClassId: 'furnace-class',
          expectedAssetInstanceId: 'furnace-2',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('compliance result retains the exact server closure receipt', () {
    final result = BurnerDirectiveComplianceResult.fromCallableData(
      complianceResultMap(),
      expectedRequestId: requestId,
      expectedAssetClassId: 'furnace-class',
      expectedAssetInstanceId: 'furnace-2',
      expectedDirectiveId: 'burner_round_red_hot_source-round',
    );

    expect(result.roundId, requestId);
    expect(result.closedDirectiveVersion, 4);
    expect(result.newDirectiveId, isNull);
    expect(result.committedAt, DateTime.utc(2026, 8, 16, 18, 30));
  });

  test(
    'compliance result rejects mismatched directive or successor evidence',
    () {
      for (final malformed in <Map<String, dynamic>>[
        complianceResultMap()..['closedDirectiveId'] = 'different-directive',
        complianceResultMap()
          ..['newDirectiveId'] = 'burner_round_red_hot_different-round',
        complianceResultMap()..['closedDirectiveVersion'] = 1,
      ]) {
        expect(
          () => BurnerDirectiveComplianceResult.fromCallableData(
            malformed,
            expectedRequestId: requestId,
            expectedAssetClassId: 'furnace-class',
            expectedAssetInstanceId: 'furnace-2',
            expectedDirectiveId: 'burner_round_red_hot_source-round',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      }
    },
  );

  test('compliance receipt survives retry-identity cleanup failure', () async {
    final committed = BurnerDirectiveComplianceResult.fromCallableData(
      complianceResultMap(),
      expectedRequestId: requestId,
      expectedAssetClassId: 'furnace-class',
      expectedAssetInstanceId: 'furnace-2',
      expectedDirectiveId: 'burner_round_red_hot_source-round',
    );

    final result = await finalizeBurnerDirectiveComplianceResult(
      result: committed,
      clearPendingIdentity: () async {
        throw StateError('local storage unavailable');
      },
    );

    expect(result.roundId, committed.roundId);
    expect(result.closedDirectiveVersion, committed.closedDirectiveVersion);
    expect(result.retryIdentityCleanupPending, isTrue);
  });

  test('committed round survives local retry cleanup failure', () async {
    final committed = BurnerConditionRoundResult.fromMap(
      resultMap(),
      expectedRequestId: requestId,
      expectedAssetClassId: 'furnace-class',
      expectedAssetInstanceId: 'furnace-2',
    );

    final result = await finalizeBurnerConditionRoundResult(
      result: committed,
      clearPendingIdentity: () async {
        throw StateError('local storage unavailable');
      },
    );

    expect(result.roundId, committed.roundId);
    expect(result.committedAt, committed.committedAt);
    expect(result.retryIdentityCleanupPending, isTrue);
  });

  test('storage admission failure becomes an operator-facing error', () async {
    final now = DateTime.utc(2026, 8, 16);
    final service = BurnerConditionRoundService(
      idempotencyStore: _ThrowingBurnerRoundIdentityStore(),
    );

    await expectLater(
      service.record(
        furnace: _furnace(now),
        observations: List<BurnerConditionObservation>.generate(
          8,
          (index) => BurnerConditionObservation(
            position: index + 1,
            flameObservation: BurnerRoundFlameObservation.seen,
            redHotObserved: false,
          ),
        ),
        actor: AppUser(
          uid: 'operations-1',
          name: 'Operations One',
          email: 'operations@example.com',
          roles: const [AppRole.operations],
          isApproved: true,
          createdAt: now,
        ),
      ),
      throwsA(
        isA<BurnerConditionRoundException>().having(
          (error) => error.code,
          'code',
          'failed-precondition',
        ),
      ),
    );
  });
}

class _ThrowingBurnerRoundIdentityStore
    extends BurnerConditionRoundIdempotencyStore {
  @override
  Future<BurnerConditionRoundPendingIdentity> resolve({
    required String actorUid,
    required String payloadFingerprint,
  }) {
    throw Exception('platform storage unavailable');
  }
}

AssetInstanceRecord _furnace(DateTime now) => AssetInstanceRecord(
  id: 'furnace-2',
  assetClassId: 'furnace-class',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetNumber: 2,
  name: 'Furnace 2',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 8,
  version: 4,
  createdAt: now,
  updatedAt: now,
  lastMutationId: 'asset-mutation-1',
);
