import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../maintenance_workflow/data/compliance_request_record.dart';
import '../../maintenance_workflow/data/job_lane_record.dart';
import '../../maintenance_workflow/data/workflow_event_record.dart';
import '../../maintenance_workflow/repositories/workflow_repository.dart';
import '../../planned_maintenance/data/job_diary_model.dart';
import '../../planned_maintenance/data/job_module_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/providers/job_diary_provider.dart';
import '../../planned_maintenance/providers/job_module_provider.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../domain/planned_job_dossier.dart';
import '../domain/report_provenance.dart';
import '../domain/structured_report_document.dart';

/// Shared by the single-job dossier and the period register. Child evidence is
/// uncapped, includes removed modules/diary rows, and is validated against the
/// selected parent by the existing dossier builder. Any failed read blocks the
/// document instead of substituting an empty list.
Future<StructuredReportDocument> loadPlannedJobReport({
  required JobExecution execution,
  JobTemplate? template,
  required PlannedMaintenanceRepository plannedRepository,
  required JobModuleRepository moduleRepository,
  required JobDiaryRepository diaryRepository,
  required WorkflowRepository workflowRepository,
  List<JobLaneRecord>? workflowLanes,
  List<ComplianceRequestRecord>? complianceRequests,
  List<WorkflowEventRecord>? workflowEvents,
  required DateTime generatedAt,
  required String generatedByName,
  required ReportProvenance provenance,
}) async {
  final rawId = execution.firestoreId?.trim();
  final id = rawId == null || rawId.isEmpty ? null : rawId;
  final workflow = execution.workflowSchemaVersion == 1;
  if (workflow && id == null) {
    throw StateError('A governed planned job has no verified parent identity.');
  }
  final selectedEvidence = jsonEncode(execution.toMap());
  Future<void> requireSameExecution() async {
    final JobExecution? current;
    if (id != null) {
      current = await plannedRepository.getExecutionByFirestoreId(id);
    } else {
      final matches = (await plannedRepository.getAllExecutions())
          .where((row) => row.id == execution.id && row.firestoreId == null)
          .toList();
      current = matches.length == 1 ? matches.single : null;
    }
    if (current == null ||
        current.isDeleted ||
        jsonEncode(current.toMap()) != selectedEvidence ||
        jsonEncode(execution.toMap()) != selectedEvidence) {
      throw StateError(
        'The selected planned job changed or disappeared during report preparation. Create a fresh report.',
      );
    }
  }

  await requireSameExecution();
  final results = await Future.wait<Object?>([
    template != null
        ? Future.value(template)
        : plannedRepository.getTemplateByFirestoreId(
            execution.templateFirestoreId,
          ),
    moduleRepository.getModulesForJob(
      jobExecutionFirestoreId: id,
      jobExecutionLocalId: kIsWeb ? null : execution.id,
      includeDeleted: true,
    ),
    diaryRepository.getEntriesForJob(
      jobExecutionFirestoreId: id,
      jobExecutionLocalId: kIsWeb ? null : execution.id,
      includeDeleted: true,
    ),
    workflowLanes != null
        ? Future.value(workflowLanes)
        : workflow
        ? workflowRepository.watchLanes(id!).first
        : Future.value(<JobLaneRecord>[]),
    complianceRequests != null
        ? Future.value(complianceRequests)
        : workflow
        ? workflowRepository.watchCompliance(id!).first
        : Future.value(<ComplianceRequestRecord>[]),
    workflowEvents != null
        ? Future.value(workflowEvents)
        : workflow
        ? workflowRepository.watchEvents(id!).first
        : Future.value(<WorkflowEventRecord>[]),
  ]);
  await requireSameExecution();
  return buildPlannedJobDossier(
    execution: execution,
    template: results[0] as JobTemplate?,
    modules: results[1] as List<JobModuleInstance>,
    diaryEntries: results[2] as List<JobDiaryEntry>,
    workflowLanes: results[3] as List<JobLaneRecord>,
    complianceRequests: results[4] as List<ComplianceRequestRecord>,
    workflowEvents: results[5] as List<WorkflowEventRecord>,
    generatedAt: generatedAt,
    generatedByName: generatedByName,
    provenance: provenance,
  );
}
