import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final command = WorkflowCommand(
    commandId: 'command-1',
    type: WorkflowCommandType.acknowledgeMaintenanceTicket,
    aggregateId: 'ticket-1',
    expectedVersion: 3,
    payload: const <String, Object?>{'lane': 'mechanical'},
  );
  final receipt = WorkflowCommandReceipt(
    commandId: 'command-1',
    resultKey: 'maintenance-ticket-acknowledged',
    aggregateVersion: 4,
    result: const <String, Object?>{
      'ticketId': 'ticket-1',
      'lane': 'mechanical',
    },
    appliedAt: DateTime.utc(2026, 8, 23, 4),
  );

  test(
    'post-apply pull failure cannot turn an accepted command into rejection',
    () async {
      var pulls = 0;
      final controller = WorkflowCommandController.forTesting(
        executeCommand: (_) async => receipt,
        pullProjections: () async {
          pulls += 1;
          throw StateError('projection unavailable');
        },
      );

      await expectLater(controller.execute(command), completion(same(receipt)));
      expect(pulls, 1);
      expect(controller.state, isA<AsyncData<WorkflowCommandReceipt?>>());
      expect(controller.state.value, same(receipt));
    },
  );

  test(
    'an actual command failure remains rejected after best-effort pull',
    () async {
      var pulls = 0;
      const failure = WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Not authorized.',
      );
      final controller = WorkflowCommandController.forTesting(
        executeCommand: (_) async => throw failure,
        pullProjections: () async {
          pulls += 1;
        },
      );

      await expectLater(controller.execute(command), throwsA(same(failure)));
      expect(pulls, 1);
      expect(controller.state, isA<AsyncError<WorkflowCommandReceipt?>>());
    },
  );
}
