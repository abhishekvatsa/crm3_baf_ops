import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../data/abnormality_model.dart';

const chargeAbnormalityCallableName = 'mutateChargeAbnormality';
const chargeAbnormalityCallableRegion = 'asia-south1';

enum ChargeAbnormalityMutationOperation {
  update('UPDATE'),
  softDelete('SOFT_DELETE');

  final String wireName;
  const ChargeAbnormalityMutationOperation(this.wireName);
}

class ChargeAbnormalityMutationResult {
  final String requestId;
  final String abnormalityId;
  final ChargeAbnormalityMutationOperation operation;
  final int version;
  final String auditId;
  final DateTime committedAt;
  final bool idempotentReplay;
  final ChargeAbnormality abnormality;

  const ChargeAbnormalityMutationResult({
    required this.requestId,
    required this.abnormalityId,
    required this.operation,
    required this.version,
    required this.auditId,
    required this.committedAt,
    required this.idempotentReplay,
    required this.abnormality,
  });
}

class ChargeAbnormalityMutationException implements Exception {
  final String code;
  final String message;
  final String? reasonCode;
  final Object? details;

  const ChargeAbnormalityMutationException({
    required this.code,
    required this.message,
    this.reasonCode,
    this.details,
  });

  factory ChargeAbnormalityMutationException.fromFirebase(
    FirebaseFunctionsException error,
  ) {
    final details =
        error.details is Map
            ? Map<String, dynamic>.from(error.details as Map)
            : <String, dynamic>{};
    return ChargeAbnormalityMutationException(
      code: error.code,
      message:
          error.message ?? 'Server-governed charge-abnormality change failed.',
      reasonCode: details['reasonCode']?.toString(),
      details: error.details,
    );
  }

  String get operatorMessage {
    switch (code) {
      case 'unauthenticated':
        return 'Sign in again before changing this charge abnormality.';
      case 'permission-denied':
        return 'Only an approved Admin can make this change.';
      case 'not-found':
        return 'This charge abnormality no longer exists. Pull latest data and review it.';
      case 'aborted':
        return 'This record changed on the server. Pull latest data before trying again.';
      case 'failed-precondition':
      case 'invalid-argument':
        return message;
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The governed server could not be reached. Check connectivity and try again.';
      default:
        return message;
    }
  }

  bool get isDurableRejection =>
      code == 'permission-denied' ||
      code == 'not-found' ||
      code == 'failed-precondition' ||
      code == 'invalid-argument' ||
      code == 'aborted' ||
      code == 'data-loss';

  @override
  String toString() => operatorMessage;
}

abstract interface class ChargeAbnormalityCommandTransport {
  Future<Object?> call(Map<String, dynamic> request);
}

class FirebaseChargeAbnormalityCommandTransport
    implements ChargeAbnormalityCommandTransport {
  final FirebaseFunctions? functions;

  const FirebaseChargeAbnormalityCommandTransport({this.functions});

  FirebaseFunctions get _client =>
      functions ??
      FirebaseFunctions.instanceFor(region: chargeAbnormalityCallableRegion);

  @override
  Future<Object?> call(Map<String, dynamic> request) async {
    final response = await _client
        .httpsCallable(chargeAbnormalityCallableName)
        .call<Map<String, dynamic>>(request);
    return response.data;
  }
}

class ChargeAbnormalityCommandService {
  final ChargeAbnormalityCommandTransport _transport;
  final Uuid _uuid;

  ChargeAbnormalityCommandService({
    ChargeAbnormalityCommandTransport? transport,
    Uuid uuid = const Uuid(),
  }) : _transport =
           transport ?? const FirebaseChargeAbnormalityCommandTransport(),
       _uuid = uuid;

  Future<ChargeAbnormalityMutationResult> update({
    required ChargeAbnormality abnormality,
    required int expectedVersion,
    String reason = 'Updated charge abnormality',
    String? requestId,
  }) {
    return _execute(
      abnormality: abnormality,
      operation: ChargeAbnormalityMutationOperation.update,
      expectedVersion: expectedVersion,
      reason: reason,
      requestId: requestId,
    );
  }

  Future<ChargeAbnormalityMutationResult> softDelete({
    required ChargeAbnormality abnormality,
    required int expectedVersion,
    required String reason,
    String? requestId,
  }) {
    return _execute(
      abnormality: abnormality,
      operation: ChargeAbnormalityMutationOperation.softDelete,
      expectedVersion: expectedVersion,
      reason: reason,
      requestId: requestId,
    );
  }

