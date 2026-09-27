import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_event_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/reports/domain/operations_report_document.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/domain/structured_report_document.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/services/operations_report_pdf_service.dart';
import 'package:crm3_baf_ops/features/reports/services/planned_job_report_loader.dart';

final _time = DateTime.utc(2026, 9, 26, 4);
JobExecution _job() => JobExecution()
  ..firestoreId = 'planned-demo'
  ..templateFirestoreId = 'template-demo'
  ..templateName = 'Furnace condition and servicing'
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..createdAt = _time
  ..updatedAt = _time
  ..workflowSchemaVersion = 1
  ..remarks = 'Full work evidence retained.';
JobModuleInstance _module(String parent) => JobModuleInstance()
  ..firestoreId = 'module-demo'
  ..jobExecutionFirestoreId = parent
  ..moduleTitle = 'Removed module with retained physical work'
  ..moduleCode = 'FURNACE-UV'
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..discipline = JobModuleDiscipline.instrumentation
  ..createdAt = _time
  ..updatedAt = _time
  ..isDeleted = true
  ..deletedAt = _time
  ..deletedByName = 'Demo Supervisor'
  ..deleteReason = 'Superseded while preserving recorded evidence.';
JobDiaryEntry _entry(String parent) => JobDiaryEntry()
  ..firestoreId = 'diary-demo'
  ..jobExecutionFirestoreId = parent
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..kind = JobDiaryKind.observation
  ..discipline = JobDiaryDiscipline.instrumentation
  ..title = 'UV detector servicing'
  ..note =
      '${List.filled(30, 'Detector cleaned, flame signal inspected and physical connections verified.').join(' ')} FINAL-PLANNED-WORK-EVIDENCE'
  ..createdAt = _time
  ..updatedAt = _time
  ..createdByName = 'Demo Technician'
  ..isDeleted = true
  ..deletedAt = _time
  ..deletedByName = 'Demo Supervisor'
  ..deleteReason = 'Correction retained';

