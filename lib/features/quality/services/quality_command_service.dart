import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../data/quality_warning.dart';

const qualityCommandCallableName = 'mutateChargeAbnormality';
const qualityCommandCallableRegion = 'asia-south1';

enum QualityCommandOperation {
  requestWarningClosure('REQUEST_QUALITY_WARNING_CLOSURE'),
  declareRaRequired('DECLARE_QUALITY_CASE_RA_REQUIRED'),
  closeWarning('CLOSE_QUALITY_WARNING'),
  reopenWarning('REOPEN_QUALITY_WARNING'),
  createMonitoringRequest('CREATE_QUALITY_MONITORING_REQUEST'),
  closeMonitoringRequest('CLOSE_QUALITY_MONITORING_REQUEST');

  const QualityCommandOperation(this.wireName);

  final String wireName;

  bool get targetsWarning =>
      this == requestWarningClosure ||
      this == declareRaRequired ||
      this == closeWarning ||
      this == reopenWarning;
}

class QualityCommandException implements Exception {
  const QualityCommandException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class QualityCommandResult {
  const QualityCommandResult({
    required this.requestId,
    required this.operation,
    required this.entityId,
    required this.version,
    required this.auditId,
    required this.committedAt,
    required this.idempotentReplay,
    this.warning,
    this.monitoringRequest,
  });

  final String requestId;
  final QualityCommandOperation operation;
  final String entityId;
  final int version;
  final String auditId;
  final DateTime committedAt;
  final bool idempotentReplay;
  final QualityWarning? warning;
  final QualityMonitoringRequest? monitoringRequest;

  factory QualityCommandResult.fromMap(
    Map<String, dynamic> map, {
    required String expectedRequestId,
    required QualityCommandOperation expectedOperation,
    required String expectedEntityId,
  }) {
    final source = '$qualityCommandCallableName/$expectedRequestId';
    if (map['ok'] != true) {
      throw PersistedDataFormatException(
        field: 'ok',
        source: source,
        detail: 'expected an explicit successful result',
      );
    }
    final returnedRequestId = readRequiredPersistedString(
      map['requestId'],
      field: 'requestId',
      source: source,
    );
    if (returnedRequestId != expectedRequestId) {
      throw PersistedDataFormatException(
        field: 'requestId',
        source: source,
        detail: 'response identity mismatch',
      );
    }
    final returnedOperation = readRequiredPersistedString(
      map['operation'],
      field: 'operation',
      source: source,
    );
    if (returnedOperation != expectedOperation.wireName) {
      throw PersistedDataFormatException(
        field: 'operation',
        source: source,
        detail: 'response operation mismatch',
      );
    }
    final entityId = readRequiredPersistedString(
      map['entityId'],
      field: 'entityId',
      source: source,
    );
    if (entityId != expectedEntityId) {
      throw PersistedDataFormatException(
        field: 'entityId',
        source: source,
        detail: 'response entity mismatch',
      );
    }
    final version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    );
    final auditId = readRequiredPersistedString(
      map['auditId'],
      field: 'auditId',
      source: source,
    );
    if (auditId != 'server_quality_$expectedRequestId') {
      throw PersistedDataFormatException(
        field: 'auditId',
        source: source,
        detail: 'response audit identity mismatch',
      );
    }
    final committedAtRaw = map['committedAt'];
    final committedAt = readRequiredPersistedDateTime(
      map['committedAt'],
      field: 'committedAt',
      source: source,
    );
    if (committedAtRaw is! String ||
        committedAtRaw.trim() != committedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'committedAt',
        source: source,
        detail: 'must be a canonical UTC ISO instant',
      );
    }
    final entityRaw = map['entity'];
    if (entityRaw is! Map) {
      throw PersistedDataFormatException(
        field: 'entity',
        source: source,
        detail: 'expected a quality entity map',
      );
    }
    final entity = _normaliseQualityEntity(
      Map<String, dynamic>.from(entityRaw),
      source: '$source/entity',
    );
    final lastMutationId = readRequiredPersistedString(
      entity['lastMutationId'],
      field: 'entity.lastMutationId',
      source: source,
    );
    if (lastMutationId != expectedRequestId) {
      throw PersistedDataFormatException(
        field: 'entity.lastMutationId',
        source: source,
        detail: 'returned entity is not bound to this mutation',
      );
    }
    final QualityWarning? warning;
    final QualityMonitoringRequest? monitoringRequest;
    if (expectedOperation.targetsWarning) {
      warning = QualityWarning.fromMap(entity, entityId);
      monitoringRequest = null;
      if (warning.version != version) {
        throw PersistedDataFormatException(
          field: 'entity.version',
          source: source,
          detail: 'returned warning version does not match result evidence',
        );
      }
    } else {
      warning = null;
      monitoringRequest = QualityMonitoringRequest.fromMap(entity, entityId);
      if (monitoringRequest.version != version) {
        throw PersistedDataFormatException(
          field: 'entity.version',
          source: source,
          detail: 'returned monitoring version does not match result evidence',
        );
      }
    }
    return QualityCommandResult(
      requestId: returnedRequestId,
      operation: expectedOperation,
      entityId: entityId,
      version: version,
      auditId: auditId,
      committedAt: committedAt,
      idempotentReplay: readRequiredPersistedBool(
        map['idempotentReplay'],
        field: 'idempotentReplay',
        source: source,
      ),
      warning: warning,
      monitoringRequest: monitoringRequest,
    );
  }
}

