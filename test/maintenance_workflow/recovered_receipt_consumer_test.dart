import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_command_reconciler.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/test_support/recording_workflow_repository.dart';

/// When an earlier attempt is found to have been accepted, the executor
/// returns that stored receipt instead of the losing attempt's transport
/// error. The callers do not merely display it: they validate it against the
/// command they issued, reading `ticketId`, `auditId` and lane evidence out of
/// `result`.
///
/// An earlier revision rebuilt that receipt with an empty result, on the
/// mistaken belief that nothing read it. The executor's own tests passed,
/// because they asserted identity and result key and never handed the receipt
/// to a real consumer. The validator would have rejected it, and an operator
/// whose acknowledgement had genuinely been accepted would have been told it
/// could not be acknowledged.
///
/// These tests take the recovered receipt through the actual validator.
void main() {
  final now = DateTime.utc(2026, 9, 10, 7, 12);

  final command = WorkflowCommand(
    commandId: 'cmd-ack-1',
    type: WorkflowCommandType.acknowledgeMaintenanceTicket,
    aggregateId: 'ticket-base-205',
    expectedVersion: 4,
    payload: <String, Object?>{'lane': 'MECHANICAL'},
  );

  WorkflowCommandReceiptRecord storedAcceptance({String? resultJson}) {
    return WorkflowCommandReceiptRecord()
      ..commandId = command.commandId
      ..aggregateId = command.aggregateId
      ..resultKey = 'maintenance-ticket-acknowledged'
      ..aggregateVersion = command.expectedVersion + 1
      ..resultJson =
          resultJson ??
          jsonEncode(<String, Object?>{
            'ticketId': command.aggregateId,
            'auditId': 'server_maintenance_ticket_${command.commandId}',
            'lane': 'MECHANICAL',
          })
      ..appliedAt = now;
  }

  WorkflowOnlineExecutor executorWith(RecordingWorkflowRepository repository) {
    return WorkflowOnlineExecutor(
      connectivity: Connectivity(),
      gateway: const _AlwaysUnavailableGateway(),
      repository: repository,
      now: () => now,
      checkConnectivity:
          () async => <ConnectivityResult>[ConnectivityResult.wifi],
      isNetworkBlocked: () async => false,
    );
  }

  test('a recovered acknowledgement satisfies its real validator', () async {
    final repository = RecordingWorkflowRepository(
      existing: null,
      acceptedReceipt: storedAcceptance(),
    );

    final receipt = await executorWith(repository).execute(command);

    // The assertion that matters: not that a receipt came back, but that the
    // caller accepts it as evidence of the work it asked for.
    expect(
      () => validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: receipt,
      ),
      returnsNormally,
    );
    expect(receipt.result['ticketId'], command.aggregateId);
    expect(
      receipt.result['auditId'],
      'server_maintenance_ticket_${command.commandId}',
    );
  });

  test('an empty stored result would be rejected, not silently accepted', () async {
    // Guards the regression directly: if the payload is ever dropped again,
    // the validator refuses it rather than the failure surfacing in a plant.
    final repository = RecordingWorkflowRepository(
      existing: null,
      acceptedReceipt: storedAcceptance(resultJson: '{}'),
    );

    final receipt = await executorWith(repository).execute(command);

    expect(
      () => validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: receipt,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('a malformed stored result is raised, not turned into an empty map', () async {
    final repository = RecordingWorkflowRepository(
      existing: null,
      acceptedReceipt: storedAcceptance(resultJson: 'not json at all'),
    );

    // Decoding goes through the same bounded reader the wire path uses, so
    // damaged evidence surfaces as a persisted-data problem instead of
    // quietly becoming a receipt that fails validation for the wrong reason.
    await expectLater(
      () => executorWith(repository).execute(command),
      throwsA(isNot(isA<WorkflowException>())),
    );
  });
}

class _AlwaysUnavailableGateway implements WorkflowCommandGateway {
  const _AlwaysUnavailableGateway();

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    throw const WorkflowException(
      WorkflowErrorCode.unavailable,
      'unreachable',
    );
  }
}
