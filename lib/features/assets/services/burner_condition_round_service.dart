import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../auth/data/user_model.dart';
import '../data/asset_registry_model.dart';
import '../data/burner_condition_round.dart';
import 'burner_condition_round_idempotency_store.dart';

const burnerConditionRoundCallableName = 'mutateAssetHierarchy';
const burnerConditionRoundCallableRegion = 'asia-south1';
const burnerDirectiveComplianceOperation = 'COMPLETE_BURNER_RED_HOT_DIRECTIVE';

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
    this.retryIdentityCleanupPending = false,
  });

  final String roundId;
  final String assetInstanceId;
  final String? directiveId;
  final DateTime committedAt;
  final bool idempotentReplay;
  final bool retryIdentityCleanupPending;

  BurnerConditionRoundResult withRetryIdentityCleanupPending() {
    return BurnerConditionRoundResult(
      roundId: roundId,
      assetInstanceId: assetInstanceId,
      directiveId: directiveId,
      committedAt: committedAt,
      idempotentReplay: idempotentReplay,
      retryIdentityCleanupPending: true,
    );
  }

  factory BurnerConditionRoundResult.fromCallableData(
    Object? raw, {
    required String expectedRequestId,
    required String expectedAssetClassId,
    required String expectedAssetInstanceId,
  }) {
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'response',
        source: '$burnerConditionRoundCallableName/$expectedRequestId',
        detail: 'must be an object',
      );
    }
    final map = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw PersistedDataFormatException(
          field: 'response',
          source: '$burnerConditionRoundCallableName/$expectedRequestId',
          detail: 'contains a non-string field name',
        );
      }
      map[entry.key as String] = entry.value;
    }
    return BurnerConditionRoundResult.fromMap(
      map,
      expectedRequestId: expectedRequestId,
      expectedAssetClassId: expectedAssetClassId,
      expectedAssetInstanceId: expectedAssetInstanceId,
    );
  }

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

class BurnerDirectiveComplianceResult {
  const BurnerDirectiveComplianceResult({
    required this.roundId,
    required this.assetInstanceId,
    required this.closedDirectiveId,
    required this.closedDirectiveVersion,
    required this.committedAt,
    required this.idempotentReplay,
    this.newDirectiveId,
    this.retryIdentityCleanupPending = false,
  });

  final String roundId;
  final String assetInstanceId;
  final String closedDirectiveId;
  final int closedDirectiveVersion;
  final String? newDirectiveId;
  final DateTime committedAt;
  final bool idempotentReplay;
  final bool retryIdentityCleanupPending;

  BurnerDirectiveComplianceResult withRetryIdentityCleanupPending() {
    return BurnerDirectiveComplianceResult(
      roundId: roundId,
      assetInstanceId: assetInstanceId,
      closedDirectiveId: closedDirectiveId,
      closedDirectiveVersion: closedDirectiveVersion,
      newDirectiveId: newDirectiveId,
      committedAt: committedAt,
      idempotentReplay: idempotentReplay,
      retryIdentityCleanupPending: true,
    );
  }

