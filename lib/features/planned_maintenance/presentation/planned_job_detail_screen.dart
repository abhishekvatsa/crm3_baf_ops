// FILE: lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../audit/models/audit_event_model.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../data/baf_module_catalogue_seed.dart';
import '../data/job_diary_model.dart';
import '../data/job_module_model.dart';
import '../data/job_template_model.dart';
import '../data/template_governance_model.dart';
import '../data/maintenance_intelligence.dart';
import '../domain/published_runtime_module_catalogue.dart';
import '../domain/runtime_module_lineage.dart';
import '../models/component_action_model.dart';
import '../providers/job_diary_provider.dart';
import '../providers/job_module_provider.dart';
import '../providers/planned_maintenance_provider.dart';
import '../providers/template_governance_provider.dart';
import '../providers/maintenance_intelligence_provider.dart';
import 'complete_job_screen.dart';
import 'job_module_detail_screen.dart';
import 'widgets/job_module_card.dart';
import 'widgets/job_module_response_summary.dart';

part 'dossier/planned_job_detail_common.dart';
part 'dossier/planned_job_diary_dossier.dart';
part 'dossier/planned_job_module_dossier.dart';

/// Planned-maintenance dossier for legacy and governed job executions.
///
/// Mutation affordances are derived from the current actor. The repositories
/// and server remain the final authority for every submitted action.
class PlannedJobDetailScreen extends ConsumerStatefulWidget {
  final JobExecution execution;

  /// Optional when the caller already has the template, such as from
  /// JobHistoryScreen. If omitted, the screen attempts to load the template by
  /// execution.templateFirestoreId.
  final JobTemplate? template;

  const PlannedJobDetailScreen({
    super.key,
    required this.execution,
    this.template,
  });

  @override
  ConsumerState<PlannedJobDetailScreen> createState() =>
      _PlannedJobDetailScreenState();
}