class _Planned implements PlannedMaintenanceRepository {
  int reads = 0;
  bool changeBefore = false;
  bool changeDuring = false;
  @override
  Future<JobExecution?> getExecutionByFirestoreId(String id) async {
    reads++;
    final value = _job();
    if (changeBefore || changeDuring && reads > 1) value.version++;
    return value;
  }

  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String id) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Modules implements JobModuleRepository {
  String parent = 'planned-demo';
  bool? includedRemoved;
  int? requestedLimit;
  bool fail = false;
  @override
  Future<List<JobModuleInstance>> getModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
    bool includeDeleted = false,
  }) async {
    includedRemoved = includeDeleted;
    requestedLimit = limit;
    if (fail) throw StateError('Module source unavailable');
    return [_module(parent)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Diary implements JobDiaryRepository {
  bool? includedRemoved;
  int? requestedLimit;
  @override
  Future<List<JobDiaryEntry>> getEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
    bool includeDeleted = false,
  }) async {
    includedRemoved = includeDeleted;
    requestedLimit = limit;
    return [_entry(jobExecutionFirestoreId!)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workflow implements WorkflowRepository {
  final reads = <String>[];
  @override
  Stream<List<JobLaneRecord>> watchLanes(String id) {
    reads.add('lanes:$id');
    return Stream.value([]);
  }

  @override
  Stream<List<ComplianceRequestRecord>> watchCompliance(String id) {
    reads.add('compliance:$id');
    return Stream.value([]);
  }

  @override
  Stream<List<WorkflowEventRecord>> watchEvents(String id) {
    reads.add('events:$id');
    return Stream.value([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<StructuredReportDocument> _load(
  _Modules modules,
  _Diary diary,
  _Workflow workflow,
) => loadPlannedJobReport(
  execution: _job(),
  plannedRepository: _Planned(),
  moduleRepository: modules,
  diaryRepository: diary,
  workflowRepository: workflow,
  generatedAt: _time,
  generatedByName: 'Demo validation',
  provenance: const ReportProvenance.applicationSnapshot(),
);
OperationsReport _report() => OperationsReport(
  filter: OperationsReportFilter(
    startDate: _time,
    endDate: _time,
    includeMaintenanceDetails: true,
  ),
  asOf: _time,
  tickets: [],
  executions: [_job()],
  events: [],
  eventOccurrences: [],
  dueStates: [],
  inspectionFindings: [],
  assetStates: [],
  classSummaries: [],
  topComponents: [],
  topSubsystemPaths: [],
  sourceTicketCount: 0,
  sourceExecutionCount: 1,
  sourceEventCount: 0,
  sourceDueStateCount: 0,
  sourceInspectionFindingCount: 0,
  disruptionCount: 0,
  openDisruptionCount: 0,
  disruptionDuration: Duration.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'shared loader preserves removed module and diary evidence and all workflow families',
    () async {
      final modules = _Modules();
      final diary = _Diary();
      final workflow = _Workflow();
      final doc = await _load(modules, diary, workflow);
      expect(modules.includedRemoved, true);
      expect(diary.includedRemoved, true);
      expect(modules.requestedLimit, isNull);
      expect(diary.requestedLimit, isNull);
      expect(workflow.reads, [
        'lanes:planned-demo',
        'compliance:planned-demo',
        'events:planned-demo',
      ]);
      final cells = doc.sections
          .expand((s) => s.tables)
          .expand((t) => t.rows)
          .expand((r) => r)
          .join(' ');
      expect(cells, contains('FINAL-PLANNED-WORK-EVIDENCE'));
      expect(cells, contains('Superseded while preserving recorded evidence.'));
    },
  );
  test(
    'failed child source blocks detail, rather than producing an empty dossier',
    () async {
      await expectLater(
        _load(_Modules()..fail = true, _Diary(), _Workflow()),
        throwsStateError,
      );
    },
  );
  test(
    'foreign-parent child evidence cannot enter a selected job dossier',
    () async {
      await expectLater(
        _load(_Modules()..parent = 'different-job', _Diary(), _Workflow()),
        throwsStateError,
      );
    },
  );
  for (final during in [false, true]) {
    test(
      'changed execution ${during ? "during" : "before"} detail read refuses mixed snapshot',
      () async {
        final planned = _Planned()
          ..changeBefore = !during
          ..changeDuring = during;
        await expectLater(
          loadPlannedJobReport(
            execution: _job(),
            plannedRepository: planned,
            moduleRepository: _Modules(),
            diaryRepository: _Diary(),
            workflowRepository: _Workflow(),
            generatedAt: _time,
            generatedByName: 'Demo',
            provenance: const ReportProvenance.applicationSnapshot(),
          ),
          throwsStateError,
        );
      },
    );
  }
  test(
    'bulk PDF refuses omitted job detail and renders complete supplied detail',
    () async {
      final report = _report();
      final request = OperationsReportDocumentRequest.forPreset(
        preset: OperationsReportDocumentPreset.maintenance,
        generatedAt: _time,
        generatedByName: 'Local demo validation',
        generatedByEmail: 'demo@example.invalid',
      );
      await expectLater(
        OperationsReportPdfService.build(
          report: report,
          request: request,
          assetClassLabel: 'Furnace',
          assetLabel: 'Furnace 7',
          furnaceAssets: [],
          currentBurnerRounds: {},
        ),
        throwsStateError,
      );
      final detail = await _load(_Modules(), _Diary(), _Workflow());
      final bytes = await OperationsReportPdfService.build(
        report: report,
        request: request,
        assetClassLabel: 'Furnace',
        assetLabel: 'Furnace 7',
        furnaceAssets: [],
        currentBurnerRounds: {},
        plannedJobDetails: [detail],
      );
      expect(bytes.length, greaterThan(5000));
      Directory('output/dev-usability-20260926').createSync(recursive: true);
      File(
        'output/dev-usability-20260926/sample-planned-details.pdf',
      ).writeAsBytesSync(bytes);
    },
  );
}
