import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_reports_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_event_issue_links_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('management reports reject before report-source reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const FleetStatusScreen(),
      overrides: [
        assetClassesProvider.overrideWith((ref) {
          reads++;
          throw StateError('asset classes must not be read');
        }),
        allAssetInstancesProvider.overrideWith((ref) {
          reads++;
          throw StateError('assets must not be read');
        }),
        operationsReportProvider.overrideWith((ref, filter) {
          reads++;
          throw StateError('report must not be built');
        }),
      ],
    );

    expect(find.text('Report access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('abnormality reports reject before repository access', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const AbnormalityReportsScreen(),
      overrides: [
        abnormalityRepositoryProvider.overrideWith((ref) {
          reads++;
          throw StateError('abnormality repository must not be read');
        }),
      ],
    );

    expect(find.text('Abnormality-report access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('compliance notifications reject before record lookup', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const ComplianceNotificationScreen(complianceId: 'request-1'),
      overrides: [
        workflowComplianceRecordProvider.overrideWith((ref, complianceId) {
          reads++;
          throw StateError('compliance record must not be read');
        }),
      ],
    );

    expect(find.text('Compliance access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('event issue links reject before event and link reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: OperationalEventIssueLinksScreen(event: _event()),
      overrides: [
        operationalEventsProvider.overrideWith((ref) {
          reads++;
          throw StateError('events must not be read');
        }),
        operationalEventIssueLinksProvider.overrideWith((ref, eventId) {
          reads++;
          throw StateError('event links must not be read');
        }),
      ],
    );

    expect(find.text('Event-link access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('issue event links reject before linked-event reads', (
    tester,
  ) async {
    var reads = 0;
    final issue = MaintenanceRecord()..firestoreId = 'issue-1';

    await _pumpUnapproved(
      tester,
      screen: MaintenanceIssueEventLinksScreen(issue: issue),
      overrides: [
        operationalIssueEventLinksProvider.overrideWith((ref, issueId) {
          reads++;
          throw StateError('issue links must not be read');
        }),
      ],
    );

    expect(find.text('Issue-link access required'), findsOneWidget);
    expect(reads, 0);
  });
}

Future<void> _pumpUnapproved(
  WidgetTester tester, {
  required Widget screen,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream<AppUser?>.value(_unapprovedActor()),
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: BafAppTheme.light, home: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

AppUser _unapprovedActor() => AppUser(
  uid: 'revoked-operations',
  name: 'Revoked Operations',
  email: 'revoked.operations@example.com',
  roles: const <AppRole>[AppRole.operations],
  isApproved: false,
  createdAt: DateTime.utc(2026, 8, 24),
);

OperationalEvent _event() {
  final startedAt = DateTime.utc(2026, 8, 24, 8);
  return OperationalEvent(
    eventId: 'event-1',
    eventType: OperationalEventType.crane,
    title: 'Crane unavailable',
    description: 'Crane movement is unavailable.',
    severity: OperationalEventSeverity.significant,
    scope: OperationalEventScope.plantWide,
    affectedAssetClassIds: const [],
    affectedAssetInstanceIds: const [],
    startedAt: startedAt,
    status: OperationalEventStatus.open,
    createdAt: startedAt,
    createdByUid: 'operations-1',
    createdByName: 'Operations One',
    resolvedAt: null,
    resolvedByUid: null,
    resolvedByName: null,
    resolutionNote: null,
    version: 1,
    updatedAt: startedAt,
    updatedByUid: 'operations-1',
    updatedByName: 'Operations One',
    lastMutationId: 'event-create-1',
  );
}
