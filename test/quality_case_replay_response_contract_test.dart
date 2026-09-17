import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/charge_abnormality_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/services/quality_command_service.dart';
import 'package:flutter_test/flutter_test.dart';

// The fixtures are the exact wire responses the backend returns when a retry
// recovers an accepted decision after later governed work. They are produced
// and re-verified by functions/test/qualityCaseReplayResponseFixtures.test.js.
Map<String, dynamic> _fixture(String name) {
  final file = File('functions/test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

class _FakeTransport implements ChargeAbnormalityCommandTransport {
  _FakeTransport(this.response);

  final Object? response;
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];

  @override
  Future<Object?> call(Map<String, dynamic> request) async {
    requests.add(Map<String, dynamic>.from(request));
    return response;
  }
}

ChargeAbnormality _record() {
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
    ..observedReason = 'Revised observation'
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
    ..version = 4
    ..isSynced = true
    ..isDeleted = false;
}

void main() {
  test('a recovered quality decision decodes through the shipped client', () {
    const requestId = '22222222-2222-4222-8222-222222222222';

    final result = QualityCommandResult.fromMap(
      _fixture('quality_decision_replay_response.json'),
      expectedRequestId: requestId,
      expectedOperation: QualityCommandOperation.closeWarning,
      expectedEntityId: 'abnormality_abn-1',
      expectedVersion: 1,
    );

    expect(result.idempotentReplay, isTrue);
    expect(result.version, 2);
    expect(result.warning?.status, QualityWarningStatus.closed);
    expect(
      result.warning?.closureDisposition,
      QualityWarningClosureDisposition.coilFoundAcceptable,
    );
    expect(result.linkedAbnormality?.firestoreId, 'abn-1');
    expect(
      result.linkedAbnormality?.reannealingStatus,
      ReannealingStatus.notRequired,
    );
  });

  test(
    'a recovered abnormality correction decodes through the shipped client',
    () async {
      final transport = _FakeTransport(
        _fixture('abnormality_replay_response.json'),
      );
      final service = ChargeAbnormalityCommandService(transport: transport);

      final result = await service.update(
        abnormality: _record(),
        expectedVersion: 4,
        reason: 'Corrected after Admin review',
        requestId: '11111111-1111-4111-8111-111111111111',
      );

      expect(result.idempotentReplay, isTrue);
      expect(result.version, 5);
      expect(result.abnormality.observedReason, 'Revised observation');
      expect(result.abnormality.version, 5);
    },
  );
}
