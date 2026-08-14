import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ticket supervision is represented from UI through server authority', () {
    final types =
        File(
          'lib/features/maintenance_workflow/domain/workflow_types.dart',
        ).readAsStringSync();
    final ticketScreen =
        File(
          'lib/features/maintenance/presentation/ticket_screen.dart',
        ).readAsStringSync();
    final adminBrowser =
        File(
          'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
        ).readAsStringSync();
    final repository =
        File(
          'lib/features/maintenance/providers/maintenance_provider.dart',
        ).readAsStringSync();
    final backend =
        File(
          'functions/src/maintenanceWorkflow/ticketHandlers.ts',
        ).readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(types, contains('acknowledgeMaintenanceTicket'));
    expect(types, contains('correctMaintenanceTicket'));
    expect(ticketScreen, contains("'Issue acknowledged'"));
    expect(
      ticketScreen,
      contains('WorkflowCommandType.acknowledgeMaintenanceTicket'),
    );
    expect(
      adminBrowser,
      contains('WorkflowCommandType.correctMaintenanceTicket'),
    );
    expect(adminBrowser, contains("'corrections': correction.corrections"));
    expect(repository, isNot(contains('Future<void> updateTicket(')));
    expect(backend, contains('server_maintenance_ticket_'));
    expect(backend, contains('maintenance-ticket-replay-audit-invalid'));
    expect(backend, contains('maintenance-ticket-route-department-invalid'));
    expect(rules, isNot(contains('validMaintenanceAdminEditUpdate')));
    expect(rules, contains("!docId.matches('^server_maintenance_ticket_.*')"));
  });
}
