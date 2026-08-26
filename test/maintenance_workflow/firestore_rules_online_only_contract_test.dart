import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workflow collections deny direct client writes', () {
    final rules = File('firestore.rules').readAsStringSync();
    for (final collection in [
      'maintenance_workflows',
      'job_lanes',
      'compliance_requests',
      'compliance_attempts',
      'equipment_status',
      'equipment_prompt_master',
      'maintenance_workflow_events',
      'maintenance_workflow_command_receipts',
      'workflow_notification_receipts',
      'notification_event_receipts',
      'critical_alarms',
      'critical_alarm_contacts',
      'critical_alarm_audits',
      'critical_alarm_contact_audits',
    ]) {
      final block = RegExp(
        r'match\s+/' + RegExp.escape(collection) + r'/\{[^}]+\}\s*\{([\s\S]*?)\n\s*\}',
      ).firstMatch(rules);
      expect(block, isNotNull, reason: 'Missing Rules block for $collection');
      final body = block!.group(1)!;
      final deniesDirectWrites =
          body.contains('allow write: if false') ||
          RegExp(
            r'allow\s+(?:read,\s*)?create,\s*update,\s*delete\s*:\s*if\s+false\s*;',
          ).hasMatch(body);
      expect(
        deniesDirectWrites,
        isTrue,
        reason:
            '$collection must reject create, update and delete through an explicit fail-closed rule',
      );
    }
  });
}
