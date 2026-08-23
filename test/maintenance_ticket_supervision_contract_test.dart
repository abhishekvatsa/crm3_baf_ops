import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/testing/dart_library_source.dart';

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
    final maintenanceForm =
        File(
          'lib/features/maintenance/presentation/maintenance_form.dart',
        ).readAsStringSync();
    final resolveForm =
        File(
          'lib/features/maintenance/presentation/resolve_form.dart',
        ).readAsStringSync();
    final closedTicketsScreen =
        File(
          'lib/features/maintenance/presentation/closed_tickets_screen.dart',
        ).readAsStringSync();
    final adminBrowser =
        File(
          'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
        ).readAsStringSync();
    final repository = readDartLibrarySource(
      'lib/features/maintenance/providers/maintenance_provider.dart',
    );
    final backend =
        File(
          'functions/src/maintenanceWorkflow/ticketHandlers.ts',
        ).readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(types, contains('acknowledgeMaintenanceTicket'));
    expect(types, contains('completeMaintenanceTicketLane'));
    expect(types, contains('reconfigureMaintenanceTicketLanes'));
    expect(types, contains('resolveMaintenanceTicket'));
    expect(types, contains('reopenMaintenanceTicket'));
    expect(types, contains('correctMaintenanceTicket'));
    expect(ticketScreen, contains("'Issue lane acknowledged'"));
    expect(
      ticketScreen,
      contains('WorkflowCommandType.acknowledgeMaintenanceTicket'),
    );
    expect(
      ticketScreen,
      contains('WorkflowCommandType.completeMaintenanceTicketLane'),
    );
    expect(
      ticketScreen,
      contains('WorkflowCommandType.reconfigureMaintenanceTicketLanes'),
    );
    expect(ticketScreen, contains("'Manage accountable lanes'"));
    expect(ticketScreen, contains("'Repair issue from server'"));
    expect(ticketScreen, contains("'Refresh this issue from server'"));
    expect(ticketScreen, contains('.adoptServerMutation('));
    expect(ticketScreen, contains('.refreshServerState('));
    expect(
      ticketScreen,
      contains("'This stale issue was removed from the active device list.'"),
    );
    expect(
      ticketScreen,
      contains(
        'final hasGovernedServerState =\n                  ticket.isSynced',
      ),
    );
    expect(ticketScreen, contains("label: 'SYNC PENDING'"));
    expect(
      closedTicketsScreen,
      contains("'Synchronize this issue before reopening it.'"),
    );
    expect(maintenanceForm, contains("'Accountable lanes'"));
    expect(maintenanceForm, contains("'Primary lane'"));
    expect(maintenanceForm, contains('FilterChip'));
    expect(resolveForm, contains('buildMaintenanceIssueResolutionCommand('));
    expect(resolveForm, contains('validateMaintenanceIssueResolutionReceipt('));
    expect(resolveForm, contains('.adoptServerMutation('));
    expect(resolveForm, isNot(contains('repository.resolveTicket(')));
    expect(
      adminBrowser,
      contains('WorkflowCommandType.correctMaintenanceTicket'),
    );
    expect(adminBrowser, contains("'corrections': correction.corrections"));
    expect(repository, isNot(contains('Future<void> updateTicket(')));
    expect(backend, contains('server_maintenance_ticket_'));
    expect(backend, contains('maintenance-ticket-replay-audit-invalid'));
    expect(backend, contains('maintenance-ticket-route-locked'));
    expect(backend, contains('maintenance-ticket-route-department-invalid'));
    expect(backend, contains('maintenance-ticket-lane-completed'));
    expect(backend, contains('maintenance-ticket-lanes-reconfigured'));
    expect(backend, contains('maintenance-ticket-resolved'));
    expect(rules, isNot(contains('validMaintenanceAdminEditUpdate')));
    expect(rules, contains("!docId.matches('^server_maintenance_ticket_.*')"));
    expect(rules, contains('validMaintenanceIssueLaneProjection'));
    expect(rules, contains('isMaintenanceIssueSupervisor'));
  });

  test(
    'secondary issue lanes receive live delivery with indexed legacy fallback',
    () {
      final liveSync =
          File(
            'lib/core/services/live_remote_sync_service.dart',
          ).readAsStringSync();
      final indexDocument = Map<String, dynamic>.from(
        jsonDecode(File('firestore.indexes.json').readAsStringSync()) as Map,
      );
      final indexes = List<Map<String, dynamic>>.from(
        (indexDocument['indexes'] as List).map(
          (entry) => Map<String, dynamic>.from(entry as Map),
        ),
      );

      expect(liveSync, contains("'issueAssignedLanes'"));
      expect(liveSync, contains('arrayContains: routedTo.name'));
      expect(liveSync, contains('..add(RoutedTo.shiftInCharge)'));
      expect(
        liveSync,
        contains("base.where('routedTo', isEqualTo: routedTo.name)"),
      );
      expect(
        indexes.any((index) {
          if (index['collectionGroup'] != 'maintenance_records') return false;
          final fields = List<Map<String, dynamic>>.from(
            (index['fields'] as List).map(
              (entry) => Map<String, dynamic>.from(entry as Map),
            ),
          );
          return fields.any(
                (field) =>
                    field['fieldPath'] == 'isDeleted' &&
                    field['order'] == 'ASCENDING',
              ) &&
              fields.any(
                (field) =>
                    field['fieldPath'] == 'isResolved' &&
                    field['order'] == 'ASCENDING',
              ) &&
              fields.any(
                (field) =>
                    field['fieldPath'] == 'issueAssignedLanes' &&
                    field['arrayConfig'] == 'CONTAINS',
              );
        }),
        isTrue,
      );
    },
  );

  test(
    'ticket closure rejects coarse authority before local or remote reads',
    () {
      String resolveMethod(String path) {
        final source = File(path).readAsStringSync();
        final start = source.indexOf('Future<void> resolveTicket(');
        final end = source.indexOf('Future<void> reopenTicket(', start);
        expect(start, greaterThanOrEqualTo(0), reason: path);
        expect(end, greaterThan(start), reason: path);
        return source.substring(start, end);
      }

      final local = resolveMethod(
        'lib/features/maintenance/providers/maintenance_provider.local.dart',
      );
      final remote = resolveMethod(
        'lib/features/maintenance/providers/maintenance_provider.remote.dart',
      );

      expect(
        local.indexOf('_requireCanAttemptCloseMaintenanceTicket(actor)'),
        lessThan(local.indexOf('await isar.writeTxn')),
      );
      expect(
        remote.indexOf('_requireCanAttemptCloseMaintenanceTicket(actor)'),
        lessThan(remote.indexOf("_collection.doc(docId).get()")),
      );
      expect(local, contains('_requireCanCloseMaintenanceTicket(actor, t)'));
      expect(
        remote,
        contains('_requireCanCloseMaintenanceTicket(actor, ticket)'),
      );
    },
  );
}
