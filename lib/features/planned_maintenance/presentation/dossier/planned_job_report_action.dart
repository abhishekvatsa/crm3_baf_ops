part of '../planned_job_detail_screen.dart';

class _PlannedJobReportAction extends ConsumerWidget {
  const _PlannedJobReportAction({
    required this.execution,
    required this.template,
    required this.actor,
    required this.templateLoading,
    required this.diaryEntries,
    required this.modules,
  });

  final JobExecution execution;
  final JobTemplate? template;
  final AppUser actor;
  final bool templateLoading;
  final AsyncValue<List<JobDiaryEntry>> diaryEntries;
  final AsyncValue<List<JobModuleInstance>> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowId =
        execution.workflowSchemaVersion == 1
            ? _cleanOptionalString(execution.firestoreId)
            : null;
    final lanes =
        workflowId == null
            ? null
            : ref.watch(workflowLanesProvider(workflowId));
    final compliance =
        workflowId == null
            ? null
            : ref.watch(workflowComplianceProvider(workflowId));
    final events =
        workflowId == null
            ? null
            : ref.watch(workflowEventsProvider(workflowId));
    final laneEvidence =
        workflowId == null ? const <JobLaneRecord>[] : lanes?.asData?.value;
    final complianceEvidence =
        workflowId == null
            ? const <ComplianceRequestRecord>[]
            : compliance?.asData?.value;
    final eventEvidence =
        workflowId == null
            ? const <WorkflowEventRecord>[]
            : events?.asData?.value;
    final failed =
        diaryEntries.hasError ||
        modules.hasError ||
        (lanes?.hasError ?? false) ||
        (compliance?.hasError ?? false) ||
        (events?.hasError ?? false);
    final ready =
        !templateLoading &&
        diaryEntries.asData != null &&
        modules.asData != null &&
        laneEvidence != null &&
        complianceEvidence != null &&
        eventEvidence != null;

    return IconButton(
      tooltip:
          failed
              ? 'Report evidence could not be loaded'
              : ready
              ? 'Preview complete PDF dossier'
              : 'Loading complete report evidence',
      onPressed:
          !ready
              ? null
              : () => _openReport(
                context,
                ref,
                laneEvidence,
                complianceEvidence,
                eventEvidence,
              ),
      icon: const Icon(Icons.picture_as_pdf_outlined),
    );
  }

  void _openReport(
    BuildContext context,
    WidgetRef ref,
    List<JobLaneRecord> workflowLanes,
    List<ComplianceRequestRecord> complianceRequests,
    List<WorkflowEventRecord> workflowEvents,
  ) {
    try {
      final report = buildPlannedJobDossier(
        execution: execution,
        template: template,
        modules: modules.requireValue,
        diaryEntries: diaryEntries.requireValue,
        workflowLanes: workflowLanes,
        complianceRequests: complianceRequests,
        workflowEvents: workflowEvents,
        generatedAt: DateTime.now(),
        generatedByName: actor.name,
        provenance: readApplicationReportProvenance(
          ref,
          completenessNotes: const <String>[
            'This dossier preserves the complete locally available execution, '
                'module, diary, lane, compliance and component-action evidence; '
                'its synchronization and version state are stated in the document.',
          ],
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StructuredReportPdfPreviewScreen(report: report),
        ),
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The planned-maintenance dossier could not be generated: $error',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }
}
