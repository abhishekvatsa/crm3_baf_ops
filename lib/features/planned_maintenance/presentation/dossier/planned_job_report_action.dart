part of '../planned_job_detail_screen.dart';

class _PlannedJobReportAction extends ConsumerStatefulWidget {
  const _PlannedJobReportAction({
    required this.execution,
    required this.template,
    required this.actor,
    required this.templateLoading,
  });

  final JobExecution execution;
  final JobTemplate? template;
  final AppUser actor;
  final bool templateLoading;

  @override
  ConsumerState<_PlannedJobReportAction> createState() =>
      _PlannedJobReportActionState();
}

class _PlannedJobReportActionState
    extends ConsumerState<_PlannedJobReportAction> {
  bool _building = false;

  @override
  Widget build(BuildContext context) {
    final workflowId =
        widget.execution.workflowSchemaVersion == 1
            ? _cleanOptionalString(widget.execution.firestoreId)
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
        (lanes?.hasError ?? false) ||
        (compliance?.hasError ?? false) ||
        (events?.hasError ?? false);
    final ready =
        !widget.templateLoading &&
        laneEvidence != null &&
        complianceEvidence != null &&
        eventEvidence != null;

    return IconButton(
      key: const ValueKey('planned-job-complete-report'),
      tooltip:
          failed
              ? 'Report evidence could not be loaded'
              : _building
              ? 'Loading complete report evidence'
              : ready
              ? 'Preview complete PDF dossier'
              : 'Loading complete report evidence',
      onPressed:
          !ready || _building
              ? null
              : () =>
                  _openReport(laneEvidence, complianceEvidence, eventEvidence),
      icon:
          _building
              ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.picture_as_pdf_outlined),
    );
  }

  Future<void> _openReport(
    List<JobLaneRecord> workflowLanes,
    List<ComplianceRequestRecord> complianceRequests,
    List<WorkflowEventRecord> workflowEvents,
  ) async {
    setState(() => _building = true);
    try {
      final execution = widget.execution;
      final diaryRequest = ref
          .read(jobDiaryRepositoryProvider)
          .getEntriesForJob(
            jobExecutionFirestoreId: _cleanOptionalString(
              execution.firestoreId,
            ),
            jobExecutionLocalId: kIsWeb ? null : execution.id,
            includeDeleted: true,
          );
      final moduleRequest = ref
          .read(jobModuleRepositoryProvider)
          .getModulesForJob(
            jobExecutionFirestoreId: _cleanOptionalString(
              execution.firestoreId,
            ),
            jobExecutionLocalId: kIsWeb ? null : execution.id,
            includeDeleted: true,
          );
      final childEvidence = await Future.wait<Object>(<Future<Object>>[
        diaryRequest,
        moduleRequest,
      ]);
      final diaryEntries = childEvidence[0] as List<JobDiaryEntry>;
      final modules = childEvidence[1] as List<JobModuleInstance>;
      if (!mounted) return;

      final report = buildPlannedJobDossier(
        execution: execution,
        template: widget.template,
        modules: modules,
        diaryEntries: diaryEntries,
        workflowLanes: workflowLanes,
        complianceRequests: complianceRequests,
        workflowEvents: workflowEvents,
        generatedAt: DateTime.now(),
        generatedByName: widget.actor.name,
        provenance: readApplicationReportProvenance(
          ref,
          completenessNotes: const <String>[
            'This dossier preserves the complete locally available execution, '
                'module (including removed modules), diary (including removed '
                'entries), lane, compliance and component-action evidence; its '
                'synchronization and version state are stated in the document.',
          ],
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StructuredReportPdfPreviewScreen(report: report),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The planned-maintenance dossier could not be generated: $error',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _building = false);
      }
    }
  }
}