  factory BurnerDirectiveComplianceResult.fromCallableData(
    Object? raw, {
    required String expectedRequestId,
    required String expectedAssetClassId,
    required String expectedAssetInstanceId,
    required String expectedDirectiveId,
  }) {
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'response',
        source: '$burnerConditionRoundCallableName/$expectedRequestId',
        detail: 'must be an object',
      );
    }
    final map = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw PersistedDataFormatException(
          field: 'response',
          source: '$burnerConditionRoundCallableName/$expectedRequestId',
          detail: 'contains a non-string field name',
        );
      }
      map[entry.key as String] = entry.value;
    }
    const expectedKeys = <String>{
      'ok',
      'requestId',
      'operation',
      'roundId',
      'assetClassId',
      'assetInstanceId',
      'closedDirectiveId',
      'closedDirectiveVersion',
      'newDirectiveId',
      'committedAt',
      'idempotentReplay',
    };
    final source = '$burnerConditionRoundCallableName/$expectedRequestId';
    if (map['ok'] != true ||
        map.keys.toSet().length != expectedKeys.length ||
        !map.keys.toSet().containsAll(expectedKeys) ||
        map['requestId'] != expectedRequestId ||
        map['roundId'] != expectedRequestId ||
        map['operation'] != burnerDirectiveComplianceOperation ||
        map['assetClassId'] != expectedAssetClassId ||
        map['assetInstanceId'] != expectedAssetInstanceId ||
        map['closedDirectiveId'] != expectedDirectiveId) {
      throw PersistedDataFormatException(
        field: 'responseIdentity',
        source: source,
        detail: 'request, round, operation, asset, or directive mismatch',
      );
    }
    final newDirectiveId = readOptionalPersistedString(
      map['newDirectiveId'],
      field: 'newDirectiveId',
      source: source,
    );
    if (newDirectiveId != null &&
        newDirectiveId != 'burner_round_red_hot_$expectedRequestId') {
      throw PersistedDataFormatException(
        field: 'newDirectiveId',
        source: source,
        detail: 'does not match the deterministic successor directive',
      );
    }
    return BurnerDirectiveComplianceResult(
      roundId: expectedRequestId,
      assetInstanceId: expectedAssetInstanceId,
      closedDirectiveId: expectedDirectiveId,
      closedDirectiveVersion: readRequiredPersistedInt(
        map['closedDirectiveVersion'],
        field: 'closedDirectiveVersion',
        source: source,
        minimum: 2,
      ),
      newDirectiveId: newDirectiveId,
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
  BurnerConditionRoundService({
    FirebaseFunctions? functions,
    BurnerConditionRoundIdempotencyStore? idempotencyStore,
  }) : _functions = functions,
       _idempotencyStore =
           idempotencyStore ?? BurnerConditionRoundIdempotencyStore();

  final FirebaseFunctions? _functions;
  final BurnerConditionRoundIdempotencyStore _idempotencyStore;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: burnerConditionRoundCallableRegion);

  Future<BurnerConditionRoundResult> record({
    required AssetInstanceRecord furnace,
    required List<BurnerConditionObservation> observations,
    required AppUser actor,
    String? roundNote,
    bool? draftSealRedHotObserved,
    bool? hotAirAtDraftSealObserved,
    List<BurnerUvObservation>? uvObservations,
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
    final extendedValues = <Object?>[
      draftSealRedHotObserved,
      hotAirAtDraftSealObserved,
      uvObservations,
    ];
    final extended = extendedValues.any((value) => value != null);
    if (extended && extendedValues.any((value) => value == null)) {
      throw const BurnerConditionRoundException(
        'Record both draft-seal conditions and all eight UV positions together.',
        code: 'invalid-argument',
      );
    }
    if (uvObservations != null &&
        (uvObservations.length != 8 ||
            uvObservations.asMap().entries.any(
              (entry) => entry.value.position != entry.key + 1,
            ))) {
      throw const BurnerConditionRoundException(
        'Record every UV position from 1 to 8.',
        code: 'invalid-argument',
      );
    }
    final payloadFingerprint = burnerConditionRoundPayloadFingerprint(
      furnace: furnace,
      observations: observations,
      roundNote: roundNote,
      draftSealRedHotObserved: draftSealRedHotObserved,
      hotAirAtDraftSealObserved: hotAirAtDraftSealObserved,
      uvObservations: uvObservations,
    );
    final pendingIdentity = await _resolvePendingIdentity(
      actorUid: actor.uid,
      payloadFingerprint: payloadFingerprint,
    );
    final requestId = pendingIdentity.requestId;
    try {
      final request = <String, dynamic>{
        'requestId': requestId,
        'operation': burnerConditionRoundOperation,
        'assetClassId': furnace.assetClassId,
        'assetInstanceId': furnace.id,
        'expectedAssetVersion': furnace.version,
        'observations': observations
            .map((item) => item.toCommandMap())
            .toList(growable: false),
        if (extended) ...<String, dynamic>{
          'draftSealRedHotObserved': draftSealRedHotObserved,
          'hotAirAtDraftSealObserved': hotAirAtDraftSealObserved,
          'uvObservations': uvObservations!
              .map((item) => item.toCommandMap())
              .toList(growable: false),
        },
        'roundNote': _cleanOptionalText(roundNote),
      };
      final response = await _client
          .httpsCallable(burnerConditionRoundCallableName)
          .call<Object?>(request);
      final result = BurnerConditionRoundResult.fromCallableData(
        response.data,
        expectedRequestId: requestId,
        expectedAssetClassId: furnace.assetClassId,
        expectedAssetInstanceId: furnace.id,
      );
      return finalizeBurnerConditionRoundResult(
        result: result,
        clearPendingIdentity:
            () => _idempotencyStore.clearIfMatches(
              actorUid: actor.uid,
              requestId: requestId,
            ),
      );
    } on FirebaseFunctionsException catch (error) {
      throw BurnerConditionRoundException(
        error.message ?? 'The burner condition round could not be recorded.',
        code: error.code,
      );
    } on PersistedDataFormatException catch (error) {
      throw BurnerConditionRoundException(
        'Burner-round response evidence is invalid: $error',
        code: 'data-loss',
      );
    }
  }

  Future<BurnerDirectiveComplianceResult> completeDirective({
    required AssetInstanceRecord furnace,
    required BurnerConditionRound current,
    required String directiveId,
    required int expectedDirectiveVersion,
    required Map<int, BurnerDirectiveComplianceDisposition> dispositions,
    required AppUser actor,
    String? closureRemarks,
  }) async {
    if (!actor.canRecordBurnerConditionRound) {
      throw const BurnerConditionRoundException(
        'Your role cannot record the required Burner/UV compliance evidence.',
        code: 'permission-denied',
      );
    }
    final cleanedDirectiveId = directiveId.trim();
    if (!cleanedDirectiveId.startsWith('burner_round_red_hot_') ||
        expectedDirectiveVersion < 1 ||
        current.assetClassId != furnace.assetClassId ||
        current.assetInstanceId != furnace.id ||
        dispositions.isEmpty ||
        dispositions.keys.any((position) => position < 1 || position > 8)) {
      throw const BurnerConditionRoundException(
        'The Burner/UV compliance identity is incomplete or stale.',
        code: 'failed-precondition',
      );
    }
    final orderedDispositions =
        dispositions.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    final canonical = <String, dynamic>{
      'operation': burnerDirectiveComplianceOperation,
      'assetClassId': furnace.assetClassId,
      'assetInstanceId': furnace.id,
      'expectedAssetVersion': furnace.version,
      'expectedCurrentRoundId': current.roundId,
      'directiveId': cleanedDirectiveId,
      'expectedDirectiveVersion': expectedDirectiveVersion,
      'dispositions': <Map<String, dynamic>>[
        for (final entry in orderedDispositions)
          <String, dynamic>{
            'position': entry.key,
            'disposition': entry.value.name,
          },
      ],
      'closureRemarks': _cleanOptionalText(closureRemarks),
    };
    final payloadFingerprint =
        sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
    final pendingIdentity = await _resolvePendingIdentity(
      actorUid: actor.uid,
      payloadFingerprint: payloadFingerprint,
    );
    final requestId = pendingIdentity.requestId;
    try {
      final response = await _client
          .httpsCallable(burnerConditionRoundCallableName)
          .call<Object?>(<String, dynamic>{
            'requestId': requestId,
            ...canonical,
          });
      final result = BurnerDirectiveComplianceResult.fromCallableData(
        response.data,
        expectedRequestId: requestId,
        expectedAssetClassId: furnace.assetClassId,
        expectedAssetInstanceId: furnace.id,
        expectedDirectiveId: cleanedDirectiveId,
      );
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw BurnerConditionRoundException(
        error.message ?? 'Burner directive compliance could not be completed.',
        code: error.code,
      );
    } on PersistedDataFormatException catch (error) {
      throw BurnerConditionRoundException(
        'Burner-compliance response evidence is invalid: $error',
        code: 'data-loss',
      );
    }
  }

  Future<BurnerDirectiveComplianceResult> finalizeDirectiveCompliance({
    required BurnerDirectiveComplianceResult result,
    required String actorUid,
  }) {
    return finalizeBurnerDirectiveComplianceResult(
      result: result,
      clearPendingIdentity:
          () => _idempotencyStore.clearIfMatches(
            actorUid: actorUid,
            requestId: result.roundId,
          ),
    );
  }

  Future<BurnerConditionRoundPendingIdentity> _resolvePendingIdentity({
    required String actorUid,
    required String payloadFingerprint,
  }) async {
    try {
      return await _idempotencyStore.resolve(
        actorUid: actorUid,
        payloadFingerprint: payloadFingerprint,
      );
    } on PersistedDataFormatException catch (error) {
      throw BurnerConditionRoundException(
        'The saved burner-round retry identity is invalid: $error',
        code: 'data-loss',
      );
    } catch (error) {
      throw BurnerConditionRoundException(
        'The burner-round retry identity could not be preserved safely: $error',
        code: 'failed-precondition',
      );
    }
  }
}

