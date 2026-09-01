import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/presentation/directives_screen.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/ticket_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/templates_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operational shell and destinations preserve the intended structure', () {
    final home = File('lib/home_screen.dart').readAsStringSync();
    final reports = [
      'lib/features/reports/presentation/fleet_status_screen.dart',
      'lib/features/reports/presentation/fleet_status_insight_widgets.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final operationalEvents =
        File(
          'lib/features/operational_events/presentation/operational_events_screen.dart',
        ).readAsStringSync();
    final operationalControl =
        File(
          'lib/features/operational_events/presentation/operational_control_screen.dart',
        ).readAsStringSync();
    final work =
        File(
          'lib/features/planned_maintenance/presentation/templates_screen.dart',
        ).readAsStringSync();
    final theme =
        File('lib/core/theme/baf_design_system.dart').readAsStringSync();

    expect(home, contains('NavigationRail('));
    expect(home, contains("label: 'Home'"));
    expect(home, contains("label: 'Issues'"));
    expect(home, contains("label: 'Work'"));
    expect(home, contains("label: 'Control'"));
    expect(home, contains("label: 'More'"));
    expect(home, isNot(contains('ModeSwitchCard(')));
    expect(home, isNot(contains("title: 'Core modules'")));
    expect(home, contains("title: 'Assets and lifecycle'"));
    expect(home, contains("title: 'Work and coordination'"));
    expect(home, contains("title: 'Performance and assurance'"));
    expect(home, contains("title: 'Standards and governance'"));
    expect(home, contains("title: 'Administration and support'"));
    expect(home, contains("title: 'Plant condition'"));
    expect(home, contains("title: 'Operations intelligence'"));
    expect(home, contains("title: 'Maintenance workflow'"));
    expect(home, contains("title: 'Directives'"));
    expect(home, contains("'Start here'"));
    expect(home, contains("hintText: 'Find a screen or function'"));
    expect(home, contains("title: 'Closed job dossiers'"));
    expect(home, contains("title: 'Audit log'"));
    expect(home, contains('appUser.canViewOperationalAssets'));
    expect(home, contains('appUser.canViewClosedMaintenanceTickets'));
    expect(home, contains('operationalEventsAsync.value == null'));
    expect(home, contains('qualityWarningsAsync.value == null'));
    expect(home, contains('operationalEventsUnavailable'));
    expect(home, contains('qualityWarningsUnavailable'));
    expect(home, contains("? 'Unavailable'"));
    expect(home, contains("'Live attention data unavailable'"));
    expect(home, contains("'Incomplete'"));
    expect(
      home,
      contains('ref.invalidate(operationalEventsProvider(appUser.uid))'),
    );
    expect(home, contains('ref.invalidate(qualityWarningsProvider)'));
    expect(home, contains('maintenanceDueStatesProvider'));
    expect(home, contains('allInspectionFindingsProvider'));
    expect(home, contains("title: 'Overdue maintenance cadence'"));
    expect(home, contains("title: 'Active inspection findings'"));
    expect(operationalControl, contains("title: 'Directives'"));
    expect(operationalControl, contains("title: 'Workflow obligations'"));
    expect(operationalControl, contains("title: 'Plant disruptions'"));
    expect(operationalControl, contains("title: 'Quality warnings'"));
    expect(operationalControl, contains("title: 'Cycle monitoring'"));
    expect(operationalControl, contains("title: 'Cycle abnormalities'"));
    expect(operationalControl, contains("title: 'Inspection findings'"));
    for (final provider in [
      'assetClassesProvider',
      'allAssetInstancesProvider',
      'assetOperationalConditionsProvider',
      'equipmentStatusProvider(null)',
      'plantAssetOverviewProvider',
      'operationsReportClockProvider',
      'maintenanceDueStatesProvider',
      'allInspectionFindingsProvider',
      'qualityWarningsForReportsProvider',
      'qualityMonitoringRequestsForReportsProvider',
      'operationsReportAbnormalitiesProvider',
      'openDirectivesProvider',
      'workflowAllLanesProvider',
      'workflowAllComplianceProvider',
    ]) {
      expect(reports, contains('ref.invalidate($provider)'));
    }
    expect(reports, contains('report.eventOccurrences'));
    expect(reports, contains('occurrence.interval.startedAt'));
    expect(reports, contains('occurrence.interval.resolvedByName'));
    expect(reports, contains('occurrence.interval.resolutionNote'));
    expect(operationalEvents, contains('event.completedIntervals.reversed'));
    expect(operationalEvents, contains('interval.resolvedByName'));
    expect(operationalEvents, contains('interval.resolutionNote'));

    expect(work, contains('_PlannedWorkView.workflow'));
    expect(work, contains('WorkflowQueueView('));
    expect(work, contains('BoxConstraints(maxWidth: 1000)'));
    expect(theme, contains('static const large = 8.0'));
    expect(theme, contains('static const xLarge = 8.0'));
  });

  testWidgets('operations Work is task-first and hides governance templates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var templateReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          activeTemplatesProvider.overrideWith((ref) {
            templateReads++;
            return Stream<List<JobTemplate>>.value(const []);
          }),
          openExecutionsProvider.overrideWith(
            (ref) => Stream<List<JobExecution>>.value(const []),
          ),
          workflowAllLanesProvider.overrideWith(
            (ref) => Stream<List<JobLaneRecord>>.value(const []),
          ),
          workflowAllComplianceProvider.overrideWith(
            (ref) => Stream<List<ComplianceRequestRecord>>.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const Scaffold(body: TemplatesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
    expect(find.text('Templates'), findsNothing);
    expect(find.text('Assign Published'), findsNothing);
    expect(templateReads, 0);

    await tester.tap(find.text('Workflow'));
    await tester.pumpAndSettle();

    expect(find.text('Workflow queue'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Queue clear'), findsOneWidget);
    expect(find.text('No workflow tasks need your attention.'), findsOneWidget);

    final destinations = <Finder>[
      find.byKey(const ValueKey('workflow-queue-overview')),
      find.byKey(const ValueKey('workflow-queue-compliance')),
      find.byKey(const ValueKey('workflow-queue-equipment')),
    ];
    final destinationRects = destinations.map(tester.getRect).toList();
    expect(destinationRects.map((rect) => rect.top).toSet().length, 1);
    expect(destinationRects.map((rect) => rect.height).toSet().length, 1);
    expect(
      destinationRects.map((rect) => rect.width.round()).toSet().length,
      1,
    );

    final metrics = <Finder>[
      find.byKey(const ValueKey('workflow-queue-lanes-metric')),
      find.byKey(const ValueKey('workflow-queue-actions-metric')),
      find.byKey(const ValueKey('workflow-queue-confirmations-metric')),
    ];
    final metricRects = metrics.map(tester.getRect).toList();
    expect(metricRects.map((rect) => rect.top).toSet().length, 1);
    expect(metricRects.map((rect) => rect.height).toSet().length, 1);
    expect(metricRects.map((rect) => rect.width.round()).toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Issues keeps reporting primary and sync secondary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          openTicketsProvider.overrideWith(
            (ref) => Stream<List<MaintenanceRecord>>.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const Scaffold(body: TicketScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open issues'), findsOneWidget);
    expect(find.byKey(const ValueKey('issues-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('issues-sync-now')), findsOneWidget);
    expect(find.byKey(const ValueKey('issues-view-resolved')), findsOneWidget);
    expect(find.byKey(const ValueKey('issues-raise-issue')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('issues-search'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('issues-raise-issue'))).dy,
      ),
    );
    final actionRowY =
        tester.getCenter(find.byKey(const ValueKey('issues-raise-issue'))).dy;
    expect(
      tester.getCenter(find.byKey(const ValueKey('issues-sync-now'))).dy,
      actionRowY,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('issues-view-resolved'))).dy,
      actionRowY,
    );
    expect(find.text('All clear'), findsOneWidget);
    expect(find.text('Manual sync now'), findsNothing);
    expect(find.byTooltip('Refresh issues'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Directives supports immediate search without hiding creation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
          ),
          openDirectivesProvider.overrideWith(
            (ref) => Stream<List<OperationalDirective>>.value([
              _directive('Inspect furnace seal', assetNumber: 2),
              _directive('Verify cooler alignment', assetNumber: 7),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const Scaffold(body: DirectivesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Directive'), findsOneWidget);
    expect(find.text('Inspect furnace seal'), findsOneWidget);
    expect(find.text('Verify cooler alignment'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('directives-search')),
      'cooler',
    );
    await tester.pump();

    expect(find.text('Inspect furnace seal'), findsNothing);
    expect(find.text('Verify cooler alignment'), findsOneWidget);
    expect(find.text('New Directive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AppUser _actor(AppRole role) => AppUser(
  uid: 'ux-${role.name}',
  name: 'UX ${role.name}',
  email: 'ux.${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: true,
  createdAt: DateTime.utc(2026, 7, 31),
);

OperationalDirective _directive(String title, {required int assetNumber}) {
  final timestamp = DateTime.utc(2026, 7, 31, 19);
  return OperationalDirective()
    ..firestoreId = 'directive-$assetNumber'
    ..title = title
    ..description = 'Operational follow-up for asset $assetNumber'
    ..assetType = AssetType.furnace
    ..assetNumber = assetNumber
    ..directedTo = AppRole.operations
    ..priority = DirectivePriority.high
    ..status = DirectiveStatus.open
    ..issuedByUid = 'ux-admin'
    ..issuedByName = 'UX Admin'
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isSynced = true;
}
