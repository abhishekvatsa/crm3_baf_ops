import 'dart:io';

import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/charge_abnormality_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements ChargeAbnormalityCommandTransport {
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  Object? response;

  _FakeTransport(this.response);

  @override
  Future<Object?> call(Map<String, dynamic> request) async {
    requests.add(Map<String, dynamic>.from(request));
    return response;
  }
}

ChargeAbnormality _record({int version = 4}) {
  return ChargeAbnormality()
    ..firestoreId = 'abn-1'
    ..sourceChargeNo = 12001
    ..abnormalityTypeId = 'TYPE_NEW'
    ..abnormalityTypeTitle = 'Client title is not authoritative'
    ..abnormalityTypeCode = 'CLIENT-CODE'
    ..category = AbnormalityCategory.equipment
    ..severity = AbnormalitySeverity.critical
    ..affectedAssets = const <AffectedAssetRef>[
      AffectedAssetRef(assetType: AssetType.furnace, assetNumber: 7),
    ]
    ..component = 'Burner assembly'
    ..observedReason = 'Governed corrected observation'
    ..description = 'Detailed correction'
    ..possibleRootReasonCategory = RootReasonCategory.furnaceRelated
    ..possibleRootReasonNotes = 'Inspection confirmed the source'
    ..reannealingStatus = ReannealingStatus.completed
    ..reannealedToChargeNo = 12002
    ..loggedAt = DateTime.parse('2026-07-20T08:00:00.000Z')
    ..updatedAt = DateTime.parse('2026-07-20T08:00:00.000Z')
    ..loggedByUid = 'operator-1'
    ..loggedByName = 'Operator One'
    ..updatedByUid = 'operator-1'
    ..updatedByName = 'Operator One'
    ..linkedTicketFirestoreId = null
    ..linkedExecutionFirestoreId = null
    ..version = version
    ..isSynced = true
    ..isDeleted = false;
}

Map<String, dynamic> _response({
  required String requestId,
  required ChargeAbnormalityMutationOperation operation,
  int version = 5,
}) {
  final remote =
      _record(version: version)
        ..abnormalityTypeTitle = 'Canonical server title'
        ..abnormalityTypeCode = 'NEW-CODE'
        ..category = AbnormalityCategory.process
        ..updatedAt = DateTime.parse('2026-07-26T10:00:00.000Z')
        ..updatedByUid = 'admin-1'
        ..updatedByName = 'Admin One';
  if (operation == ChargeAbnormalityMutationOperation.softDelete) {
    remote
      ..isDeleted = true
      ..deletedAt = DateTime.parse('2026-07-26T10:00:00.000Z')
      ..deletedByUid = 'admin-1'
      ..deletedByName = 'Admin One'
      ..deleteReason = 'Reason: dup';
  }
  return <String, dynamic>{
    'ok': true,
    'requestId': requestId,
    'abnormalityId': 'abn-1',
    'operation': operation.wireName,
    'version': version,
    'auditId': 'server_charge_abnormality_$requestId',
    'committedAt': '2026-07-26T10:00:00.000Z',
    'idempotentReplay': false,
    'abnormality': remote.toMap(),
  };
}

