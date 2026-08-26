import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _section(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'Missing $end after $start');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('R-05 source and CI closure is exact without delivery overclaim', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;
    final finding = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'R-05');

    expect(finding['authorityType'], 'SOURCE_AND_CI');
    expect(finding['currentStatus'], 'CLOSED');
    final evidence = _objects(finding['evidence']).single;
    expect(evidence['pullRequest'], 117);
    expect(
      evidence['headCommit'],
      '946c414fee7605f590253dc630a0205095f3b44d',
    );
    expect(
      evidence['mergeCommit'],
      '45ebd9c853798f88fedd2e4d72d6022dc389097f',
    );
    expect(evidence['pullRequestWorkflowRun'], 30795773566);
    expect(evidence['postMergeWorkflowRun'], 30796250694);
    expect(
      evidence['decision'],
      'PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE',
    );
    expect(evidence['productionDeploymentPerformed'], isFalse);
    expect(evidence['deviceEvidenceClaimed'], isFalse);
    expect(evidence['pilotAuthorizationCreated'], isFalse);
    expect(
      _objects(finding['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    expect(_strings(finding['requiredExitEvidence']), hasLength(6));
    expect(_strings(finding['reArmTriggers']), hasLength(6));
    expect(
      _strings(finding['notes']).join('\n'),
      contains(
        'It is not deployment, notification-delivery, device, pilot or cutover evidence.',
      ),
    );
  });

  test('every notification trigger is receipt-first and retry-enabled', () {
    final index = File('functions/src/index.ts').readAsStringSync();
    final triggerSections = <String>[
      _section(index, 'export const onTicketCreated', 'export const onTicketResolved'),
      _section(index, 'export const onTicketResolved', 'export const onJobAssigned'),
      _section(index, 'export const onJobAssigned', 'Maintenance workflow control plane'),
    ];
    for (final source in triggerSections) {
      expect(source, contains('retry: true'));
      expect(source, contains('cloudEventId: event.id'));
      final receiptIndex = source.indexOf('executeIdempotentNotificationEvent({');
      final recipientIndex = source.indexOf('getTokenLookup');
      expect(receiptIndex, greaterThanOrEqualTo(0));
      expect(recipientIndex, greaterThan(receiptIndex));
    }

    final workflow = File(
      'functions/src/maintenanceWorkflow/workflowNotificationTrigger.ts',
    ).readAsStringSync();
    expect(workflow, contains('retry: true'));
    expect(workflow, contains('cloudEventId: event.id'));
    expect(
      workflow.indexOf('executeIdempotentNotificationEvent({'),
      lessThan(workflow.indexOf('getTokenLookupsForRoles(')),
    );
    expect(workflow, contains('workflow_notification_receipts'));
    expect(workflow, contains('deviceRecoveryStateDocumentId'));
    expect(workflow, contains('state.status !== "pending"'));
    expect(workflow, contains('retryKnownFailure:'));
    expect(workflow, contains('shouldRetryKnownWorkflowNotificationFailure('));
    expect(workflow, contains('criticalAlarmRecipientCloudEventId('));
    expect(workflow, contains('groupNotificationRecipientsByToken'));
    expect(workflow, contains('recipients: recipientGroup.registrations'));
    expect(workflow, contains('Promise.allSettled'));
    expect(workflow, contains('shouldRetryCriticalAlarmRecipientFailure(outcome)'));
    final notificationPolicy = File(
      'functions/src/maintenanceWorkflow/workflowNotificationPolicy.ts',
    ).readAsStringSync();
    expect(
      notificationPolicy,
      contains('export const shouldRetryCriticalAlarmRecipientFailure'),
    );
    expect(notificationPolicy, contains('outcome.attempted === 1'));
    expect(notificationPolicy, contains('outcome.failed === 1'));
    expect(notificationPolicy, contains('outcome.retryableFailures === 1'));
    expect(
      notificationPolicy,
      isNot(contains('outcome.retryableFailures === outcome.attempted')),
    );
    expect(workflow, contains('return null;'));
  });

  test('receipt state machine, client denial and evidence remain fail closed', () {
    final receipt = File(
      'functions/src/notificationEventReceipt.ts',
    ).readAsStringSync();
    for (final marker in <String>[
      'notification-event-receipt-v1\\0',
      'notification_event_receipts',
      'failedBeforeDispatch',
      'retryableDeliveryFailed',
      'deliveryUncertain',
      'notification-event-receipt-attempt-mismatch',
      'notification-event-receipt-attempt-exhausted',
      'notification-event-receipt-state-malformed',
      'existing.status === "dispatching"',
      'reason: "delivery-uncertain"',
      'requiresAdjudication: true',
      'reportDeliveryUncertain',
    ]) {
      expect(receipt, contains(marker), reason: 'Missing receipt marker $marker');
    }

    final rules = File('firestore.rules').readAsStringSync();
    final receiptRules = _section(
      rules,
      'match /notification_event_receipts/{docId}',
      'AUDIT LOGS',
    );
    expect(
      receiptRules,
      contains('allow read, create, update, delete: if false;'),
    );
    final functionsPackage = File('functions/package.json').readAsStringSync();
    expect(File('functions/test/notificationEventReceipt.test.js').existsSync(), isTrue);
    expect(
      functionsPackage,
      contains('notificationEventReceipt.firestoreEmulator.test.js'),
    );
    expect(functionsPackage, contains('audit:notification-inventory'));
    final inventoryPolicy = jsonDecode(
      File(
        'release/r05-notification-trigger-source-policy.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(inventoryPolicy['schemaVersion'], 1);
    expect(
      _objects(inventoryPolicy['notificationTriggers'])
          .map((trigger) => trigger['name'])
          .toSet(),
      <String>{
        'onTicketCreated',
        'onTicketResolved',
        'onJobAssigned',
        'onMaintenanceWorkflowEventCreated',
      },
    );
    final inventoryAudit = File(
      'functions/tools/audit_notification_trigger_inventory.mjs',
    ).readAsStringSync();
    expect(inventoryAudit, contains('notification-trigger-policy-mismatch'));
    expect(
      inventoryAudit,
      contains('notification-dispatch-outside-receipt-boundary'),
    );

    final decision = File(
      'docs/v4_2_r1/R05_NOTIFICATION_EVENT_IDEMPOTENCY.md',
    ).readAsStringSync();
    expect(decision, contains('Status: CLOSED'));
    expect(decision, contains('This is not an exactly-once delivery claim.'));
    expect(decision, contains('structured error-level signal'));
    expect(decision, contains('operator-queryable marker'));
    expect(decision, contains('exact single-device'));
    expect(
      decision,
      contains('A reporting failure cannot reopen or resend the event.'),
    );
    expect(
      decision,
      contains('PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE'),
    );
    expect(decision, contains('`R-05` is closed'));
  });
}
