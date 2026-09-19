import 'dart:convert';

import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';

/// Operator-facing command boundary for correcting a recorded Burner Block
/// installation time. The original event is never edited or recreated.
class BurnerBlockCorrectionCommandService {
  const BurnerBlockCorrectionCommandService({
    required this.gateway,
    required this.currentActorUid,
    this.replayDelay = const Duration(milliseconds: 250),
  });

  final OriginBoundWorkflowCommandGateway gateway;
  final String Function() currentActorUid;
  final Duration replayDelay;

  Future<WorkflowCommandReceipt> correct({
    required String correctionId,
    required String eventId,
    required String expectedCurrentEventId,
    required String correctedActionPerformedAt,
    required String reason,
    String? supersedesCorrectionId,
  }) async {
    final originActorUid = currentActorUid().trim();
    if (originActorUid.isEmpty) {
      throw const WorkflowException(
        WorkflowErrorCode.unauthenticated,
        'Sign in before correcting a Burner Block installation record.',
      );
    }
    final command = WorkflowCommandFactory.create(
      type: WorkflowCommandType.correctBurnerBlockInstallation,
      aggregateId: correctionId,
      expectedVersion: 0,
      payload: {
        'eventId': eventId,
        'expectedCurrentEventId': expectedCurrentEventId,
        'correctedActionPerformedAt': correctedActionPerformedAt,
        'reason': reason,
        'supersedesCorrectionId': supersedesCorrectionId,
      },
    );
    final envelope = jsonEncode({
      'protocolVersion': 2,
      'originActorUid': originActorUid,
      'command': command.toMap(),
    });
    try {
      return await gateway.executeOriginBoundEnvelope(envelope);
    } on WorkflowException catch (error) {
      if (!_uncertain(error)) rethrow;
      if (replayDelay > Duration.zero) await Future<void>.delayed(replayDelay);
      return gateway.executeOriginBoundEnvelope(envelope);
    }
  }

  bool _uncertain(WorkflowException error) =>
      error.code == WorkflowErrorCode.unavailable ||
      error.code == WorkflowErrorCode.deadlineExceeded ||
      error.code == WorkflowErrorCode.aborted;
}
