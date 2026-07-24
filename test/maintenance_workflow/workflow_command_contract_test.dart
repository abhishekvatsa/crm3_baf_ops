import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('command wire shape matches server contract', () {
    final command = WorkflowCommand(
      commandId: 'cmd-1',
      type: WorkflowCommandType.acknowledgeLane,
      aggregateId: 'wf-1',
      expectedVersion: 3,
      payload: const {'laneKey': 'emd'},
    );
    expect(command.toMap(), {
      'commandId': 'cmd-1',
      'commandType': 'acknowledgeLane',
      'aggregateId': 'wf-1',
      'expectedVersion': 3,
      'payload': {'laneKey': 'emd'},
    });
  });
}
