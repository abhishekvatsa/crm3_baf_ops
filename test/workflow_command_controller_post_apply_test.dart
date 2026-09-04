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
    'exact-readback caller can skip the unrelated post-apply pull',
    () async {
      var pulls = 0;
      final controller = WorkflowCommandController.forTesting(
        executeCommand: (_) async => receipt,
        pullProjections: () async {
          pulls++;
        },
      );
      addTearDown(controller.dispose);
      expect(
        await controller.execute(command, refreshProjections: false),
        same(receipt),
      );
      expect(pulls, 0);
      expect(controller.state.value, same(receipt));
    },
  );

  test('exact-readback mode still reconciles a rejected command', () async {
    var pulls = 0;
    final failure = StateError('Server rejected command');
    final controller = WorkflowCommandController.forTesting(
      executeCommand: (_) async => throw failure,
      pullProjections: () async {
        pulls++;
      },
    );
    addTearDown(controller.dispose);
    await expectLater(
      controller.execute(command, refreshProjections: false),
      throwsA(same(failure)),
    );
    expect(pulls, 1);
  });

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
