import 'package:crm3_baf_ops/features/quality/services/quality_command_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const requestId = '11111111-1111-4111-8111-111111111111';
  const warningId = 'issue_ticket-1';

  test('accepts complete warning command evidence', () {
    final result = QualityCommandResult.fromMap(
      _warningResult(requestId: requestId),
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.requestWarningClosure,
      expectedEntityId: warningId,
    );

    expect(result.operation, QualityCommandOperation.requestWarningClosure);
    expect(result.entityId, warningId);
    expect(result.version, 2);
    expect(result.auditId, 'server_quality_$requestId');
    expect(result.committedAt, DateTime.utc(2026, 8, 14, 12));
    expect(result.idempotentReplay, isFalse);
    expect(result.warning?.warningId, warningId);
    expect(result.monitoringRequest, isNull);
  });

  test('accepts complete monitoring command evidence', () {
    const monitoringId = '22222222-2222-4222-8222-222222222222';
    final result = QualityCommandResult.fromMap(
      _monitoringResult(requestId: requestId, monitoringId: monitoringId),
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.createMonitoringRequest,
      expectedEntityId: monitoringId,
    );

    expect(result.entityId, monitoringId);
    expect(result.version, 1);
    expect(result.warning, isNull);
    expect(result.monitoringRequest?.requestId, monitoringId);
  });

  test('rejects mismatched receipt and entity evidence', () {
    final cases = <Map<String, dynamic>>[
      <String, dynamic>{..._warningResult(requestId: requestId), 'ok': false},
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'requestId': '22222222-2222-4222-8222-222222222222',
      },
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'operation': 'CLOSE_QUALITY_WARNING',
      },
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'entityId': 'issue_ticket-2',
      },
      <String, dynamic>{..._warningResult(requestId: requestId), 'version': 3},
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'auditId': 'server_quality_other',
      },
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'committedAt': '2026-08-14T12:00:00Z',
      },
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'idempotentReplay': 0,
      },
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'entity': <String, dynamic>{
          ..._warningEntity(requestId: requestId),
          'lastMutationId': '22222222-2222-4222-8222-222222222222',
        },
      },
      <String, dynamic>{
        ..._warningResult(requestId: requestId),
        'entity': <String, dynamic>{
          ..._warningEntity(requestId: requestId),
          'warningId': 'issue_ticket-2',
        },
      },
    ];

    for (final value in cases) {
      expect(
        () => QualityCommandResult.fromMap(
          value,
          expectedRequestId: requestId,
          expectedOperation: QualityCommandOperation.requestWarningClosure,
          expectedEntityId: warningId,
        ),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _warningResult({required String requestId}) =>
    <String, dynamic>{
      'ok': true,
      'requestId': requestId,
      'operation': 'REQUEST_QUALITY_WARNING_CLOSURE',
      'entityId': 'issue_ticket-1',
      'version': 2,
      'auditId': 'server_quality_$requestId',
      'committedAt': '2026-08-14T12:00:00.000Z',
      'idempotentReplay': false,
      'entity': _warningEntity(requestId: requestId),
    };

Map<String, dynamic> _warningEntity({required String requestId}) =>
    <String, dynamic>{
      'schemaVersion': 1,
      'warningId': 'issue_ticket-1',
      'sourceType': 'issue',
      'sourceId': 'ticket-1',
      'sourceVersion': 1,
      'sourceChargeNo': 123,
      'sourceSummary': 'Furnace temperature excursion',
      'sourceSeverity': 'high',
      'warningReason': 'Potential coil quality impact',
      'affectedAssets': <Map<String, dynamic>>[
        <String, dynamic>{'assetType': 'furnace', 'assetNumber': 1},
      ],
      'component': 'Temperature control loop',
      'status': 'closureRequested',
      'closureRequestReason': 'Coils inspected and acceptable',
      'closureRequestedAt': <String, dynamic>{
        '_seconds': 1776168000,
        '_nanoseconds': 0,
      },
      'closureRequestedByUid': 'operator-1',
      'closureRequestedByName': 'Operator One',
      'closedAt': null,
      'closedByUid': null,
      'closedByName': null,
      'closureDisposition': null,
      'linkedReannealingChargeNos': <int>[],
      'decisionReason': null,
      'createdAt': '2026-08-14T08:00:00.000Z',
      'createdByUid': 'operator-1',
      'createdByName': 'Operator One',
      'updatedAt': '2026-08-14T12:00:00.000Z',
      'updatedByUid': 'operator-1',
      'updatedByName': 'Operator One',
      'version': 2,
      'lastMutationId': requestId,
    };

Map<String, dynamic> _monitoringResult({
  required String requestId,
  required String monitoringId,
}) => <String, dynamic>{
  'ok': true,
  'requestId': requestId,
  'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
  'entityId': monitoringId,
  'version': 1,
  'auditId': 'server_quality_$requestId',
  'committedAt': '2026-08-14T12:00:00.000Z',
  'idempotentReplay': false,
  'entity': <String, dynamic>{
    'schemaVersion': 2,
    'requestId': monitoringId,
    'baseNumber': 4,
    'grade': 'CRCA',
    'cycleReference': 'Cycle 4412',
    'chargeNumbers': <int>[12345, 12346],
    'reason': 'Monitor temperature uniformity',
    'status': 'active',
    'visibilityState': 'active',
    'visibleUntil': null,
    'archivedAt': null,
    'createdAt': '2026-08-14T12:00:00.000Z',
    'createdByUid': 'si-1',
    'createdByName': 'SI One',
    'closedAt': null,
    'closedByUid': null,
    'closedByName': null,
    'closeReason': null,
    'updatedAt': '2026-08-14T12:00:00.000Z',
    'updatedByUid': 'si-1',
    'updatedByName': 'SI One',
    'version': 1,
    'lastMutationId': requestId,
  },
};