class QualityCommandService {
  QualityCommandService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;
  static const _uuid = Uuid();

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: qualityCommandCallableRegion);

  Future<QualityCommandResult> requestWarningClosure({
    required QualityWarning warning,
    required String reason,
  }) => _call(QualityCommandOperation.requestWarningClosure, <String, dynamic>{
    'warningId': warning.warningId,
    'expectedVersion': warning.version,
    'reason': reason,
  });

  Future<QualityCommandResult> closeWarning({
    required QualityWarning warning,
    required QualityWarningClosureDisposition disposition,
    required String reason,
    List<int> linkedReannealingChargeNos = const <int>[],
  }) => _call(QualityCommandOperation.closeWarning, <String, dynamic>{
    'warningId': warning.warningId,
    'expectedVersion': warning.version,
    'reason': reason,
    'disposition': disposition.name,
    'linkedReannealingChargeNos': linkedReannealingChargeNos,
  });

  Future<QualityCommandResult> declareRaRequired({
    required QualityWarning warning,
    required String reason,
  }) => _call(QualityCommandOperation.declareRaRequired, <String, dynamic>{
    'warningId': warning.warningId,
    'expectedVersion': warning.version,
    'reason': reason,
  });

  Future<QualityCommandResult> reopenWarning({
    required QualityWarning warning,
    required String reason,
  }) => _call(QualityCommandOperation.reopenWarning, <String, dynamic>{
    'warningId': warning.warningId,
    'expectedVersion': warning.version,
    'reason': reason,
  });

  Future<QualityCommandResult> createMonitoringRequest({
    required int baseNumber,
    required String grade,
    required String cycleReference,
    required List<int> chargeNumbers,
    required String reason,
  }) {
    final monitoringId = _uuid.v4();
    return _call(
      QualityCommandOperation.createMonitoringRequest,
      <String, dynamic>{
        'monitoringRequestId': monitoringId,
        'expectedVersion': 0,
        'reason': reason,
        'baseNumber': baseNumber,
        'grade': grade,
        'cycleReference': cycleReference,
        'chargeNumbers': chargeNumbers,
      },
    );
  }

  Future<QualityCommandResult> closeMonitoringRequest({
    required QualityMonitoringRequest request,
    required String reason,
  }) => _call(QualityCommandOperation.closeMonitoringRequest, <String, dynamic>{
    'monitoringRequestId': request.requestId,
    'expectedVersion': request.version,
    'reason': reason,
  });

  Future<QualityCommandResult> _call(
    QualityCommandOperation operation,
    Map<String, dynamic> payload,
  ) async {
    final requestId = _uuid.v4();
    final expectedEntityId =
        (payload['warningId'] ?? payload['monitoringRequestId']) as String;
    final request = <String, dynamic>{
      'requestId': requestId,
      'operation': operation.wireName,
      ...payload,
    };
    try {
      final result = await _client
          .httpsCallable(qualityCommandCallableName)
          .call<Map<String, dynamic>>(request);
      return QualityCommandResult.fromMap(
        result.data,
        expectedRequestId: requestId,
        expectedOperation: operation,
        expectedEntityId: expectedEntityId,
      );
    } on FirebaseFunctionsException catch (error) {
      throw QualityCommandException(_friendlyMessage(error), code: error.code);
    } on FormatException catch (error) {
      throw QualityCommandException(
        'The quality service returned invalid evidence: $error',
        code: 'data-loss',
      );
    }
  }

  String _friendlyMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Your current role cannot perform this quality decision.';
      case 'failed-precondition':
        return error.message ??
            'The quality record is not ready for this action.';
      case 'aborted':
        return 'The record changed. Refresh it before trying again.';
      case 'not-found':
        return 'The quality record is no longer available.';
      case 'resource-exhausted':
        return 'Quality commands are temporarily rate limited.';
      default:
        return error.message ?? 'The quality command could not be completed.';
    }
  }
}

Map<String, dynamic> _normaliseQualityEntity(
  Map<String, dynamic> data, {
  required String source,
}) {
  final result = Map<String, dynamic>.from(data);
  result['createdAt'] = readRequiredPersistedDateTime(
    data['createdAt'],
    field: 'createdAt',
    source: source,
    allowSerializedTimestampMap: true,
  );
  result['updatedAt'] = readRequiredPersistedDateTime(
    data['updatedAt'],
    field: 'updatedAt',
    source: source,
    allowSerializedTimestampMap: true,
  );
  result['closureRequestedAt'] = readOptionalPersistedDateTime(
    data['closureRequestedAt'],
    field: 'closureRequestedAt',
    source: source,
    allowSerializedTimestampMap: true,
  );
  result['closedAt'] = readOptionalPersistedDateTime(
    data['closedAt'],
    field: 'closedAt',
    source: source,
    allowSerializedTimestampMap: true,
  );
  return result;
}
