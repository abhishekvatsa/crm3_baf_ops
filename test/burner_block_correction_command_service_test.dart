import 'dart:convert';

import 'package:crm3_baf_ops/features/assets/services/burner_block_correction_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements OriginBoundWorkflowCommandGateway {
  final List<Object> responses;
  final List<String> envelopes = [];

  _Gateway(this.responses);

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    envelopes.add(envelopeJson);
    final response = responses.removeAt(0);
    if (response is WorkflowException) throw response;
    return response as WorkflowCommandReceipt;
  }
}

class _Receipt implements WorkflowCommandReceipt {
  const _Receipt();

  @override
  String get commandId => 'correction-1';

  @override
  int get aggregateVersion => 1;

  @override
  DateTime get appliedAt => DateTime.utc(2026, 9, 19);

  @override
  Map<String, Object?> get result => const {};

  @override
  String get resultKey => 'burner-block-installation-corrected';
}

void main() {
  test(
    'builds an origin-bound correction command with the backend contract',
    () async {
      final gateway = _Gateway([const _Receipt()]);
      final service = BurnerBlockCorrectionCommandService(
        gateway: gateway,
        currentActorUid: () => 'operator-1',
        replayDelay: Duration.zero,
      );

      await service.correct(
        correctionId: 'correction-1',
        eventId: 'event-1',
        expectedCurrentEventId: 'event-1',
        correctedActionPerformedAt: '2026-09-18T10:00:00.000Z',
        reason: 'The recorded installation date was entered one day late.',
      );

      final envelope =
          jsonDecode(gateway.envelopes.single) as Map<String, dynamic>;
      final command = envelope['command'] as Map<String, dynamic>;
      expect(envelope['originActorUid'], 'operator-1');
      expect(command['commandType'], 'correctBurnerBlockInstallation');
      expect(command['expectedVersion'], 0);
      expect((command['payload'] as Map)['eventId'], 'event-1');
    },
  );
}
