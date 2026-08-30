import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/reports/domain/maintenance_ticket_dossier.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dossier distinguishes exact lane completion from legacy evidence', () {
    final completedAt = DateTime.utc(2026, 8, 30, 10, 25);
    final ticket = _resolvedTicket(
      IssueLanePlan.initial(const <String>['electrical'])
          .acknowledge('electrical')
          .complete(
            'electrical',
            evidence: IssueLaneCompletionEvidence(
              completedAt: completedAt,
              completedByUid: 'electrical-1',
              completedByName: 'Electrical One',
            ),
          ),
    );

    final exactDocument = buildMaintenanceTicketDossier(
      ticket: ticket,
      correctionEvents: const [],
      generatedAt: DateTime.utc(2026, 8, 30, 12),
      generatedByName: 'Supervisor One',
      provenance: const ReportProvenance.applicationSnapshot(),
    );
    final exactTable =
        exactDocument.sections
            .singleWhere((section) => section.title == 'Lane accountability')
            .tables
            .single;
    final local = completedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final expectedTime =
        '${two(local.day)}-${two(local.month)}-${local.year} '
        '${two(local.hour)}:${two(local.minute)}';

    expect(exactTable.headers, contains('Completion time / authority'));
    expect(exactTable.rows.single[3], '$expectedTime by Electrical One');

    ticket.issueLanePlan = IssueLanePlan.initial(const <String>[
      'electrical',
    ]).acknowledge('electrical').complete('electrical');
    final legacyDocument = buildMaintenanceTicketDossier(
      ticket: ticket,
      correctionEvents: const [],
      generatedAt: DateTime.utc(2026, 8, 30, 12, 1),
      generatedByName: 'Supervisor One',
      provenance: const ReportProvenance.applicationSnapshot(),
    );
    final legacyTable =
        legacyDocument.sections
            .singleWhere((section) => section.title == 'Lane accountability')
            .tables
            .single;
    expect(
      legacyTable.rows.single[3],
      'Exact lane completion time was not retained for this record',
    );
  });
}

MaintenanceRecord _resolvedTicket(IssueLanePlan lanePlan) {
  final closedAt = DateTime.utc(2026, 8, 30, 11);
  return MaintenanceRecord()
    ..firestoreId = 'ticket-lane-time-1'
    ..version = 5
    ..isSynced = true
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Electrical attendance completed.'
    ..routedTo = RoutedTo.electrical
    ..status = TicketStatus.resolved
    ..isResolved = true
    ..isCritical = false
    ..loggedByUid = 'operations-1'
    ..loggedByName = 'Operations One'
    ..acknowledgedByUid = 'electrical-1'
    ..acknowledgedByName = 'Electrical One'
    ..acknowledgedAt = closedAt.subtract(const Duration(minutes: 45))
    ..startDate = closedAt.subtract(const Duration(hours: 2))
    ..createdAt = closedAt.subtract(const Duration(hours: 2))
    ..updatedAt = closedAt
    ..endDate = closedAt
    ..closedByUid = 'electrical-1'
    ..closedByName = 'Electrical One'
    ..actionsJson = '[]'
    ..resolutionHistoryJson = '[]'
    ..issueLanePlan = lanePlan;
}
