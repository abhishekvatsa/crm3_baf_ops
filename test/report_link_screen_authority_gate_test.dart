import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_reports_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_issue_link.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_event_issue_links_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report and link guards reject every loading authority state', () {
    for (final path in <String>[
      'lib/features/abnormalities/presentation/abnormality_reports_screen.dart',
      'lib/features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart',
      'lib/features/operational_events/presentation/operational_event_issue_links_screen.dart',
      'lib/features/reports/presentation/fleet_status_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('actorAsync.isLoading && !actorAsync.hasValue')),
        reason: path,
      );
    }
  });

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

  testWidgets('compliance notification applies the exact request audience', (
    tester,
  ) async {
    var reads = 0;
    final request =
        ComplianceRequestRecord()
          ..firestoreId = 'request-1'
          ..linkedWorkflowId = 'workflow-1'
          ..title = 'Operations support'
          ..description = 'Move the furnace to the maintenance position.'
          ..targetLaneKey = 'inst'
          ..originLaneKey = 'elec'
          ..raisedByUid = 'operations-raiser'
          ..statusKey = 'raised';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(
              _approvedActor(AppRole.seniorMechanical),
            ),
          ),
          workflowComplianceRecordProvider.overrideWith((ref, complianceId) {
            reads++;
            return Future.value(request);
          }),
        ],
        child: const MaterialApp(
          home: ComplianceNotificationScreen(complianceId: 'request-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compliance audience required'), findsOneWidget);
    expect(find.text(request.description), findsNothing);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
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

  test('event and link providers dispose after their last listener', () async {
    var eventDisposals = 0;
    var eventLinkDisposals = 0;
    var issueLinkDisposals = 0;
    final container = ProviderContainer(
      overrides: [
        operationalEventsProvider.overrideWith((ref) {
          ref.onDispose(() => eventDisposals++);
          return Stream<List<OperationalEvent>>.value(const []);
        }),
        operationalEventIssueLinksProvider.overrideWith((ref, eventId) {
          ref.onDispose(() => eventLinkDisposals++);
          return Stream<List<OperationalEventIssueLink>>.value(const []);
        }),
        operationalIssueEventLinksProvider.overrideWith((ref, issueId) {
          ref.onDispose(() => issueLinkDisposals++);
          return Stream<List<OperationalEventIssueLink>>.value(const []);
        }),
      ],
    );
    addTearDown(container.dispose);

    final events = container.listen(operationalEventsProvider, (_, _) {});
    final eventLinks = container.listen(
      operationalEventIssueLinksProvider('event-1'),
      (_, _) {},
    );
    final issueLinks = container.listen(
      operationalIssueEventLinksProvider('issue-1'),
      (_, _) {},
    );
    events.close();
    eventLinks.close();
    issueLinks.close();
    await Future<void>.delayed(Duration.zero);

    expect(eventDisposals, 1);
    expect(eventLinkDisposals, 1);
    expect(issueLinkDisposals, 1);
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

AppUser _approvedActor(AppRole role) => AppUser(
  uid: 'approved-${role.name}',
  name: 'Approved ${role.name}',
  email: 'approved.${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: true,
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
