import 'package:crm3_baf_ops/features/quality/services/quality_command_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm3_baf_ops/features/quality/services/monitoring_creation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const requestId = '11111111-1111-4111-8111-111111111111';
  const warningId = 'issue_ticket-1';

  group('durable monitoring creation', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    Future<QualityCommandResult> create(
      QualityCommandService service, {
      String reason = 'Monitor temperature uniformity',
    }) => service.createMonitoringRequest(
      baseNumber: 4,
      grade: 'CRCA',
      cycleReference: 'Cycle 4412',
      chargeNumbers: [12345, 12346],
      reason: reason,
    );

    test(
      'lost response then restarted service reuses IDs; later deliberate create is new',
      () async {
        final requests = <Map<String, dynamic>>[];
        final committed = <String, Map<String, dynamic>>{};
        Future<Map<String, dynamic>> server(
          Map<String, dynamic> request,
        ) async {
          requests.add(Map.of(request));
          final id = request['requestId'] as String;
          final result = committed.putIfAbsent(
            id,
            () => _monitoringResult(
              requestId: id,
              monitoringId: request['monitoringRequestId'] as String,
            ),
          );
          if (requests.length == 1) {
            throw StateError('Response lost after commit');
          }
          return {...result, 'idempotentReplay': requests.length == 2};
        }

        final first = QualityCommandService(
          monitoringScope: () => 'project:si-1',
          transport: server,
        );
        await expectLater(create(first), throwsStateError);
        final restarted = QualityCommandService(
          monitoringScope: () => 'project:si-1',
          transport: server,
        );
        final pending = await restarted.pendingMonitoringCreation();
        expect(pending?['reason'], 'Monitor temperature uniformity');
        await restarted.retryMonitoringCreation();
        expect(requests[1], requests[0]);
        expect(committed.length, 1);
        expect(await restarted.pendingMonitoringCreation(), isNull);
        await create(restarted);
        expect(committed.length, 2);
        expect(requests[2]['requestId'], isNot(requests[0]['requestId']));
        expect(
          requests[2]['monitoringRequestId'],
          isNot(requests[0]['monitoringRequestId']),
        );
      },
    );

    test(
      'malformed receipt retains intent and changed form cannot rotate it',
      () async {
        var sends = 0;
        final service = QualityCommandService(
          monitoringScope: () => 'project:si-1',
          transport: (_) async {
            sends++;
            return {};
          },
        );
        await expectLater(
          create(service),
          throwsA(isA<QualityCommandException>()),
        );
        final pending = await service.pendingMonitoringCreation();
        await expectLater(
          create(service, reason: 'A different request'),
          throwsStateError,
        );
        expect(sends, 1);
        expect(await service.pendingMonitoringCreation(), pending);
      },
    );

    test('persistence failure sends nothing', () async {
      var sends = 0;
      final service = QualityCommandService(
        monitoringScope: () => 'project:si-1',
        monitoringStore: MonitoringCreationStore(
          preferencesLoader: () async => throw StateError('Disk unavailable'),
        ),
        transport: (_) async {
          sends++;
          return {};
        },
      );
      await expectLater(create(service), throwsStateError);
      expect(sends, 0);
    });

    test(
      'simultaneous retries share intent; different accounts and projects do not',
      () async {
        final store = MonitoringCreationStore();
        final payload = <String, dynamic>{
          'baseNumber': 4,
          'grade': 'CRCA',
          'cycleReference': 'Cycle 4412',
          'chargeNumbers': [12345],
          'reason': 'Monitor temperature',
        };
        final attempts = await Future.wait([
          store.prepare('p:si-1', payload),
          MonitoringCreationStore().prepare('p:si-1', payload),
        ]);
        expect(attempts[0], attempts[1]);
        expect(await store.pending('p:si-2'), isNull);
        expect(await store.pending('other:si-1'), isNull);
        await store.complete('p:si-1', 'wrong-receipt');
        expect(await store.pending('p:si-1'), attempts[0]);
      },
    );

    test('invalid input is never persisted or sent', () async {
      final store = MonitoringCreationStore();
      await expectLater(
        store.prepare('p:si-1', {'baseNumber': 4}),
        throwsFormatException,
      );
      expect(await store.pending('p:si-1'), isNull);
    });
  });

  test('accepts complete warning command evidence', () {
    final result = QualityCommandResult.fromMap(
      _warningResult(requestId: requestId),
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.requestWarningClosure,
      expectedEntityId: warningId,
      expectedVersion: 1,
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

  test('accepts and binds the committed linked-abnormality readback', () {
    final payload = _warningResult(requestId: requestId)
      ..['linkedAbnormality'] = _linkedAbnormalityEntity();
    final result = QualityCommandResult.fromMap(
      payload,
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.requestWarningClosure,
      expectedEntityId: warningId,
      expectedVersion: 1,
    );

    expect(result.linkedAbnormality?.firestoreId, 'issue_quality_ticket-1');
    expect(result.linkedAbnormality?.linkedTicketFirestoreId, 'ticket-1');
    expect(result.linkedAbnormality?.sourceChargeNo, 12345);
    expect(result.linkedAbnormality?.isSynced, isTrue);
  });

  test('rejects an RA lifecycle receipt without its canonical case', () {
    final payload = _warningResult(requestId: requestId)
      ..['operation'] = 'DECLARE_QUALITY_CASE_RA_REQUIRED';

    expect(
      () => QualityCommandResult.fromMap(
        payload,
        expectedRequestId: requestId,
        expectedOperation: QualityCommandOperation.declareRaRequired,
        expectedEntityId: warningId,
        expectedVersion: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects a standalone warning receipt without its linked case', () {
    const abnormalityWarningId = 'abnormality_abn-1';
    final payload =
        _warningResult(requestId: requestId)
          ..['entityId'] = abnormalityWarningId
          ..['entity'] = <String, dynamic>{
            ..._warningEntity(requestId: requestId),
            'warningId': abnormalityWarningId,
            'sourceType': 'abnormality',
            'sourceId': 'abn-1',
          };

    expect(
      () => QualityCommandResult.fromMap(
        payload,
        expectedRequestId: requestId,
        expectedOperation: QualityCommandOperation.requestWarningClosure,
        expectedEntityId: abnormalityWarningId,
        expectedVersion: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects a governed issue receipt without its linked case', () {
    final payload = _warningResult(requestId: requestId);
    final entity = Map<String, dynamic>.from(payload['entity']! as Map);
    entity['affectedAssets'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'assetType': 'furnace',
        'assetNumber': 1,
        'assetHierarchyRef': _governedFurnaceReference(),
      },
    ];
    payload['entity'] = entity;

    expect(
      () => QualityCommandResult.fromMap(
        payload,
        expectedRequestId: requestId,
        expectedOperation: QualityCommandOperation.requestWarningClosure,
        expectedEntityId: warningId,
        expectedVersion: 1,
      ),
      throwsFormatException,
    );
  });

  test('accepts complete monitoring command evidence', () {
    const monitoringId = '22222222-2222-4222-8222-222222222222';
    final result = QualityCommandResult.fromMap(
      _monitoringResult(requestId: requestId, monitoringId: monitoringId),
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.createMonitoringRequest,
      expectedEntityId: monitoringId,
      expectedVersion: 0,
    );

    expect(result.entityId, monitoringId);
    expect(result.version, 1);
    expect(result.warning, isNull);
    expect(result.monitoringRequest?.requestId, monitoringId);
  });

  test('accepts server timestamp maps in closed monitoring evidence', () {
    const monitoringId = '22222222-2222-4222-8222-222222222222';
    final payload = _monitoringResult(
      requestId: requestId,
      monitoringId: monitoringId,
    );
    payload
      ..['operation'] = 'CLOSE_QUALITY_MONITORING_REQUEST'
      ..['version'] = 2;
    final entity =
        Map<String, dynamic>.from(payload['entity']! as Map)
          ..['status'] = 'closed'
          ..['visibilityState'] = 'recent'
          ..['visibleUntil'] = _serializedTimestamp(
            DateTime.utc(2026, 8, 21, 12),
          )
          ..['closedAt'] = _serializedTimestamp(DateTime.utc(2026, 8, 14, 12))
          ..['closedByUid'] = 'si-1'
          ..['closedByName'] = 'SI One'
          ..['closeReason'] = 'The monitoring campaign is complete.'
          ..['createdAt'] = _serializedTimestamp(DateTime.utc(2026, 8, 14, 12))
          ..['updatedAt'] = _serializedTimestamp(DateTime.utc(2026, 8, 14, 12))
          ..['version'] = 2;
    payload['entity'] = entity;

    final recent = QualityCommandResult.fromMap(
      payload,
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.closeMonitoringRequest,
      expectedEntityId: monitoringId,
      expectedVersion: 1,
    );
    expect(
      recent.monitoringRequest?.visibleUntil,
      DateTime.utc(2026, 8, 21, 12),
    );

    entity
      ..['visibilityState'] = 'archived'
      ..['visibleUntil'] = null
      ..['archivedAt'] = _serializedTimestamp(DateTime.utc(2026, 8, 21, 12));
    final archived = QualityCommandResult.fromMap(
      payload,
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.closeMonitoringRequest,
      expectedEntityId: monitoringId,
      expectedVersion: 1,
    );
    expect(
      archived.monitoringRequest?.archivedAt,
      DateTime.utc(2026, 8, 21, 12),
    );
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
          expectedVersion: 1,
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects a receipt that did not advance the expected version once', () {
    expect(
      () => QualityCommandResult.fromMap(
        _warningResult(requestId: requestId),
        expectedRequestId: requestId,
        expectedOperation: QualityCommandOperation.requestWarningClosure,
        expectedEntityId: warningId,
        expectedVersion: 2,
      ),
      throwsFormatException,
    );
  });

  test('rejects target evidence from a different commit instant', () {
    final payload = _warningResult(requestId: requestId);
    payload['entity'] = <String, dynamic>{
      ..._warningEntity(requestId: requestId),
      'updatedAt': '2026-08-14T11:59:59.000Z',
    };

    expect(
      () => QualityCommandResult.fromMap(
        payload,
        expectedRequestId: requestId,
        expectedOperation: QualityCommandOperation.requestWarningClosure,
        expectedEntityId: warningId,
        expectedVersion: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects stale linked evidence after an RA mutation', () {
    final payload =
        _warningResult(requestId: requestId)
          ..['operation'] = 'DECLARE_QUALITY_CASE_RA_REQUIRED'
          ..['linkedAbnormality'] = _linkedAbnormalityEntity();
    final linked = Map<String, dynamic>.from(
      payload['linkedAbnormality']! as Map,
    )..['updatedAt'] = '2026-08-14T11:59:59.000Z';
    payload['linkedAbnormality'] = linked;

    expect(
      () => QualityCommandResult.fromMap(
        payload,
        expectedRequestId: requestId,
        expectedOperation: QualityCommandOperation.declareRaRequired,
        expectedEntityId: warningId,
        expectedVersion: 1,
      ),
      throwsFormatException,
    );
  });

  test('closure request accepts unchanged older linked evidence', () {
    final payload = _warningResult(requestId: requestId)
      ..['linkedAbnormality'] = <String, dynamic>{
        ..._linkedAbnormalityEntity(),
        'updatedAt': '2026-08-14T11:59:59.000Z',
      };

    final result = QualityCommandResult.fromMap(
      payload,
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.requestWarningClosure,
      expectedEntityId: warningId,
      expectedVersion: 1,
    );

    expect(
      result.linkedAbnormality?.updatedAt,
      DateTime.utc(2026, 8, 14, 11, 59, 59),
    );
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
      'sourceChargeNo': 12345,
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
        '_seconds': 1786708800,
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

Map<String, dynamic> _linkedAbnormalityEntity() => <String, dynamic>{
  'firestoreId': 'issue_quality_ticket-1',
  'sourceChargeNo': 12345,
  'abnormalityTypeId': 'ATMOSPHERE_DEVIATION',
  'abnormalityTypeTitle': 'Atmosphere deviation',
  'abnormalityTypeCode': 'ATM-DEV',
  'category': 'process',
  'severity': 'high',
  'affectedAssets': <Map<String, dynamic>>[
    <String, dynamic>{'assetType': 'furnace', 'assetNumber': 1},
  ],
  'component': 'Temperature control loop',
  'observedReason': 'Potential coil quality impact',
  'description': 'Created from maintenance issue ticket-1.',
  'possibleRootReasonCategory': 'unknown',
  'possibleRootReasonNotes': null,
  'reannealingStatus': 'required',
  'reannealedToChargeNo': null,
  'loggedAt': <String, dynamic>{'_seconds': 1786694400, '_nanoseconds': 0},
  'updatedAt': <String, dynamic>{'_seconds': 1786708800, '_nanoseconds': 0},
  'loggedByUid': 'operator-1',
  'loggedByName': 'Operator One',
  'updatedByUid': 'operator-1',
  'updatedByName': 'Operator One',
  'linkedTicketFirestoreId': 'ticket-1',
  'linkedExecutionFirestoreId': null,
  'version': 2,
  'isDeleted': false,
  'deletedAt': null,
  'deletedByUid': null,
  'deletedByName': null,
  'deleteReason': null,
};

Map<String, dynamic> _governedFurnaceReference() => <String, dynamic>{
  'schemaVersion': 4,
  'scope': 'componentDefinitionOnAsset',
  'assetClassId': 'furnace-class',
  'assetClassCode': 'FURNACE',
  'assetClassName': 'Furnace',
  'nodeId': 'burner-block',
  'nodeVersion': 2,
  'nodeName': 'Burner block',
  'assetInstanceId': 'furnace-1',
  'assetInstanceVersion': 3,
  'assetNumber': 1,
  'assetInstanceName': 'Furnace 1',
  'componentInstanceId': null,
  'componentInstanceVersion': null,
  'componentTag': null,
  'hierarchyPath': <String>['Furnace', 'Combustion', 'Burner block'],
  'ownershipStatus': 'confirmed',
  'ownerDiscipline': 'Mechanical',
  'accountableRoleKeys': <String>['contractSupervisor'],
  'innerCoverAssociation': null,
};

Map<String, int> _serializedTimestamp(DateTime value) => <String, int>{
  '_seconds': value.toUtc().millisecondsSinceEpoch ~/ 1000,
  '_nanoseconds': value.toUtc().microsecond * 1000,
};
