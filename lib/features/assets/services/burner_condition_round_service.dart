import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../auth/data/user_model.dart';
import '../data/asset_registry_model.dart';
import '../data/burner_condition_round.dart';

const burnerConditionRoundCallableName = 'mutateAssetHierarchy';
const burnerConditionRoundCallableRegion = 'asia-south1';

class BurnerConditionRoundException implements Exception {
  const BurnerConditionRoundException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class BurnerConditionRoundResult {
  const BurnerConditionRoundResult({
    required this.roundId,
    required this.assetInstanceId,
    required this.committedAt,
    required this.idempotentReplay,
    this.directiveId,
  });

  final String roundId;
  final String assetInstanceId;
  final String? directiveId;
  final DateTime committedAt;
  final bool idempotentReplay;

  factory BurnerConditionRoundResult.fromMap(
    Map<String, dynamic> map, {
    required String expectedRequestId,
    required String expectedAssetClassId,
    required String expectedAssetInstanceId,
  }) {
    const operation = burnerConditionRoundOperation;
    final source = '$burnerConditionRoundCallableName/$expectedRequestId';
    const expectedKeys = <String>{
      'ok',
      'requestId',
      'operation',
      'roundId',
      'assetClassId',
      'assetInstanceId',
      'directiveId',
      'committedAt',
      'idempotentReplay',
    };
    if (map['ok'] != true ||
        map.keys.toSet().length != expectedKeys.length ||
        !map.keys.toSet().containsAll(expectedKeys) ||
        map['requestId'] != expectedRequestId ||
        map['roundId'] != expectedRequestId ||
        map['operation'] != operation ||
        map['assetClassId'] != expectedAssetClassId ||
        map['assetInstanceId'] != expectedAssetInstanceId) {
      throw PersistedDataFormatException(
        field: 'responseIdentity',
        source: source,
        detail: 'request, round, operation, or asset mismatch',
      );
    }
    final directiveId = readOptionalPersistedString(
      map['directiveId'],
      field: 'directiveId',
      source: source,
    );
    if (directiveId != null &&
        directiveId != 'burner_round_red_hot_$expectedRequestId') {
      throw PersistedDataFormatException(
        field: 'directiveId',
        source: source,
        detail: 'does not match the deterministic round directive',
      );
    }
    return BurnerConditionRoundResult(
      roundId: expectedRequestId,
      assetInstanceId: expectedAssetInstanceId,
      directiveId: directiveId,
      committedAt: readRequiredPersistedDateTime(
        map['committedAt'],
        field: 'committedAt',
        source: source,
      ),
      idempotentReplay: readRequiredPersistedBool(
        map['idempotentReplay'],
        field: 'idempotentReplay',
        source: source,
      ),
    );
  }
}

class BurnerConditionRoundService {
  BurnerConditionRoundService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;
  static const _uuid = Uuid();

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: burnerConditionRoundCallableRegion);

  Future<BurnerConditionRoundResult> record({
    required AssetInstanceRecord furnace,
    required List<BurnerConditionObservation> observations,
    required AppUser actor,
    String? roundNote,
  }) async {
    if (!actor.canRecordBurnerConditionRound) {
      throw const BurnerConditionRoundException(
        'Your role cannot record a burner condition round.',
        code: 'permission-denied',
      );
    }
    if (observations.length != 8 ||
        observations.asMap().entries.any(
          (entry) => entry.value.position != entry.key + 1,
        )) {
      throw const BurnerConditionRoundException(
        'Record every burner position from 1 to 8.',
        code: 'invalid-argument',
      );
    }
    final requestId = _uuid.v4();
    final request = <String, dynamic>{
      'requestId': requestId,
      'operation': burnerConditionRoundOperation,
      'assetClassId': furnace.assetClassId,
      'assetInstanceId': furnace.id,
      'expectedAssetVersion': furnace.version,
      'observations': observations
          .map((item) => item.toCommandMap())
          .toList(growable: false),
      'roundNote': _cleanOptionalText(roundNote),
    };
    try {
      final response = await _client
          .httpsCallable(burnerConditionRoundCallableName)
          .call<Map<String, dynamic>>(request);
      return BurnerConditionRoundResult.fromMap(
        Map<String, dynamic>.from(response.data),
        expectedRequestId: requestId,
        expectedAssetClassId: furnace.assetClassId,
        expectedAssetInstanceId: furnace.id,
      );
    } on FirebaseFunctionsException catch (error) {
      throw BurnerConditionRoundException(
        error.message ?? 'The burner condition round could not be recorded.',
        code: error.code,
      );
    } on PersistedDataFormatException catch (error) {
      throw BurnerConditionRoundException(
        'The server returned invalid burner-round evidence: $error',
        code: 'data-loss',
      );
    }
  }
}

String? _cleanOptionalText(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