  String deterministicSyncRequestId({
    required ChargeAbnormalityMutationOperation operation,
    required String abnormalityId,
    required int localVersion,
  }) {
    final source =
        'crm3-charge-abnormality-v1:${operation.wireName}:'
        '$abnormalityId:$localVersion';
    final bytes = sha256.convert(utf8.encode(source)).bytes.toList();
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes
            .take(16)
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  Future<ChargeAbnormalityMutationResult> _execute({
    required ChargeAbnormality abnormality,
    required ChargeAbnormalityMutationOperation operation,
    required int expectedVersion,
    required String reason,
    String? requestId,
  }) async {
    final abnormalityId = abnormality.firestoreId?.trim();
    if (abnormalityId == null ||
        abnormalityId.isEmpty ||
        abnormalityId.contains('/')) {
      throw const ChargeAbnormalityMutationException(
        code: 'invalid-argument',
        message: 'The charge abnormality has no valid server identity.',
        reasonCode: 'invalid-abnormality-id',
      );
    }
    if (expectedVersion <= 0) {
      throw const ChargeAbnormalityMutationException(
        code: 'invalid-argument',
        message: 'The charge abnormality has no valid source version.',
        reasonCode: 'invalid-expected-version',
      );
    }
    final cleanReason = _governedReason(reason);
    final effectiveRequestId = requestId?.trim() ?? _uuid.v4();
    final payload = <String, dynamic>{
      'requestId': effectiveRequestId,
      'abnormalityId': abnormalityId,
      'operation': operation.wireName,
      'expectedVersion': expectedVersion,
      'reason': cleanReason,
      if (operation == ChargeAbnormalityMutationOperation.update) ...{
        'abnormalityTypeId': abnormality.abnormalityTypeId,
        'severity': abnormality.severity.name,
        'affectedAssets': abnormality.affectedAssets
            .map((asset) => asset.toMap())
            .toList(growable: false),
        'component': _cleanOptional(abnormality.component),
        'observedReason': abnormality.observedReason.trim(),
        'description': _cleanOptional(abnormality.description),
        'possibleRootReasonCategory':
            abnormality.possibleRootReasonCategory.name,
        'possibleRootReasonNotes': _cleanOptional(
          abnormality.possibleRootReasonNotes,
        ),
        'reannealingStatus': abnormality.reannealingStatus.name,
        'reannealedToChargeNo': abnormality.reannealedToChargeNo,
      },
    };

    try {
      final raw = await _transport.call(payload);
      return _parseResult(
        raw,
        expectedRequestId: effectiveRequestId,
        expectedAbnormalityId: abnormalityId,
        expectedOperation: operation,
      );
    } on FirebaseFunctionsException catch (error) {
      throw ChargeAbnormalityMutationException.fromFirebase(error);
    } on ChargeAbnormalityMutationException {
      rethrow;
    } catch (error) {
      throw ChargeAbnormalityMutationException(
        code: 'internal',
        message: 'The governed abnormality response could not be verified.',
        reasonCode: 'abnormality-response-invalid',
        details: error,
      );
    }
  }

  ChargeAbnormalityMutationResult _parseResult(
    Object? raw, {
    required String expectedRequestId,
    required String expectedAbnormalityId,
    required ChargeAbnormalityMutationOperation expectedOperation,
  }) {
    if (raw is! Map || raw['ok'] != true) {
      throw const ChargeAbnormalityMutationException(
        code: 'internal',
        message: 'The governed abnormality response was malformed.',
        reasonCode: 'abnormality-response-invalid',
      );
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['requestId'] != expectedRequestId ||
        data['abnormalityId'] != expectedAbnormalityId ||
        data['operation'] != expectedOperation.wireName) {
      throw const ChargeAbnormalityMutationException(
        code: 'internal',
        message: 'The governed abnormality response identity did not match.',
        reasonCode: 'abnormality-response-identity-mismatch',
      );
    }
    final version = data['version'];
    final auditId = data['auditId'];
    final committedAt = DateTime.tryParse(
      data['committedAt']?.toString() ?? '',
    );
    final abnormalityRaw = data['abnormality'];
    if (version is! int ||
        version <= 0 ||
        auditId is! String ||
        auditId != 'server_charge_abnormality_$expectedRequestId' ||
        committedAt == null ||
        data['idempotentReplay'] is! bool ||
        abnormalityRaw is! Map) {
      throw const ChargeAbnormalityMutationException(
        code: 'internal',
        message: 'The governed abnormality response evidence was malformed.',
        reasonCode: 'abnormality-response-invalid',
      );
    }
    final abnormalityData = Map<String, dynamic>.from(abnormalityRaw);
    if (abnormalityData['firestoreId'] != expectedAbnormalityId ||
        abnormalityData['version'] != version ||
        abnormalityData['updatedAt'] is! String ||
        abnormalityData['updatedByUid'] is! String ||
        abnormalityData['isDeleted'] is! bool) {
      throw const ChargeAbnormalityMutationException(
        code: 'internal',
        message: 'The governed abnormality document was malformed.',
        reasonCode: 'abnormality-response-document-invalid',
      );
    }
    final abnormality = ChargeAbnormality.fromMap(
      abnormalityData,
      expectedAbnormalityId,
    );
    if (abnormality.version != version ||
        abnormality.firestoreId != expectedAbnormalityId ||
        (expectedOperation == ChargeAbnormalityMutationOperation.softDelete &&
            !abnormality.isDeleted)) {
      throw const ChargeAbnormalityMutationException(
        code: 'internal',
        message:
            'The governed abnormality document did not match its evidence.',
        reasonCode: 'abnormality-response-document-mismatch',
      );
    }

    return ChargeAbnormalityMutationResult(
      requestId: expectedRequestId,
      abnormalityId: expectedAbnormalityId,
      operation: expectedOperation,
      version: version,
      auditId: auditId,
      committedAt: committedAt,
      idempotentReplay: data['idempotentReplay'] as bool,
      abnormality: abnormality,
    );
  }
}

String _governedReason(String value) {
  var cleaned = value.trim();
  if (cleaned.isEmpty) {
    cleaned = 'Charge abnormality admin mutation';
  } else if (cleaned.length < 8) {
    cleaned = 'Reason: $cleaned';
  }
  if (cleaned.length > 500) {
    throw const ChargeAbnormalityMutationException(
      code: 'invalid-argument',
      message: 'The mutation reason must not exceed 500 characters.',
      reasonCode: 'abnormality-reason-too-long',
    );
  }
  return cleaned;
}

String? _cleanOptional(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
