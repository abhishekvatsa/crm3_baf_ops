import 'dart:convert';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/reports/domain/planned_job_dossier.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/services/structured_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('planned maintenance dossier', () {
    test('preserves execution, module and diary evidence in a PDF', () async {
      final createdAt = DateTime.utc(2026, 8, 28, 8);
      final execution = _execution(createdAt);
      final module =
          JobModuleInstance()
            ..firestoreId = 'module-1'
            ..jobExecutionFirestoreId = 'execution-1'
            ..moduleTitle = 'Burner block condition'
            ..moduleCode = 'F-BB-01'
            ..assetType = AssetType.furnace
            ..assetNumber = 1
            ..status = JobModuleStatus.accepted
            ..discipline = JobModuleDiscipline.mechanical
            ..createdAt = createdAt.add(const Duration(hours: 1))
            ..updatedAt = createdAt.add(const Duration(hours: 2))
            ..acceptedAt = createdAt.add(const Duration(hours: 2))
            ..acceptedByName = 'Shift Supervisor'
            ..isSynced = true;
      final diary =
          JobDiaryEntry()
            ..firestoreId = 'diary-1'
            ..jobExecutionFirestoreId = 'execution-1'
            ..assetType = AssetType.furnace
            ..assetNumber = 1
            ..kind = JobDiaryKind.observation
            ..discipline = JobDiaryDiscipline.instrumentation
            ..title = 'UV detector checked'
            ..note = 'Flame signal remained stable after cleaning.'
            ..createdByName = 'I&A Technician'
            ..createdAt = createdAt.add(const Duration(minutes: 30))
            ..updatedAt = createdAt.add(const Duration(minutes: 30))
            ..isSynced = true;

      final report = buildPlannedJobDossier(
        execution: execution,
        template: null,
        modules: <JobModuleInstance>[module],
        diaryEntries: <JobDiaryEntry>[diary],
        workflowLanes: const [],
        complianceRequests: const [],
        workflowEvents: const [],
        generatedAt: DateTime.utc(2026, 8, 29, 12),
        generatedByName: 'Admin User',
        provenance: const ReportProvenance.applicationSnapshot(),
      );

      expect(
        report.sections.map((section) => section.title),
        containsAll(<String>[
          'Execution identity and status',
          'Runtime modules',
          'Job diary chronology',
          'Governed lanes and compliance',
          'Record assurance',
        ]),
      );
      final bytes = await StructuredReportPdfService.build(report);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    });

    test('rejects malformed execution action evidence', () {
      final execution = _execution(DateTime.utc(2026, 8, 28, 8));
      execution.actionsJson = '{not-an-array}';

      expect(
        () => buildPlannedJobDossier(
          execution: execution,
          template: null,
          modules: const [],
          diaryEntries: const [],
          workflowLanes: const [],
          complianceRequests: const [],
          workflowEvents: const [],
          generatedAt: DateTime.utc(2026, 8, 29, 12),
          generatedByName: 'Admin User',
          provenance: const ReportProvenance.applicationSnapshot(),
        ),
        throwsStateError,
      );
    });

    test('retains evidence beyond screen limits and removed child records', () {
      final createdAt = DateTime.utc(2026, 8, 28, 8);
      final modules = List<JobModuleInstance>.generate(101, (index) {
        final module =
            JobModuleInstance()
              ..id = index + 1
              ..firestoreId = 'module-${index + 1}'
              ..jobExecutionFirestoreId = 'execution-1'
              ..moduleTitle = 'Module evidence ${index + 1}'
              ..moduleCode = 'M-${index + 1}'
              ..assetType = AssetType.furnace
              ..assetNumber = 1
              ..status = JobModuleStatus.inProgress
              ..discipline = JobModuleDiscipline.mechanical
              ..createdAt = createdAt.add(Duration(minutes: index))
              ..updatedAt = createdAt.add(Duration(minutes: index))
              ..isSynced = true;
        if (index == 100) {
          module
            ..isDeleted = true
            ..deletedAt = createdAt.add(const Duration(hours: 3))
            ..deletedByName = 'Maintenance Supervisor'
            ..deleteReason = 'Removed after governed correction.';
        }
        return module;
      });
      final diaryEntries = List<JobDiaryEntry>.generate(51, (index) {
        final entry =
            JobDiaryEntry()
              ..id = index + 1
              ..firestoreId = 'diary-${index + 1}'
              ..jobExecutionFirestoreId = 'execution-1'
              ..assetType = AssetType.furnace
              ..assetNumber = 1
              ..kind = JobDiaryKind.note
              ..discipline = JobDiaryDiscipline.shared
              ..title = 'Diary evidence ${index + 1}'
              ..note = 'Preserved report evidence ${index + 1}'
              ..createdByName = 'Maintenance User'
              ..createdAt = createdAt.add(Duration(minutes: index))
              ..updatedAt = createdAt.add(Duration(minutes: index))
              ..isSynced = true;
        if (index == 50) {
          entry
            ..isDeleted = true
            ..deletedAt = createdAt.add(const Duration(hours: 3))
            ..deletedByName = 'Maintenance Supervisor'
            ..deleteReason = 'Removed after governed correction.';
        }
        return entry;
      });

      final report = buildPlannedJobDossier(
        execution: _execution(createdAt),
        template: null,
        modules: modules,
        diaryEntries: diaryEntries,
        workflowLanes: const [],
        complianceRequests: const [],
        workflowEvents: const [],
        generatedAt: DateTime.utc(2026, 8, 29, 12),
        generatedByName: 'Admin User',
        provenance: const ReportProvenance.applicationSnapshot(),
      );

      final moduleSection = report.sections.singleWhere(
        (section) => section.title == 'Runtime modules',
      );
      final diarySection = report.sections.singleWhere(
        (section) => section.title == 'Job diary chronology',
      );
      expect(moduleSection.tables.first.rows, hasLength(101));
      expect(
        moduleSection.tables.first.rows.last.last,
        contains('Removed after governed correction.'),
      );
      expect(diarySection.tables.single.rows, hasLength(51));
      expect(
        diarySection.tables.single.rows.last[4],
        contains('Removed after governed correction.'),
      );
    });
  });
}

JobExecution _execution(DateTime createdAt) =>
    JobExecution()
      ..firestoreId = 'execution-1'
      ..templateFirestoreId = 'template-1'
      ..templateName = 'Furnace planned maintenance'
      ..assetType = AssetType.furnace
      ..assetNumber = 1
      ..assignedByName = 'Planner'
      ..assignedAgencies = <String>['mechanical', 'instrumentation']
      ..createdAt = createdAt
      ..updatedAt = createdAt.add(const Duration(hours: 2))
      ..isSynced = true;
