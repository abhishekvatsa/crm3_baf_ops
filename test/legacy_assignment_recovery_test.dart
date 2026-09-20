import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/legacy_assignment_recovery.dart';

void main() {
  test(
    'concurrent screens cannot both allocate fresh assignment identities',
    () {
      final release = claimLegacyAssignmentAdmission('actor', 'template');
      expect(
        () => claimLegacyAssignmentAdmission('actor', 'template'),
        throwsStateError,
      );
      release();
      final second = claimLegacyAssignmentAdmission('actor', 'template');
      release(); // An old release cannot unlock the new owner's admission.
      expect(
        () => claimLegacyAssignmentAdmission('actor', 'template'),
        throwsStateError,
      );
      second();
    },
  );
  WorkflowCommandRecord saved({
    String actor = 'original',
    String state = 'uncertainOutcome',
  }) => WorkflowCommandRecord()
    ..commandId = 'original-command'
    ..aggregateId = 'original-execution'
    ..commandTypeKey = 'createLegacyWorkflowJob'
    ..stateKey = state
    ..payloadJson = jsonEncode({
      '__workflowOriginBoundV1': actor,
      'payload': {
        'executionId': 'original-execution',
        'templateFirestoreId': 'template',
        'assetInstanceId': 'asset',
        'remarks': 'Retain exact instructions',
      },
    });
  test('reopened screen recovers exact durable command, not fresh IDs', () {
    final command = retainedLegacyAssignment(
      [saved()],
      actorUid: 'original',
      templateId: 'template',
    )!;
    expect(command.commandId, 'original-command');
    expect(command.aggregateId, 'original-execution');
    expect(command.payload['remarks'], 'Retain exact instructions');
  });
  test('replacement account cannot see or recover original command', () {
    expect(
      retainedLegacyAssignment(
        [saved()],
        actorUid: 'replacement',
        templateId: 'template',
      ),
      isNull,
    );
  });
  test('unbound and conflicting saved evidence prevents fresh admission', () {
    final unbound = saved()..payloadJson = '{"executionId":"old"}';
    expect(
      () => retainedLegacyAssignment(
        [unbound],
        actorUid: 'original',
        templateId: 'template',
      ),
      throwsStateError,
    );
    expect(
      () => retainedLegacyAssignment(
        [saved(), saved()..commandId = 'other'],
        actorUid: 'original',
        templateId: 'template',
      ),
      throwsStateError,
    );
    final mismatch = saved()..aggregateId = 'different';
    expect(
      () => retainedLegacyAssignment(
        [mismatch],
        actorUid: 'original',
        templateId: 'template',
      ),
      throwsStateError,
    );
  });
  test('terminal records do not resurrect or block a new intentional job', () {
    expect(
      retainedLegacyAssignment(
        [saved(state: 'applied'), saved(state: 'rejected')],
        actorUid: 'original',
        templateId: 'template',
      ),
      isNull,
    );
  });
}