Future<BurnerDirectiveComplianceResult>
finalizeBurnerDirectiveComplianceResult({
  required BurnerDirectiveComplianceResult result,
  required Future<void> Function() clearPendingIdentity,
}) async {
  try {
    await clearPendingIdentity();
    return result;
  } catch (_) {
    return result.withRetryIdentityCleanupPending();
  }
}

Future<BurnerConditionRoundResult> finalizeBurnerConditionRoundResult({
  required BurnerConditionRoundResult result,
  required Future<void> Function() clearPendingIdentity,
}) async {
  try {
    await clearPendingIdentity();
    return result;
  } catch (_) {
    return result.withRetryIdentityCleanupPending();
  }
}

String burnerConditionRoundPayloadFingerprint({
  required AssetInstanceRecord furnace,
  required List<BurnerConditionObservation> observations,
  String? roundNote,
  bool? draftSealRedHotObserved,
  bool? hotAirAtDraftSealObserved,
  List<BurnerUvObservation>? uvObservations,
}) {
  final extended = uvObservations != null;
  final canonical = jsonEncode(<String, dynamic>{
    'operation': burnerConditionRoundOperation,
    'assetClassId': furnace.assetClassId,
    'assetInstanceId': furnace.id,
    'expectedAssetVersion': furnace.version,
    'observations': observations
        .map((item) => item.toCommandMap())
        .toList(growable: false),
    if (extended) ...<String, dynamic>{
      'draftSealRedHotObserved': draftSealRedHotObserved,
      'hotAirAtDraftSealObserved': hotAirAtDraftSealObserved,
      'uvObservations': uvObservations
          .map((item) => item.toCommandMap())
          .toList(growable: false),
    },
    'roundNote': _cleanOptionalText(roundNote),
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}

String? _cleanOptionalText(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