void main() {
  const requestId = '11111111-1111-4111-8111-111111111111';

  test(
    'update sends only mutable business fields and verifies evidence',
    () async {
      final transport = _FakeTransport(
        _response(
          requestId: requestId,
          operation: ChargeAbnormalityMutationOperation.update,
        ),
      );
      final service = ChargeAbnormalityCommandService(transport: transport);

      final result = await service.update(
        abnormality: _record(),
        expectedVersion: 4,
        reason: 'Corrected after Admin review',
        requestId: requestId,
      );

      expect(result.version, 5);
      expect(result.abnormality.abnormalityTypeTitle, 'Canonical server title');
      expect(result.abnormality.abnormalityTypeCode, 'NEW-CODE');
      expect(result.abnormality.category, AbnormalityCategory.process);
      expect(result.auditId, 'server_charge_abnormality_$requestId');
      final payload = transport.requests.single;
      expect(payload['operation'], 'UPDATE');
      expect(payload['expectedVersion'], 4);
      expect(payload['abnormalityTypeId'], 'TYPE_NEW');
      expect(payload['affectedAssets'], <Map<String, dynamic>>[
        <String, dynamic>{'assetType': 'furnace', 'assetNumber': 7},
      ]);
      expect(payload.containsKey('sourceChargeNo'), isFalse);
      expect(payload.containsKey('loggedAt'), isFalse);
      expect(payload.containsKey('loggedByUid'), isFalse);
      expect(payload.containsKey('version'), isFalse);
      expect(payload.containsKey('isDeleted'), isFalse);
    },
  );

  test('short delete reason is normalized and tombstone is verified', () async {
    final transport = _FakeTransport(
      _response(
        requestId: requestId,
        operation: ChargeAbnormalityMutationOperation.softDelete,
      ),
    );
    final service = ChargeAbnormalityCommandService(transport: transport);

    final result = await service.softDelete(
      abnormality: _record(),
      expectedVersion: 4,
      reason: 'dup',
      requestId: requestId,
    );

    expect(transport.requests.single['reason'], 'Reason: dup');
    expect(transport.requests.single.keys, <String>[
      'requestId',
      'abnormalityId',
      'operation',
      'expectedVersion',
      'reason',
    ]);
    expect(result.abnormality.isDeleted, isTrue);
  });

  test(
    'non-string or non-canonical committedAt evidence fails closed',
    () async {
      for (final invalid in <Object>[20260726, '2026-07-26T10:00:00Z']) {
        final response = _response(
          requestId: requestId,
          operation: ChargeAbnormalityMutationOperation.update,
        )..['committedAt'] = invalid;
        final service = ChargeAbnormalityCommandService(
          transport: _FakeTransport(response),
        );

        await expectLater(
          service.update(
            abnormality: _record(),
            expectedVersion: 4,
            reason: 'Corrected after Admin review',
            requestId: requestId,
          ),
          throwsA(
            isA<ChargeAbnormalityMutationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'abnormality-response-invalid',
            ),
          ),
        );
      }
    },
  );

  test('deterministic sync IDs are stable and operation-bound', () {
    final service = ChargeAbnormalityCommandService(
      transport: _FakeTransport(null),
    );

    final first = service.deterministicSyncRequestId(
      operation: ChargeAbnormalityMutationOperation.update,
      abnormalityId: 'abn-1',
      localVersion: 5,
    );
    final second = service.deterministicSyncRequestId(
      operation: ChargeAbnormalityMutationOperation.update,
      abnormalityId: 'abn-1',
      localVersion: 5,
    );
    final deleted = service.deterministicSyncRequestId(
      operation: ChargeAbnormalityMutationOperation.softDelete,
      abnormalityId: 'abn-1',
      localVersion: 5,
    );

    expect(first, second);
    expect(first, isNot(deleted));
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('response identity mismatch fails closed', () async {
    final response = _response(
      requestId: requestId,
      operation: ChargeAbnormalityMutationOperation.update,
    )..['abnormalityId'] = 'other';
    final service = ChargeAbnormalityCommandService(
      transport: _FakeTransport(response),
    );

    await expectLater(
      service.update(
        abnormality: _record(),
        expectedVersion: 4,
        requestId: requestId,
      ),
      throwsA(
        isA<ChargeAbnormalityMutationException>().having(
          (error) => error.reasonCode,
          'reasonCode',
          'abnormality-response-identity-mismatch',
        ),
      ),
    );
  });

  test(
    'source contract routes admin mutations only through governed callable',
    () {
      final screen =
          File(
            'lib/features/abnormalities/presentation/'
            'charge_abnormalities_screen.dart',
          ).readAsStringSync();
      final sync =
          File(
            'lib/core/services/sync_service.directives_abnormalities.dart',
          ).readAsStringSync();
      final rules = File('firestore.rules').readAsStringSync();
      final functions = File('functions/src/index.ts').readAsStringSync();

      expect(screen, contains('chargeAbnormalityCommandServiceProvider'));
      expect(screen, isNot(contains('repository.updateAbnormality(')));
      expect(screen, isNot(contains('repository.softDeleteAbnormality(')));
      expect(sync, contains('_pushGovernedChargeAbnormalityMutation('));
      expect(sync, contains('deterministicSyncRequestId('));
      expect(
        rules,
        contains('match /charge_abnormality_mutation_receipts/{docId}'),
      );
      expect(
        rules,
        contains("!docId.matches('^server_charge_abnormality_.*')"),
      );
      expect(functions, contains('export const mutateChargeAbnormality'));
      expect(
        functions,
        contains('isQualityMutationOperation(request.data?.operation) ?'),
      );
      expect(
        functions,
        contains('userCanMutateQuality(userData, request.data.operation)'),
      );
      expect(functions, contains('userCanMutateChargeAbnormality(userData)'));
    },
  );
}