class _PlannedJobDetailScreenState
    extends ConsumerState<PlannedJobDetailScreen> {
  JobTemplate? _template;
  bool _isLoadingTemplate = true;
  String? _templateLoadError;

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    if (_template != null) {
      _isLoadingTemplate = false;
    } else {
      _loadTemplate();
    }
  }

  Future<void> _loadTemplate() async {
    if (widget.execution.isGovernedTemplateAssignment) {
      if (!mounted) return;
      setState(() {
        _isLoadingTemplate = false;
        _templateLoadError = null;
      });
      return;
    }

    final templateFirestoreId = widget.execution.templateFirestoreId.trim();
    if (templateFirestoreId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingTemplate = false;
        _templateLoadError = 'Template reference missing on this job.';
      });
      return;
    }

    try {
      final template = await ref
          .read(plannedRepositoryProvider)
          .getTemplateByFirestoreId(templateFirestoreId);
      if (!mounted) return;
      setState(() {
        _template = template;
        _isLoadingTemplate = false;
        _templateLoadError = template == null ? 'Template not found.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTemplate = false;
        _templateLoadError = 'Could not load template: $e';
      });
    }
  }

  Future<void> _openCompletionScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteJobScreen(execution: widget.execution),
      ),
    );
  }

  Future<void> _classifyMaintenance(
    List<MaintenanceClassDefinition> definitions,
  ) async {
    final execution = widget.execution;
    final applicable = definitions
        .where(
          (definition) => definition.appliesTo(
            assetTypeKey: execution.assetType.name,
            assetClassId: _assetClassIdFromMetadata(execution.metadataJson),
          ),
        )
        .toList(growable: false);
    if (applicable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active maintenance class applies to this asset.'),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }
    String? selectedId = applicable.first.id;
    final reason = TextEditingController(
      text:
          execution.isCompleted
              ? 'Classify completed maintenance against its actual completion time.'
              : 'Classify this maintenance before completion.',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    execution.isCompleted
                        ? 'Classify completed work'
                        : 'Classify maintenance',
                  ),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Maintenance class',
                          ),
                          items:
                              applicable
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(item.title),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) =>
                                  setDialogState(() => selectedId = value),
                        ),
                        const SizedBox(height: BafSpacing.md),
                        TextField(
                          controller: reason,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Classification reason',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
          ),
    );
    final selected =
        applicable.where((item) => item.id == selectedId).firstOrNull;
    final rationale = reason.text.trim();
    reason.dispose();
    if (confirmed != true ||
        selected == null ||
        rationale.length < 5 ||
        !mounted) {
      return;
    }
    try {
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(
            WorkflowCommand(
              commandId: 'classifyMaintenanceExecution_${const Uuid().v4()}',
              type: WorkflowCommandType.classifyMaintenanceExecution,
              aggregateId: execution.firestoreId!.trim(),
              expectedVersion: execution.version,
              payload: {
                'definitionId': selected.id,
                'definitionVersion': selected.version,
                'reason': rationale,
              },
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            execution.isCompleted
                ? 'Completion classified at its original completion time.'
                : 'Maintenance class frozen into this execution.',
          ),
          backgroundColor: BafColors.sync,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not classify maintenance: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  Future<void> _openAddDiaryEntrySheet() async {
    AppUser? actor;
    try {
      actor = await ref.read(currentAppUserProvider.future);
    } catch (_) {
      actor = null;
    }

    if (!mounted) return;

    if (actor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify the signed-in user.')),
      );
      return;
    }

    if (!actor.canCreateJobDiaryEntry) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are not authorized to create planned-job diary entries.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final draft = await showModalBottomSheet<_DiaryEntryDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BafRadius.large),
        ),
      ),
      builder: (sheetContext) {
        return _AddDiaryEntrySheet(
          initialDiscipline: _disciplineForUser(actor!),
        );
      },
    );

    if (!mounted || draft == null) return;

    final execution = widget.execution;
    final now = DateTime.now();
    final entry =
        JobDiaryEntry()
          ..jobExecutionFirestoreId = _cleanOptionalString(
            execution.firestoreId,
          )
          ..jobExecutionLocalId = kIsWeb ? null : execution.id
          ..assetType = execution.assetType
          ..assetNumber = execution.assetNumber
          ..chargeNoAtEvent = execution.chargeNoAtEvent
          ..templateFirestoreId = _cleanOptionalString(
            execution.templateFirestoreId,
          )
          ..templateName = _cleanOptionalString(
            execution.templateName ?? _template?.jobName,
          )
          ..kind = draft.kind
          ..discipline = draft.discipline
          ..severity = draft.severity
          ..isBlocker = draft.kind == JobDiaryKind.blocker
          ..isHandover = draft.kind == JobDiaryKind.handover
          ..blockerStatus =
              draft.kind == JobDiaryKind.blocker ? JobBlockerStatus.open : null
          ..functionalSection = draft.functionalSection
          ..componentGroup = draft.componentGroup
          ..targetRef = draft.targetRef
          ..procedureRef = draft.procedureRef
          ..title = draft.title
          ..note = draft.note
          ..actionTaken = draft.actionTaken
          ..pendingIssue = draft.pendingIssue
          ..requiresFollowUp = draft.requiresFollowUp
          ..createdByUid = actor.uid
          ..createdByName = actor.name
          ..createdAt = now
          ..updatedByUid = actor.uid
          ..updatedByName = actor.name
          ..updatedAt = now;

    try {
      await ref
          .read(jobDiaryRepositoryProvider)
          .saveEntry(
            entry,
            actor: actor,
            auditContext: AuditContext(
              performedByUid: actor.uid,
              performedByName: actor.name,
              summary: 'Added planned-maintenance diary entry',
            ),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diary entry saved'),
          backgroundColor: BafColors.sync,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save diary entry: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  Future<void> _openModuleWorkspace(JobModuleInstance module) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => JobModuleDetailScreen(
              execution: widget.execution,
              module: module,
            ),
      ),
    );
  }

  Future<_PublishedRuntimeCatalogueLoad> _loadPublishedRuntimeCatalogue({
    required JobExecution execution,
    required List<JobModuleInstance> currentModules,
  }) async {
    if (!execution.isGovernedTemplateAssignment) {
      return const _PublishedRuntimeCatalogueLoad(candidates: []);
    }

    final versionId = _cleanOptionalString(execution.templateVersionId);
    if (versionId == null) {
      return const _PublishedRuntimeCatalogueLoad(
        candidates: [],
        errorMessage:
            'Published TemplateVersion reference is missing on this job.',
      );
    }

    try {
      final governanceRepo = ref.read(templateGovernanceRepositoryProvider);
      final version = await governanceRepo.getVersionByFirestoreId(versionId);
      if (version == null) {
        return _PublishedRuntimeCatalogueLoad(
          candidates: const [],
          errorMessage:
              'Published TemplateVersion $versionId was not found locally.',
        );
      }

      TemplatePackage? package;
      final packageId =
          _cleanOptionalString(version.packageFirestoreId) ??
          _cleanOptionalString(execution.templatePackageId);
      if (packageId != null) {
        package = await governanceRepo.getPackageByFirestoreId(packageId);
      }

      final candidates = publishedRuntimeModuleCandidatesFromVersion(
        version: version,
        package: package,
        assetType: execution.assetType,
        existingModuleCodes:
            currentModules
                .map((module) => module.moduleCode?.trim())
                .whereType<String>()
                .where((code) => code.isNotEmpty)
                .toSet(),
        existingTemplateModuleIds:
            currentModules
                .map((module) => module.templateModuleId?.trim() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet(),
      );

      return _PublishedRuntimeCatalogueLoad(candidates: candidates);
    } catch (error) {
      return _PublishedRuntimeCatalogueLoad(
        candidates: const [],
        errorMessage: 'Could not load published runtime-add catalogue: $error',
      );
    }
  }

  Future<void> _openAddJobModuleSheet(
    List<JobModuleInstance> currentModules,
  ) async {
    AppUser? actor;
    try {
      actor = await ref.read(currentAppUserProvider.future);
    } catch (_) {
      actor = null;
    }

    if (!mounted) return;

    if (actor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify the signed-in user.')),
      );
      return;
    }

    if (!actor.canAddJobModuleDuringExecution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authorized to add process modules to this job.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final execution = widget.execution;
    final publishedCatalogue = await _loadPublishedRuntimeCatalogue(
      execution: execution,
      currentModules: currentModules,
    );

    if (!mounted) return;

    JobModuleInstance? module;
    String? auditSummary;
    String? snackText;

    if (publishedCatalogue.candidates.isNotEmpty) {
      final publishedDraft =
          await showModalBottomSheet<_PublishedRuntimeModuleDraft>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: BafColors.card,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(BafRadius.large),
              ),
            ),
            builder: (sheetContext) {
              return _AddPublishedRuntimeModuleSheet(
                candidates: publishedCatalogue.candidates,
                actor: actor!,
              );
            },
          );

      if (!mounted || publishedDraft == null) return;

      if (!publishedDraft.useEmergencyManualFallback) {
        final candidate = publishedDraft.candidate;
        if (candidate == null) return;
        final now = DateTime.now();
        module = candidate.toJobModuleInstance(
          execution: execution,
          actor: actor,
          now: now,
          addReason: publishedDraft.addReason,
          displayOrderOverride: now.millisecondsSinceEpoch,
        );
        if (kIsWeb) module.jobExecutionLocalId = null;
        auditSummary =
            'Added published governed runtime module ${candidate.moduleCode}';
        snackText = 'Added published governed module ${candidate.moduleCode}';
      }
    } else if (publishedCatalogue.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publishedCatalogue.errorMessage!),
          backgroundColor: BafColors.warning,
        ),
      );
    }

    if (module == null) {
      final draft = await showModalBottomSheet<_JobModuleDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: BafColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BafRadius.large),
          ),
        ),
        builder: (sheetContext) {
          return _AddJobModuleSheet(
            assetType: execution.assetType,
            initialDiscipline: _moduleDisciplineForUser(actor!),
            actor: actor,
            isGovernedTemplateAssignment:
                execution.isGovernedTemplateAssignment,
          );
        },
      );

      if (!mounted || draft == null) return;

      final now = DateTime.now();
      module = draft.seed.toJobModuleInstance(
        parentAssetType: execution.assetType,
        parentAssetNumber: execution.assetNumber,
        discipline: draft.discipline,
        useMode: draft.useMode,
        requiredForClosure: draft.requiredForClosure,
        addedDuringExecution: true,
        actorUid: actor.uid,
        actorName: actor.name,
        now: now,
        jobExecutionFirestoreId: _cleanOptionalString(execution.firestoreId),
        jobExecutionLocalId: kIsWeb ? null : execution.id,
        chargeNoAtEvent: execution.chargeNoAtEvent,
        templateFirestoreId: _cleanOptionalString(
          execution.templateFirestoreId,
        ),
        templateName: _cleanOptionalString(
          execution.templateName ?? _template?.jobName,
        ),
        addReason: draft.addReason,
        displayOrder: now.millisecondsSinceEpoch,
      );
      auditSummary =
          'Added Emergency/manual seed process module ${draft.seed.moduleCode}';
      snackText = 'Added Emergency/manual seed module ${draft.seed.moduleCode}';
    }

    final moduleToSave = module;
    final summaryToAudit = auditSummary ?? 'Added process module';
    final messageToShow = snackText ?? 'Added process module';

    try {
      await ref
          .read(jobModuleRepositoryProvider)
          .saveModule(
            moduleToSave,
            actor: actor,
            auditContext: AuditContext(
              performedByUid: actor.uid,
              performedByName: actor.name,
              summary: summaryToAudit,
            ),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageToShow), backgroundColor: BafColors.sync),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add process module: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final execution = widget.execution;
    final actionRead = execution.actionsReadResult;
    final responseRead = execution.responsesReadResult;
    final innerCoverPositionRead =
        execution.assignmentInnerCoverPositionReadResult;
    final actor = ref.watch(currentAppUserProvider).value;
    final maintenanceClasses =
        ref.watch(maintenanceClassDefinitionsProvider).value ??
        const <MaintenanceClassDefinition>[];
    final frozenMaintenanceClass = _maintenanceClassFromMetadata(
      execution.metadataJson,
    );
    final canClassify =
        _hasText(execution.firestoreId) &&
        (execution.isCompleted
            ? actor?.canClassifyCompletedMaintenance ?? false
            : actor?.canClassifyOpenMaintenance ?? false);
    final canAddDiaryEntry = actor?.canCreateJobDiaryEntry ?? false;
    final canAddModule = actor?.canAddJobModuleDuringExecution ?? false;
    final canCompleteJob =
        (actor?.canCompleteJobExecution ?? false) &&
        actionRead.isValid &&
        responseRead.isValid &&
        innerCoverPositionRead.isValid;
    final showBottomActions =
        !execution.isCompleted && (canAddDiaryEntry || canCompleteJob);
    final statusColor =
        execution.isCompleted ? BafColors.sync : BafColors.warning;
    final diaryAsync = ref.watch(
      jobDiaryEntriesProvider(
        JobDiaryQueryKey(
          jobExecutionFirestoreId: _cleanOptionalString(execution.firestoreId),
          jobExecutionLocalId: kIsWeb ? null : execution.id,
          limit: 50,
        ),
      ),
    );
    final modulesAsync = ref.watch(
      jobModulesProvider(
        JobModuleQueryKey(
          jobExecutionFirestoreId: _cleanOptionalString(execution.firestoreId),
          jobExecutionLocalId: kIsWeb ? null : execution.id,
          limit: 100,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text(
          'Planned Job Detail',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          showBottomActions ? 112 : BafSpacing.xl,
        ),
        children: [
          _DossierHeaderCard(
            execution: execution,
            template: _template,
            statusColor: statusColor,
          ),
          if (!actionRead.isValid) ...[
            const SizedBox(height: BafSpacing.lg),
            const PersistedDataIntegrityNotice(
              title: 'Saved action evidence needs repair',
              message:
                  'Action counts and details are hidden, and job completion is blocked. No saved actions were discarded or replaced.',
            ),
          ],
          if (!responseRead.isValid) ...[
            const SizedBox(height: BafSpacing.lg),
            const PersistedDataIntegrityNotice(
              title: 'Saved response evidence needs repair',
              message:
                  'Response counts and details are hidden, and job completion is blocked. No saved responses were discarded or replaced.',
            ),
          ],
          if (!innerCoverPositionRead.isValid) ...[
            const SizedBox(height: BafSpacing.lg),
            const PersistedDataIntegrityNotice(
              title: 'Inner Cover assignment evidence needs repair',
              message:
                  'The frozen Base, serial or linkage identity is contradictory. Job completion is blocked until the saved evidence is repaired.',
            ),
          ],
          if (execution.workflowSchemaVersion == 1 &&
              _hasText(execution.firestoreId)) ...[
            const SizedBox(height: BafSpacing.lg),
            PlannedJobWorkflowPanel(
              workflowId: execution.firestoreId!.trim(),
              jobCompleted: execution.isCompleted,
            ),
          ],
          const SizedBox(height: BafSpacing.lg),
          _SectionCard(
            title: 'Maintenance classification',
            subtitle:
                'The frozen business outcome controls the immutable completion ledger and only its declared counters.',
            icon: Icons.event_repeat_rounded,
            children: [
              if (frozenMaintenanceClass != null) ...[
                _InfoRow(label: 'Class', value: frozenMaintenanceClass.title),
                _InfoRow(
                  label: 'Reset matrix',
                  value: frozenMaintenanceClass.resetCounters
                      .map((counter) => counter.label)
                      .join(', '),
                ),
              ] else ...[
                _WarningBox(
                  text:
                      execution.isCompleted
                          ? 'Classification pending. This completion has not reset a preventive-maintenance counter.'
                          : 'No maintenance class is frozen yet. Completion will remain classification pending.',
                ),
              ],
              if (canClassify) ...[
                const SizedBox(height: BafSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _classifyMaintenance(maintenanceClasses),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(
                      frozenMaintenanceClass == null
                          ? 'Classify'
                          : 'Correct classification',
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (execution.isCompleted) ...[
            const SizedBox(height: BafSpacing.lg),
            _ClosedDossierStatusCard(execution: execution),
          ],
          const SizedBox(height: BafSpacing.lg),
          _SectionCard(
            title: 'Job context',
            subtitle: 'Assignment, asset, charge, teams and sync context.',
            icon: Icons.assignment_rounded,
            children: [
              _InfoRow(
                label: 'Asset',
                value:
                    '${_assetTypeLabel(execution.assetType)} ${execution.assetNumber}',
              ),
              if (innerCoverPositionRead.position case final position?) ...[
                _InfoRow(
                  label: 'Inner Cover serial',
                  value: position.innerCoverSerialNumber,
                ),
                _InfoRow(
                  label: 'Frozen linkage',
                  value:
                      '${position.linkageId} · assignment v${position.assignmentVersion}',
                ),
              ],
              _InfoRow(
                label: 'Template',
                value: _cleanDisplay(
                  execution.templateName ?? _template?.jobName,
                  fallback: 'Unnamed planned job',
                ),
              ),
              if (execution.isGovernedTemplateAssignment) ...[
                _InfoRow(
                  label: 'Governed version',
                  value: _governedTemplateVersionLabel(execution),
                ),
                if (_hasText(execution.templateContentHash))
                  _InfoRow(
                    label: 'Content hash',
                    value: execution.templateContentHash!.trim(),
                  ),
              ],
              if (_template != null) ...[
                _InfoRow(
                  label: 'Template scope',
                  value: _templateScopeLabel(_template!),
                ),
                _ChipInfoRow(
                  label: 'Assigned agencies',
                  values: _template!.assignedAgencies,
                  colorFor: _agencyColor,
                  emptyText: 'No agency scope recorded',
                ),
              ] else if (_templateLoadError != null) ...[
                _WarningBox(text: _templateLoadError!),
              ] else if (_isLoadingTemplate) ...[
                const _InlineLoadingRow(label: 'Template'),
              ],
              _InfoRow(
                label: 'Status',
                value: execution.isCompleted ? 'Completed' : 'Open / Pending',
              ),
              _InfoRow(
                label: 'Assigned on',
                value: _formatDateTime(execution.createdAt),
              ),
              if (_hasText(execution.assignedByName))
                _InfoRow(
                  label: 'Assigned by',
                  value: execution.assignedByName!.trim(),
                ),
              if (execution.chargeNoAtEvent != null)
                _InfoRow(
                  label: 'Charge no.',
                  value: execution.chargeNoAtEvent.toString(),
                ),
              if (execution.isCompleted && execution.completedAt != null)
                _InfoRow(
                  label: 'Completed on',
                  value: _formatDateTime(execution.completedAt!),
                ),
              if (_hasText(execution.completedByName))
                _InfoRow(
                  label: 'Completed by',
                  value: execution.completedByName!.trim(),
                ),
              _ChipInfoRow(
                label: 'Teams involved',
                values: execution.teamsInvolved,
                colorFor: _agencyColor,
                emptyText:
                    execution.isCompleted
                        ? 'No teams recorded'
                        : 'Not submitted yet',
              ),
              _InfoRow(
                label: 'Last updated',
                value: _formatDateTime(execution.updatedAt),
              ),
              _InfoRow(
                label: 'Sync state',
                value:
                    execution.isSynced || kIsWeb
                        ? 'Remote-backed / synced'
                        : 'Saved locally · pending sync',
              ),
            ],
          ),
          if (!execution.isGovernedTemplateAssignment) ...[
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Legacy execution summary',
              subtitle:
                  'Original execution-level evidence retained for jobs created from a legacy template.',
              icon: Icons.view_module_rounded,
              children: [
                _LegacyModuleCard(execution: execution, template: _template),
              ],
            ),
          ],
          const SizedBox(height: BafSpacing.lg),
          _SectionCard(
            title:
                execution.isCompleted
                    ? 'Closed process modules'
                    : 'Process modules',
            subtitle:
                execution.isCompleted
                    ? 'Read-only module evidence, lifecycle decisions and structured responses captured before closure.'
                    : 'Published governed runtime-add catalogue first, with Emergency/manual seed catalogue fallback.',
            icon: Icons.account_tree_rounded,
            children: [
              _ProcessModuleDossier(
                modulesAsync: modulesAsync,
                isOpenJob: !execution.isCompleted,
                onAddModule: canAddModule ? _openAddJobModuleSheet : null,
                onOpenModule: _openModuleWorkspace,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _SectionCard(
            title:
                execution.isCompleted
                    ? 'Closed diary / handover'
                    : 'Live diary / handover',
            subtitle:
                execution.isCompleted
                    ? 'Read-only running notes, blockers and handovers preserved with the closed dossier.'
                    : 'Running notes, blockers and shift handovers attached to this planned job.',
            icon: Icons.forum_rounded,
            children: [
              _DiaryDossier(
                entriesAsync: diaryAsync,
                isOpenJob: !execution.isCompleted,
                onAddEntry: canAddDiaryEntry ? _openAddDiaryEntrySheet : null,
              ),
            ],
          ),
          if (!execution.isGovernedTemplateAssignment) ...[
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title:
                  execution.isCompleted
                      ? 'Closed checklist responses'
                      : 'Checklist responses',
              subtitle:
                  execution.isCompleted
                      ? 'Final legacy checklist responses preserved as the submitted job evidence.'
                      : 'Template fields and submitted responses for this job.',
              icon: Icons.fact_check_rounded,
              children: [
                if (!responseRead.isValid)
                  const PersistedDataIntegrityNotice(
                    title: 'Checklist responses unavailable',
                    message:
                        'This saved response payload must be repaired before its evidence can be displayed.',
                  )
                else
                  _ChecklistDossier(
                    template: _template,
                    responses: responseRead.entries,
                    isLoadingTemplate: _isLoadingTemplate,
                  ),
              ],
            ),
          ],
          const SizedBox(height: BafSpacing.lg),
          _SectionCard(
            title:
                execution.isCompleted
                    ? 'Closed actions / observations'
                    : 'Actions / observations',
            subtitle:
                execution.isCompleted
                    ? 'Final cross-module observations and work notes captured at closure.'
                    : 'Cross-module observations and work to record at completion.',
            icon: Icons.build_circle_rounded,
            children: [
              if (!actionRead.isValid)
                const PersistedDataIntegrityNotice(
                  title: 'Actions unavailable',
                  message:
                      'This saved action payload is malformed and must be repaired before its evidence can be displayed.',
                )
              else if (actionRead.entries.isEmpty)
                const _EmptyInlineState(
                  icon: Icons.add_task_rounded,
                  text: 'No component actions or observations were recorded.',
                  color: BafColors.planned,
                )
              else
                ...actionRead.entries.map(_ActionDossierCard.new),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _SectionCard(
            title:
                execution.isCompleted
                    ? 'Final remarks and raw dossier notes'
                    : 'Remarks and raw dossier notes',
            subtitle:
                execution.isCompleted
                    ? 'Final completion remarks and raw metadata preserved with the closed job dossier.'
                    : execution.isGovernedTemplateAssignment
                    ? 'Assignment context, final remarks and governed lineage metadata.'
                    : 'Legacy remarks are preserved here alongside diary and final closure notes.',
            icon: Icons.notes_rounded,
            children: [
              if (_hasText(execution.remarks))
                _RemarksBox(text: execution.remarks!.trim())
              else
                const _EmptyInlineState(
                  icon: Icons.notes_rounded,
                  text: 'No remarks recorded.',
                  color: BafColors.admin,
                ),
              if (_hasText(execution.metadataJson)) ...[
                const SizedBox(height: BafSpacing.md),
                _MetadataBox(metadataJson: execution.metadataJson!),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar:
          !showBottomActions
              ? null
              : _OpenJobBottomBar(
                onAddEntry: canAddDiaryEntry ? _openAddDiaryEntrySheet : null,
                onComplete: canCompleteJob ? _openCompletionScreen : null,
              ),
    );
  }
}

FrozenMaintenanceClass? _maintenanceClassFromMetadata(String? metadataJson) {
  if (metadataJson == null || metadataJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(metadataJson);
    if (decoded is! Map) return null;
    final raw = decoded['maintenanceClassification'];
    if (raw is! Map) return null;
    return FrozenMaintenanceClass.fromMap(
      Map<String, dynamic>.from(raw),
      source: 'JobExecution.metadataJson/maintenanceClassification',
    );
  } catch (_) {
    return null;
  }
}

String? _assetClassIdFromMetadata(String? metadataJson) {
  if (metadataJson == null || metadataJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(metadataJson);
    if (decoded is! Map) return null;
    final identity = decoded['assignmentAssetIdentity'];
    if (identity is! Map) return null;
    final value = identity['assetClassId'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  } catch (_) {
    return null;
  }
}

String _governedTemplateVersionLabel(JobExecution execution) {
  final versionNumber = execution.templateVersionNumber;
  final label = _cleanDisplay(execution.templateVersionLabel, fallback: '');
  final packageCode = _cleanDisplay(
    execution.templatePackageCode,
    fallback: 'Governed catalogue',
  );
  final versionText =
      versionNumber == null ? 'published version' : 'v$versionNumber';
  return label.isEmpty
      ? '$packageCode · $versionText'
      : '$packageCode · $versionText · $label';
}
