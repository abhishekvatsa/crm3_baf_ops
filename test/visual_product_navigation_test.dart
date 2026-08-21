import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raise issue'), findsOneWidget);
    expect(find.text('Plant status'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    await tester.tap(find.text('Raise issue'));
    await tester.tap(find.text('Plant status'));
    await tester.tap(find.text('Reports'));
    expect((raised, plant, reports), (1, 1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'management pulse fits narrow screens without hiding its signals',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
                    actionCount: 7,
                    assuranceCount: 2,
                    dataUnavailable: false,
                    onOpenReports: () {},
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
      expect(tester.takeException(), isNull);
    },
  );

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
