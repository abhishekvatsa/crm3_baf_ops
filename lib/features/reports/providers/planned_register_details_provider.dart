import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../planned_maintenance/providers/job_diary_provider.dart';
import '../../planned_maintenance/providers/job_module_provider.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../domain/report_provenance.dart';
import '../domain/structured_report_document.dart';
import '../models/operations_report.dart';
import '../services/planned_job_report_loader.dart';

final plannedRegisterDetailsProvider = FutureProvider.autoDispose
    .family<
      List<StructuredReportDocument>,
      ({String actorUid, OperationsReport report})
    >((ref, scope) async {
      final actor = ref.watch(currentAppUserProvider).asData?.value;
      if (actor?.uid != scope.actorUid || actor?.canViewReports != true) {
        throw StateError('Approved report access is required.');
      }
      if (scope.report.executions.isEmpty) return const [];
      final planned = ref.watch(plannedRepositoryProvider);
      final modules = ref.watch(jobModuleRepositoryProvider);
      final diary = ref.watch(jobDiaryRepositoryProvider);
      final workflow = ref.watch(workflowRepositoryProvider);
      var cancelled = false;
      ref.onDispose(() => cancelled = true);
      final result = <StructuredReportDocument>[];
      // Bound concurrent reads to one job's families; never cap the job population.
      for (final execution in scope.report.executions) {
        if (cancelled) throw StateError("Report preparation was cancelled.");
        result.add(
          await loadPlannedJobReport(
            execution: execution,
            plannedRepository: planned,
            moduleRepository: modules,
            diaryRepository: diary,
            workflowRepository: workflow,
            generatedAt: scope.report.asOf,
            generatedByName: actor!.name,
            provenance: const ReportProvenance.applicationSnapshot(),
          ),
        );
      }
      if (cancelled) throw StateError("Report preparation was cancelled.");
      return List.unmodifiable(result);
    });
