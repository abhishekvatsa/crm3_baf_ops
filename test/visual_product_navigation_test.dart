import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_control_screen.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home command hierarchy remains explicit on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var raised = 0;
    var plant = 0;
    var reports = 0;
    var control = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(BafSpacing.md),
            child: HomeCommandBar(
              onRaiseIssue: () => raised += 1,
              onPlantCondition: () => plant += 1,
              onReports: () => reports += 1,
              onControl: () => control += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raise issue'), findsOneWidget);
    expect(find.text('Plant'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    await tester.tap(find.text('Raise issue'));
    await tester.tap(find.text('Plant'));
    await tester.tap(find.text('Reports'));
    await tester.tap(find.text('Control'));
    expect((raised, plant, reports, control), (1, 1, 1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'management pulse fits narrow screens without hiding its signals',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var control = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(BafSpacing.md),
                  child: HomeManagementPulsePanel(
                    plantOverview: const AsyncData(
                      PlantAssetOverview(classes: [], assets: []),
                    ),
                    actionCount: 2,
                    assuranceCount: 0,
                    dataUnavailable: false,
                    onOpenReports: () {},
                    onPlantCondition: () {},
                    onIssues: () {},
                    onWork: () {},
                    onControl: () => control += 1,
                    onRetry: () {},
                    onMaintenanceRhythm: () {},
                    onInspectionProgrammes: () {},
                    ticketCount: 0,
                    executionCount: 0,
                    directiveCount: 2,
                    workflowAttentionCount: 0,
                    openOperationalEventCount: 0,
                    openQualityWarningCount: 0,
                    overdueMaintenanceCount: 0,
                    activeInspectionFindingCount: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Management pulse'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Action queue'), findsOneWidget);
      expect(find.text('Assurance'), findsOneWidget);
      expect(find.byTooltip('Open operations reports'), findsOneWidget);
      expect(find.text('2 directives remain active.'), findsOneWidget);
      await tester.tap(find.text('2 directives remain active.'));
      expect(control, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('incomplete management data invokes the retry action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var retries = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeManagementPulsePanel(
                plantOverview: const AsyncData(
                  PlantAssetOverview(classes: [], assets: []),
                ),
                actionCount: 0,
                assuranceCount: 0,
                dataUnavailable: true,
                onOpenReports: () {},
                onPlantCondition: () {},
                onIssues: () {},
                onWork: () {},
                onControl: () {},
                onRetry: () => retries += 1,
                onMaintenanceRhythm: () {},
                onInspectionProgrammes: () {},
                ticketCount: 0,
                executionCount: 0,
                directiveCount: 0,
                workflowAttentionCount: 0,
                openOperationalEventCount: 0,
                openQualityWarningCount: 0,
                overdueMaintenanceCount: 0,
                activeInspectionFindingCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final prompt = find.text(
      'Live sources are incomplete. Refresh before final decisions.',
    );
    expect(prompt, findsOneWidget);
    await tester.tap(prompt);
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operational control represents cross-functional queues', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final actor = AppUser(
      uid: 'admin',
      name: 'Admin',
      email: 'admin@example.com',
      roles: const [AppRole.admin],
      isApproved: true,
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          body: OperationalControlScreen(
            appUser: actor,
            directiveCount: 2,
            workflowAttentionCount: 1,
            operationalEventCount: 1,
            qualityWarningCount: 3,
            inspectionFindingCount: 2,
            directiveDataUnavailable: false,
            workflowDataUnavailable: false,
            operationalEventsUnavailable: false,
            qualityWarningsUnavailable: false,
            inspectionFindingsUnavailable: false,
            onDirectives: () {},
            onWorkflow: () {},
            onOperationalEvents: () {},
            onQuality: () {},
            onAbnormalities: () {},
            onInspections: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operational control'), findsOneWidget);
    expect(find.text('3 quality warnings remain open'), findsOneWidget);
    expect(find.text('Directives'), findsOneWidget);
    expect(find.text('Plant disruptions'), findsOneWidget);
    expect(find.text('Cycle abnormalities'), findsOneWidget);
    expect(find.text('Inspection findings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report modes remain selectable at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = OperationsReportView.overview;

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          body: OperationsReportViewSelector(
            selected: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Reliability'), findsOneWidget);
    expect(find.text('Assurance'), findsOneWidget);
    await tester.tap(find.text('Work'));
    await tester.pump();
    expect(selected, OperationsReportView.work);
    expect(tester.takeException(), isNull);
  });

  testWidgets('management readout remains legible at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 22, 12, 30);
    final report = OperationsReport(
      filter: OperationsReportFilter(startDate: now, endDate: now),
      asOf: now,
      tickets: const [],
      executions: const [],
      events: const [],
      eventOccurrences: const [],
      dueStates: const [],
      inspectionFindings: const [],
      assetStates: const [],
      classSummaries: const [],
      topComponents: const [],
      topSubsystemPaths: const [],
      sourceTicketCount: 0,
      sourceExecutionCount: 0,
      sourceEventCount: 0,
      sourceDueStateCount: 0,
      sourceInspectionFindingCount: 0,
      disruptionCount: 0,
      openDisruptionCount: 0,
      disruptionDuration: Duration.zero,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(BafSpacing.md),
              child: OperationsManagementReadout(report: report),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Management readout'), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Assurance due'), findsOneWidget);
    expect(find.textContaining('No active exception'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
