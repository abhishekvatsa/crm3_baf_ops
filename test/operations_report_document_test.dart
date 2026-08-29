import 'dart:convert';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:crm3_baf_ops/features/reports/domain/operations_report_document.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/operations_report_pdf_screen.dart';
import 'package:crm3_baf_ops/features/reports/services/operations_report_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('operations report document contract', () {
    test('complete preset includes every section in canonical order', () {
      final request = OperationsReportDocumentRequest.forPreset(
        preset: OperationsReportDocumentPreset.complete,
        generatedAt: DateTime.utc(2026, 8, 29, 10, 11, 12),
        generatedByName: 'Test Supervisor',
        generatedByEmail: 'supervisor@example.com',
      );

      expect(request.orderedSections, operationsReportSectionOrder);
      expect(request.reportId, 'OPS-260829-101112');
      expect(
        request.fileName,
        'crm3_integrated_operations_report_OPS-260829-101112.pdf',
      );
    });

    test('reliability preset carries current Burner and UV evidence', () {
      final sections = operationsReportSectionsForPreset(
        OperationsReportDocumentPreset.reliability,
      );

      expect(sections, contains(OperationsReportSection.reliability));
      expect(sections, contains(OperationsReportSection.burnerUvCondition));
      expect(
        sections,
        isNot(contains(OperationsReportSection.maintenanceIssues)),
      );
    });

    test(
      'quality preset carries warning, abnormality and inspection evidence',
      () {
        final sections = operationsReportSectionsForPreset(
          OperationsReportDocumentPreset.quality,
        );

        expect(sections, contains(OperationsReportSection.qualityAndAssurance));
        expect(
          sections,
          isNot(contains(OperationsReportSection.maintenanceIssues)),
        );
      },
    );

    test('safety preset carries alarms, disruptions and response controls', () {
      final sections = operationsReportSectionsForPreset(
        OperationsReportDocumentPreset.safetyAndDisruption,
      );

      expect(sections, contains(OperationsReportSection.plantDisruptions));
      expect(sections, contains(OperationsReportSection.safetyCriticalAlarms));
      expect(sections, contains(OperationsReportSection.operationalControl));
    });

    test('report cell normalization preserves the complete evidence text', () {
      final narrative =
          '${List<String>.filled(80, 'complete maintenance evidence').join(' ')} '
          'FINAL-RETAINED-EVIDENCE';

      final normalized =
          OperationsReportPdfService.normalizeReportCellTextForTesting(
            narrative,
          );

      expect(normalized, narrative);
      expect(normalized, endsWith('FINAL-RETAINED-EVIDENCE'));
      expect(normalized.length, greaterThan(180));
    });

    test('report cells safely segment unbroken retained evidence', () {
      final narrative = '${List<String>.filled(900, 'X').join()}-FINAL';

      final segments = OperationsReportPdfService.segmentReportRowForTesting(
        <String>['Evidence', narrative],
      );

      expect(segments.length, greaterThan(1));
      expect(
        segments.every((row) => row.every((cell) => cell.length <= 360)),
        isTrue,
      );
      expect(
        segments.map((row) => row[1]).where((cell) => cell.isNotEmpty).join(),
        narrative,
      );
    });

    test('plant disruption timestamps use the device local timezone', () {
      final startedAt = DateTime.utc(2026, 8, 29, 23, 45);
      final resolvedAt = startedAt.add(const Duration(hours: 2));
      final asOf = startedAt.add(const Duration(hours: 1));
      final format = DateFormat('dd MMM yyyy, HH:mm');

      final closed =
          OperationsReportPdfService.plantDisruptionTimeCellsForTesting(
            startedAt: startedAt,
            resolvedAt: resolvedAt,
            asOf: asOf,
            isOpen: false,
          );
      final open =
          OperationsReportPdfService.plantDisruptionTimeCellsForTesting(
            startedAt: startedAt,
            resolvedAt: resolvedAt,
            asOf: asOf,
            isOpen: true,
          );

      expect(closed[0], format.format(startedAt.toLocal()));
      expect(closed[1], format.format(resolvedAt.toLocal()));
      expect(open[1], 'Open at ${format.format(asOf.toLocal())}');
    });

    test('planned-work lifecycle dates use the device local timezone', () {
      final assignedAt = DateTime.utc(2026, 8, 29, 23, 45);
      final completedAt = assignedAt.add(const Duration(hours: 2));
      final job =
          JobExecution()
            ..createdAt = assignedAt
            ..completedAt = completedAt;
      final format = DateFormat('dd MMM yyyy');

      expect(
        OperationsReportPdfService.plannedJobLifecycleDateCellsForTesting(job),
        <String>[
          format.format(assignedAt.toLocal()),
          format.format(completedAt.toLocal()),
        ],
      );
    });

    test('Burner observation timestamps use the device local timezone', () {
      final observedAt = DateTime.utc(2026, 8, 29, 23, 45);
      final format = DateFormat('dd MMM yyyy, HH:mm');

      expect(
        OperationsReportPdfService.burnerObservationTimeForTesting(observedAt),
        format.format(observedAt.toLocal()),
      );
    });

    test('generated PDF has a valid document signature', () async {
      final generatedAt = DateTime.utc(2026, 8, 29, 10, 11, 12);
      final report = OperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 29),
        ),
        asOf: generatedAt,
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
      final request = OperationsReportDocumentRequest.forPreset(
        preset: OperationsReportDocumentPreset.complete,
        generatedAt: generatedAt,
        generatedByName: 'Test Supervisor',
        generatedByEmail: 'supervisor@example.com',
      );

      final bytes = await OperationsReportPdfService.build(
        report: report,
        request: request,
        assetClassLabel: 'All asset classes',
        assetLabel: 'All assets in scope',
        furnaceAssets: const [],
        currentBurnerRounds: const {},
      );

      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    });

    test('large maintenance report paginates without overflow', () async {
      final generatedAt = DateTime.utc(2026, 8, 29, 10, 11, 12);
      final longNarrative =
          '${List<String>.filled(120, 'full retained maintenance narrative').join(' ')} '
          'FINAL-RETAINED-EVIDENCE';
      final tickets = List<MaintenanceRecord>.generate(
        120,
        (index) =>
            MaintenanceRecord()
              ..firestoreId = 'pagination-$index'
              ..assetType = AssetType.furnace
              ..assetNumber = (index % 26) + 1
              ..maintenanceType = MaintenanceType.breakdown
              ..description =
                  index == 0
                      ? longNarrative
                      : 'Governed maintenance summary row $index with enough '
                          'narrative content to exercise wrapping and bounded '
                          'table pagination.'
              ..routedTo = RoutedTo.mechanical
              ..status = TicketStatus.resolved
              ..isResolved = true
              ..startDate = generatedAt.subtract(Duration(hours: index + 2))
              ..endDate = generatedAt.subtract(Duration(hours: index + 1))
              ..createdAt = generatedAt.subtract(Duration(hours: index + 2))
              ..updatedAt = generatedAt.subtract(Duration(hours: index + 1)),
        growable: false,
      );
      final report = OperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 29),
        ),
        asOf: generatedAt,
        tickets: tickets,
        executions: const [],
        events: const [],
        eventOccurrences: const [],
        dueStates: const [],
        inspectionFindings: const [],
        assetStates: const [],
        classSummaries: const [],
        topComponents: const [],
        topSubsystemPaths: const [],
        sourceTicketCount: tickets.length,
        sourceExecutionCount: 0,
        sourceEventCount: 0,
        sourceDueStateCount: 0,
        sourceInspectionFindingCount: 0,
        disruptionCount: 0,
        openDisruptionCount: 0,
        disruptionDuration: Duration.zero,
      );
      final request = OperationsReportDocumentRequest.forPreset(
        preset: OperationsReportDocumentPreset.custom,
        generatedAt: generatedAt,
        generatedByName: 'Test Supervisor',
        generatedByEmail: 'supervisor@example.com',
      ).copyWith(
        sections: const <OperationsReportSection>{
          OperationsReportSection.maintenanceIssues,
        },
      );

      final bytes = await OperationsReportPdfService.build(
        report: report,
        request: request,
        assetClassLabel: 'All asset classes',
        assetLabel: 'All assets in scope',
        furnaceAssets: const [],
        currentBurnerRounds: const {},
      );

      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(20000));
    });

    testWidgets('report composer remains usable at narrow phone width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      OperationsReportDocumentRequest? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => Center(
                    child: FilledButton(
                      onPressed: () async {
                        result = await showOperationsReportComposer(
                          context: context,
                          generatedByName: 'Test Supervisor',
                          generatedByEmail: 'supervisor@example.com',
                          hasFurnaceScope: true,
                          provenance:
                              const ReportProvenance.applicationSnapshot(),
                        );
                      },
                      child: const Text('Open composer'),
                    ),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open composer'));
      await tester.pumpAndSettle();

      expect(find.text('Report library'), findsOneWidget);
      expect(find.text('Build preview'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Reliability and condition'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reliability and condition'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build preview'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(
        result!.sections,
        contains(OperationsReportSection.burnerUvCondition),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
