// FILE: lib/features/planned_maintenance/presentation/job_module_detail_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../audit/models/audit_event_model.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../data/job_module_model.dart';
import '../data/job_template_model.dart';
import '../domain/runtime_module_lineage.dart';
import '../providers/job_module_provider.dart';
import 'widgets/job_module_response_form.dart';
import 'widgets/job_module_response_summary.dart';

/// Detail workspace for a single process module inside a planned job.
///
/// This is intentionally the first runtime workspace layer. It renders the
/// governance-shaped dynamic module response fields and preserves lifecycle
/// actions without disturbing the legacy completion flow.
class JobModuleDetailScreen extends ConsumerStatefulWidget {
  final JobExecution execution;
  final JobModuleInstance module;

  const JobModuleDetailScreen({
    super.key,
    required this.execution,
    required this.module,
  });

  @override
  ConsumerState<JobModuleDetailScreen> createState() =>
      _JobModuleDetailScreenState();
}

class _JobModuleDetailScreenState extends ConsumerState<JobModuleDetailScreen> {
  late JobModuleInstance _module;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _module = widget.module;
  }

  @override
  void didUpdateWidget(covariant JobModuleDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module.firestoreId != widget.module.firestoreId ||
        oldWidget.module.id != widget.module.id) {
      _module = widget.module;
    }
  }

  Future<AppUser?> _readActor() async {
    try {
      return await ref.read(currentAppUserProvider.future);
    } catch (_) {
      return null;
    }
  }

  dynamic _transitionId() {
    if (kIsWeb) {
      final firestoreId = _cleanOptionalString(_module.firestoreId);
      if (firestoreId == null) {
        throw StateError(
          'Remote module id is missing. Save/sync this module first.',
        );
      }
      return firestoreId;
    }
    return _module.id;
  }

  JobModuleInstance _editableCopy() {
    final copy =
        JobModuleInstance.fromMap(
            _module.toMap(),
            _module.firestoreId ?? '__local_module__',
          )
          ..id = _module.id
          ..firestoreId = _module.firestoreId
          // fromMap() is intentionally remote-safe and ignores transported
          // Isar ids. Preserve the genuine local relation when cloning an
          // offline/local module for editing on this device.
          ..jobExecutionLocalId = _module.jobExecutionLocalId
          ..isSynced = _module.isSynced;
    return copy;
  }

  Future<void> _saveStructuredResponses(List<FieldResponse> responses) async {
    final actor = await _readActor();
    if (!mounted) return;

    if (actor == null ||
        !actor.canSaveJobModuleWorkFor(_module.discipline.name)) {
      _showSnack(
        'You are not authorized to save module responses.',
        isError: true,
      );
      return;
    }

    final wasNotStarted = _module.status == JobModuleStatus.notStarted;
    final nextStatus =
        wasNotStarted ? JobModuleStatus.draftSaved : _module.status;

    final updated =
        _editableCopy()
          ..responses = responses
          ..status = nextStatus
          ..updatedByUid = actor.uid
          ..updatedByName = actor.name
          ..updatedAt = DateTime.now();

    await _runBusyAction(
      successMessage:
          wasNotStarted
              ? 'Structured responses saved as draft'
              : 'Structured module responses saved',
      action: () async {
        await ref
            .read(jobModuleRepositoryProvider)
            .saveModule(
              updated,
              actor: actor,
              auditContext: AuditContext(
                performedByUid: actor.uid,
                performedByName: actor.name,
                summary:
                    wasNotStarted
                        ? 'Saved structured process-module responses as draft'
                        : 'Saved structured process-module responses',
              ),
            );
        if (!mounted) return;
        setState(() => _module = updated);
      },
    );
  }

  Future<void> _saveProgress() async {
    final actor = await _readActor();
    if (!mounted) return;

    if (actor == null ||
        !actor.canSaveJobModuleWorkFor(_module.discipline.name)) {
      _showSnack(
        'You are not authorized to save module progress.',
        isError: true,
      );
      return;
    }

    final draft = await showModalBottomSheet<_ModuleProgressDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BafRadius.large),
        ),
      ),
      builder: (_) => _ModuleProgressSheet(module: _module),
    );

    if (!mounted || draft == null) return;

    final updated =
        _editableCopy()
          ..status = draft.status
          ..draftNote = draft.draftNote
          ..pendingIssue = draft.pendingIssue
          ..requiresFollowUp = draft.requiresFollowUp
          ..updatedByUid = actor.uid
          ..updatedByName = actor.name
          ..updatedAt = DateTime.now();

    await _runBusyAction(
      successMessage: 'Module progress saved',
      action: () async {
        await ref
            .read(jobModuleRepositoryProvider)
            .saveModule(
              updated,
              actor: actor,
              auditContext: AuditContext(
                performedByUid: actor.uid,
                performedByName: actor.name,
                summary: 'Saved process-module progress',
              ),
            );
        if (!mounted) return;
        setState(() => _module = updated);
      },
    );
  }

  Future<void> _submitModule() async {
    final actor = await _readActor();
    if (!mounted) return;

    if (actor == null || !actor.canSubmitJobModule(_module.discipline.name)) {
      _showSnack(
        'You are not authorized to submit this module.',
        isError: true,
      );
      return;
    }

    final note = await _openReasonSheet(
      title: 'Submit module',
      description:
          'Submit this process module for supervisor/Admin review or final dossier inclusion.',
      label: 'Submission note',
      required: false,
      actionLabel: 'Submit Module',
      actionColor: BafColors.sync,
    );

    if (!mounted || note == null) return;

    await _runBusyAction(
      successMessage: 'Module submitted',
      action: () async {
        await ref
            .read(jobModuleRepositoryProvider)
            .submitModule(
              _transitionId(),
              actor: actor,
              submissionNote: note,
              auditContext: AuditContext(
                performedByUid: actor.uid,
                performedByName: actor.name,
                summary: 'Submitted process module',
              ),
            );
        if (!mounted) return;
        setState(() {
          _module
            ..status = JobModuleStatus.submitted
            ..submittedByUid = actor.uid
            ..submittedByName = actor.name
            ..submittedAt = DateTime.now()
            ..submissionNote = note
            ..updatedByUid = actor.uid
            ..updatedByName = actor.name
            ..isSynced = kIsWeb;
        });
      },
    );
  }

  Future<void> _acceptModule() async {
    final actor = await _readActor();
    if (!mounted) return;

    if (actor == null || !actor.canAcceptJobModule) {
      _showSnack(
        'You are not authorized to accept this module.',
        isError: true,
      );
      return;
    }

    final note = await _openReasonSheet(
      title: 'Accept module',
      description:
          'Accept this submitted module as reviewed evidence. This does not close the parent planned job.',
      label: 'Acceptance note',
      required: false,
      actionLabel: 'Accept Module',
      actionColor: BafColors.sync,
    );

    if (!mounted || note == null) return;

    await _runBusyAction(
      successMessage: 'Module accepted',
      action: () async {
        await ref
            .read(jobModuleRepositoryProvider)
            .acceptModule(
              _transitionId(),
              actor: actor,
              acceptanceNote: note,
              auditContext: AuditContext(
                performedByUid: actor.uid,
                performedByName: actor.name,
                summary: 'Accepted process module',
              ),
            );
        if (!mounted) return;
        setState(() {
          _module
            ..status = JobModuleStatus.accepted
            ..acceptedByUid = actor.uid
            ..acceptedByName = actor.name
            ..acceptedAt = DateTime.now()
            ..acceptanceNote = note
            ..updatedByUid = actor.uid
            ..updatedByName = actor.name
            ..isSynced = kIsWeb;
        });
      },
    );
  }

  Future<void> _markNotApplicable() async {
    final actor = await _readActor();
    if (!mounted) return;

    if (actor == null || !actor.canMarkJobModuleNotApplicable) {
      _showSnack(
        'You are not authorized to mark this module not applicable.',
        isError: true,
      );
      return;
    }

    final reason = await _openReasonSheet(
      title: 'Mark not applicable',
      description:
          'A preloaded or selected module should only be bypassed with a clear reason.',
      label: 'Reason',
      required: true,
      actionLabel: 'Mark N/A',
      actionColor: BafColors.warning,
    );

    if (!mounted || reason == null) return;

    await _runBusyAction(
      successMessage: 'Module marked not applicable',
      action: () async {
        await ref
            .read(jobModuleRepositoryProvider)
            .markModuleNotApplicable(
              _transitionId(),
              actor: actor,
              reason: reason,
              auditContext: AuditContext(
                performedByUid: actor.uid,
                performedByName: actor.name,
                summary: 'Marked process module not applicable',
              ),
            );
        if (!mounted) return;
        setState(() {
          _module
            ..status = JobModuleStatus.notApplicable
            ..notApplicableByUid = actor.uid
            ..notApplicableByName = actor.name
            ..notApplicableAt = DateTime.now()
            ..notApplicableReason = reason
            ..updatedByUid = actor.uid
            ..updatedByName = actor.name
            ..isSynced = kIsWeb;
        });
      },
    );
  }

  Future<void> _reopenModule() async {
    final actor = await _readActor();
    if (!mounted) return;

    if (actor == null || !actor.canReopenJobModule) {
      _showSnack(
        'You are not authorized to reopen this module.',
        isError: true,
      );
      return;
    }

    final reason = await _openReasonSheet(
      title: 'Reopen module',
      description:
          'Reopening makes the module editable again and records an audit reason.',
      label: 'Reopen reason',
      required: true,
      actionLabel: 'Reopen Module',
      actionColor: BafColors.danger,
    );

    if (!mounted || reason == null) return;

    await _runBusyAction(
      successMessage: 'Module reopened',
      action: () async {
        final appliedAt = DateTime.now().toUtc();
        final executionId = _cleanOptionalString(widget.execution.firestoreId);
        final moduleId = _cleanOptionalString(_module.firestoreId);
        if (widget.execution.workflowSchemaVersion == 1) {
          if (executionId == null || moduleId == null) {
            throw StateError(
              'Workflow identity is incomplete. Sync this job before reopening.',
            );
          }
          final repository = ref.read(workflowRepositoryProvider);
          final workflow = await repository.getWorkflow(executionId);
          if (workflow == null) {
            throw StateError(
              'Maintenance workflow is not available locally. Sync and retry.',
            );
          }
          final command = WorkflowCommandFactory.create(
            type: WorkflowCommandType.reopenWorkflowModule,
            aggregateId: executionId,
            expectedVersion: workflow.version,
            payload: <String, Object?>{
              'moduleFirestoreId': moduleId,
              'reason': reason,
            },
          );
          await ref
              .read(workflowCommandControllerProvider.notifier)
              .execute(command);
          await ref
              .read(jobModuleRepositoryProvider)
              .applyWorkflowModuleReopenProjection(
                moduleId,
                actor: actor,
                reason: reason,
                appliedAt: appliedAt,
              );
        } else {
          await ref
              .read(jobModuleRepositoryProvider)
              .reopenModule(
                _transitionId(),
                actor: actor,
                reopenReason: reason,
                auditContext: AuditContext(
                  performedByUid: actor.uid,
                  performedByName: actor.name,
                  summary: 'Reopened process module',
                ),
              );
        }
        if (!mounted) return;
        setState(() {
          _module
            ..status = JobModuleStatus.reopened
            ..reopenedByUid = actor.uid
            ..reopenedByName = actor.name
            ..reopenedAt = appliedAt
            ..reopenReason = reason
            ..updatedByUid = actor.uid
            ..updatedByName = actor.name
            ..isSynced = kIsWeb;
        });
      },
    );
  }

  Future<String?> _openReasonSheet({
    required String title,
    required String description,
    required String label,
    required bool required,
    required String actionLabel,
    required Color actionColor,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BafRadius.large),
        ),
      ),
      builder:
          (_) => _ReasonSheet(
            title: title,
            description: description,
            label: label,
            required: required,
            actionLabel: actionLabel,
            actionColor: actionColor,
          ),
    );
  }

  Future<void> _runBusyAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      _showSnack(successMessage);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? BafColors.danger : BafColors.sync,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = _module;
    final snapshotRead = module.moduleSnapshotReadResult;
    final standardItems = _standardItemsFromSnapshot(snapshotRead.value);
    final fieldRead = module.fieldDefinitionsReadResult;
    final responseRead = module.responsesReadResult;
    final fields = fieldRead.entries;
    final responses = responseRead.entries;
    final actor = ref.watch(currentAppUserProvider).asData?.value;
    final lineage = RuntimeModuleLineageInfo.fromModule(module);
    final actionRead = module.actionsReadResult;
    final workPayloadsValid =
        snapshotRead.isValid &&
        fieldRead.isValid &&
        responseRead.isValid &&
        actionRead.isValid;
    final canSaveWork =
        !widget.execution.isCompleted &&
        module.isOpenForWork &&
        workPayloadsValid &&
        (actor?.canSaveJobModuleWorkFor(module.discipline.name) ?? false);
    final canSubmitModule =
        canSaveWork &&
        (actor?.canSubmitJobModule(module.discipline.name) ?? false);
    final canMarkNotApplicable =
        canSaveWork && (actor?.canMarkJobModuleNotApplicable ?? false);
    final canAcceptModule =
        !widget.execution.isCompleted &&
        module.status == JobModuleStatus.submitted &&
        workPayloadsValid &&
        (actor?.canAcceptJobModule ?? false);
    final canReopenModule =
        !widget.execution.isCompleted &&
        (module.status == JobModuleStatus.submitted ||
            module.status == JobModuleStatus.accepted ||
            module.status == JobModuleStatus.notApplicable) &&
        workPayloadsValid &&
        (actor?.canReopenJobModule ?? false);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text(
          'Module Workspace',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.xl,
        ),
        children: [
          _ModuleHeaderCard(module: module),
          if (!fieldRead.isValid) ...[
            const SizedBox(height: BafSpacing.lg),
            const PersistedDataIntegrityNotice(
              title: 'Saved field definitions need repair',
              message:
                  'Dynamic fields are hidden and module changes are blocked. The saved definition payload was preserved exactly.',
            ),
          ],
          if (!responseRead.isValid) ...[
            const SizedBox(height: BafSpacing.lg),
            const PersistedDataIntegrityNotice(
              title: 'Saved module responses need repair',
              message:
                  'Response counts and details are hidden and module changes are blocked. No saved response evidence was discarded or replaced.',
            ),
          ],
          if (!actionRead.isValid) ...[
            const SizedBox(height: BafSpacing.lg),
            const PersistedDataIntegrityNotice(
              title: 'Saved module actions need repair',
              message:
                  'Action counts are hidden and module changes are blocked. No saved action evidence was discarded or replaced.',
            ),
          ],
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Module context',
            subtitle: 'Runtime identity, parent job and sync context.',
            icon: Icons.account_tree_rounded,
            children: [
              _InfoRow(
                label: 'Asset',
                value:
                    '${_assetTypeLabel(module.assetType)} ${module.assetNumber}',
              ),
              _InfoRow(
                label: 'Functional section',
                value: _display(module.functionalSection, 'Not specified'),
              ),
              _InfoRow(
                label: 'Component group',
                value: _display(module.componentGroup, 'Not specified'),
              ),
              _InfoRow(label: 'Use mode', value: _useModeLabel(module.useMode)),
              _InfoRow(
                label: 'Discipline lane',
                value: _disciplineLabel(module.discipline),
              ),
              _InfoRow(
                label: 'Safety class',
                value: _safetyLabel(module.safetyClass),
              ),
              _InfoRow(
                label: 'Closure-critical',
                value: module.requiredForClosure ? 'Yes' : 'No',
              ),
              _InfoRow(
                label: 'Added during execution',
                value: module.addedDuringExecution ? 'Yes' : 'No',
              ),
              if (_hasText(module.addReason))
                _InfoRow(label: 'Add reason', value: module.addReason!.trim()),
              _InfoRow(
                label: 'Last updated',
                value: _formatDateTime(module.updatedAt),
              ),
              _InfoRow(
                label: 'Sync state',
                value:
                    module.isSynced || kIsWeb
                        ? 'Remote-backed / synced'
                        : 'Saved locally · pending sync',
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Source lineage',
            subtitle:
                'Published source, runtime-add fallback and audit metadata visible for dossier review.',
            icon: _lineageIcon(lineage.source),
            children: [
              _InfoRow(label: 'Source', value: lineage.label),
              _InfoRow(label: 'Summary', value: lineage.summary),
              ...lineage.detailRows.map(
                (row) => _InfoRow(label: row.label, value: row.value),
              ),
              if (lineage.warning != null)
                _InfoRow(label: 'Governance note', value: lineage.warning!),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Procedure, safety and targets',
            subtitle:
                'Snapshot metadata carried from the BAF module catalogue.',
            icon: Icons.health_and_safety_rounded,
            children: [
              _StringListBlock(
                title: 'Procedure references',
                values: module.procedureRefs,
                emptyText:
                    'No procedure references captured in this module snapshot.',
              ),
              const SizedBox(height: BafSpacing.md),
              _StringListBlock(
                title: 'Safety confirmations',
                values: module.safetyConfirmations,
                emptyText: 'No safety confirmations captured.',
              ),
              const SizedBox(height: BafSpacing.md),
              _StringListBlock(
                title: 'Operational preconditions',
                values: module.operationalStatePreconditions,
                emptyText: 'No operational preconditions captured.',
              ),
              const SizedBox(height: BafSpacing.md),
              _StringListBlock(
                title: 'Targets',
                values: [
                  if (_hasText(module.targetRef)) module.targetRef!.trim(),
                  ...module.targetRefs,
                ],
                emptyText: 'No target tags captured yet.',
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Standard items and field definitions',
            subtitle: 'Catalogue snapshot carried into this module instance.',
            icon: Icons.checklist_rounded,
            children: [
              if (!snapshotRead.isValid)
                const PersistedDataIntegrityNotice(
                  title: 'Module snapshot unavailable',
                  message:
                      'This saved module snapshot must be repaired before work can continue.',
                )
              else if (standardItems.isEmpty)
                const _EmptyBox(
                  icon: Icons.checklist_rtl_rounded,
                  text:
                      'No standard job items were captured in this module snapshot.',
                )
              else
                ...standardItems.map(_StandardItemTile.new),
              if (!fieldRead.isValid)
                const PersistedDataIntegrityNotice(
                  title: 'Field definitions unavailable',
                  message:
                      'This saved definition payload must be repaired before dynamic work fields can be displayed.',
                )
              else if (fields.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.md),
                const Text(
                  'Dynamic field definitions',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                ...fields.map(_FieldDefinitionTile.new),
              ],
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Saved structured responses',
            subtitle:
                'Read-only dossier view of responses already saved into responsesJson.',
            icon: Icons.fact_check_rounded,
            children: [
              if (!responseRead.isValid)
                const PersistedDataIntegrityNotice(
                  title: 'Responses unavailable',
                  message:
                      'This saved response payload must be repaired before its evidence can be displayed.',
                )
              else
                JobModuleResponseSummary(
                  responses: responses,
                  fieldDefinitions: fields,
                ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Structured module responses',
            subtitle:
                module.status == JobModuleStatus.notStarted
                    ? 'Saving these fields will create a draft module response.'
                    : 'Dynamic fields rendered from the module snapshot and saved into responsesJson.',
            icon: Icons.dynamic_form_rounded,
            children: [
              if (!fieldRead.isValid || !responseRead.isValid)
                const PersistedDataIntegrityNotice(
                  title: 'Structured response editing blocked',
                  message:
                      'Repair the saved field definitions and responses before editing this module.',
                )
              else
                JobModuleResponseForm(
                  fieldDefinitions: fields,
                  initialResponses: responses,
                  isEditable: canSaveWork,
                  isBusy: _isBusy,
                  saveButtonLabel:
                      module.status == JobModuleStatus.notStarted
                          ? 'Save Responses as Draft'
                          : 'Save Structured Responses',
                  onSave: _saveStructuredResponses,
                ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleSectionCard(
            title: 'Progress and lifecycle notes',
            subtitle:
                'Module-level notes and lifecycle evidence alongside structured responses.',
            icon: Icons.timeline_rounded,
            children: [
              _InfoRow(
                label: 'Draft / progress note',
                value: _display(module.draftNote, 'No progress note saved.'),
              ),
              _InfoRow(
                label: 'Pending issue',
                value: _display(
                  module.pendingIssue,
                  'No pending issue recorded.',
                ),
              ),
              _InfoRow(
                label: 'Follow-up required',
                value: module.requiresFollowUp ? 'Yes' : 'No',
              ),
              if (_hasText(module.submissionNote))
                _InfoRow(
                  label: 'Submission note',
                  value: module.submissionNote!.trim(),
                ),
              if (_hasText(module.acceptanceNote))
                _InfoRow(
                  label: 'Acceptance note',
                  value: module.acceptanceNote!.trim(),
                ),
              if (_hasText(module.notApplicableReason))
                _InfoRow(
                  label: 'Not applicable reason',
                  value: module.notApplicableReason!.trim(),
                ),
              if (_hasText(module.reopenReason))
                _InfoRow(
                  label: 'Reopen reason',
                  value: module.reopenReason!.trim(),
                ),
              _InfoRow(
                label: 'Response count',
                value:
                    responseRead.isValid
                        ? responseRead.entries.length.toString()
                        : 'Needs repair',
              ),
              _InfoRow(
                label: 'Action count',
                value:
                    actionRead.isValid
                        ? actionRead.entries.length.toString()
                        : 'Needs repair',
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          _ModuleLifecycleCard(
            module: module,
            parentJobCompleted: widget.execution.isCompleted,
            isBusy: _isBusy,
            canSaveProgress: canSaveWork,
            canSubmit: canSubmitModule,
            canAccept: canAcceptModule,
            canMarkNotApplicable: canMarkNotApplicable,
            canReopen: canReopenModule,
            onSaveProgress: _saveProgress,
            onSubmit: _submitModule,
            onAccept: _acceptModule,
            onNotApplicable: _markNotApplicable,
            onReopen: _reopenModule,
          ),
        ],
      ),
    );
  }
}

class _ModuleHeaderCard extends StatelessWidget {
  final JobModuleInstance module;

  const _ModuleHeaderCard({required this.module});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(module.status);
    final title = _moduleTitle(module);
    final lineage = RuntimeModuleLineageInfo.fromModule(module);

    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _statusIcon(module.status),
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _display(module.moduleCode, 'PROCESS MODULE'),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              StatusBadge(
                label: _statusLabel(module.status),
                color: statusColor,
              ),
              StatusBadge(
                label: _disciplineLabel(module.discipline),
                color: _disciplineColor(module.discipline),
              ),
              StatusBadge(
                label: _useModeLabel(module.useMode),
                color: BafColors.planned,
              ),
              StatusBadge(
                label: lineage.badgeLabel,
                color: _lineageColor(lineage.source),
                icon: _lineageIcon(lineage.source),
              ),
              StatusBadge(
                label: _safetyLabel(module.safetyClass),
                color: _safetyColor(module.safetyClass),
                icon: Icons.health_and_safety_rounded,
              ),
              if (module.requiredForClosure)
                const StatusBadge(
                  label: 'Closure-critical',
                  color: BafColors.danger,
                  icon: Icons.lock_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _ModuleSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BafColors.planned, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _ModuleLifecycleCard extends StatelessWidget {
  final JobModuleInstance module;
  final bool parentJobCompleted;
  final bool isBusy;
  final bool canSaveProgress;
  final bool canSubmit;
  final bool canAccept;
  final bool canMarkNotApplicable;
  final bool canReopen;
  final VoidCallback onSaveProgress;
  final VoidCallback onSubmit;
  final VoidCallback onAccept;
  final VoidCallback onNotApplicable;
  final VoidCallback onReopen;

  const _ModuleLifecycleCard({
    required this.module,
    required this.parentJobCompleted,
    required this.isBusy,
    required this.canSaveProgress,
    required this.canSubmit,
    required this.canAccept,
    required this.canMarkNotApplicable,
    required this.canReopen,
    required this.onSaveProgress,
    required this.onSubmit,
    required this.onAccept,
    required this.onNotApplicable,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = module.isOpenForWork && !parentJobCompleted;
    final isSubmitted =
        !parentJobCompleted && module.status == JobModuleStatus.submitted;
    final isReopenable =
        !parentJobCompleted &&
        (module.status == JobModuleStatus.submitted ||
            module.status == JobModuleStatus.accepted ||
            module.status == JobModuleStatus.notApplicable);

    return _ModuleSectionCard(
      title: 'Lifecycle actions',
      subtitle:
          parentJobCompleted
              ? 'Parent job is closed. Module lifecycle actions are locked.'
              : 'Save progress, submit, accept, bypass with reason, or reopen when permitted.',
      icon: Icons.published_with_changes_rounded,
      children: [
        if (parentJobCompleted)
          const _EmptyBox(
            icon: Icons.lock_rounded,
            text:
                'This planned job is closed. The module is shown as dossier evidence.',
          )
        else if (isOpen) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !isBusy && canSaveProgress ? onSaveProgress : null,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Progress'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BafColors.planned,
                    side: const BorderSide(color: BafColors.planned),
                  ),
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: !isBusy && canSubmit ? onSubmit : null,
                  icon: const Icon(Icons.outbox_rounded),
                  label: const Text('Submit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.sync,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (!canSubmit) ...[
            const SizedBox(height: BafSpacing.xs),
            const Text(
              'Submit requires the assigned senior discipline role, supervisor, Admin, or SI. Progress and responses remain open for cross-lane evidence capture.',
              style: TextStyle(
                color: BafColors.textSecondary,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.sm),
          TextButton.icon(
            onPressed: !isBusy && canMarkNotApplicable ? onNotApplicable : null,
            icon: const Icon(Icons.block_rounded),
            label: const Text('Mark not applicable with reason'),
            style: TextButton.styleFrom(foregroundColor: BafColors.warning),
          ),
        ] else if (isSubmitted) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: !isBusy && canAccept ? onAccept : null,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Accept'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.sync,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !isBusy && canReopen ? onReopen : null,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Reopen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BafColors.danger,
                    side: const BorderSide(color: BafColors.danger),
                  ),
                ),
              ),
            ],
          ),
          if (!canAccept && !canReopen) ...[
            const SizedBox(height: BafSpacing.sm),
            const _EmptyBox(
              icon: Icons.hourglass_top_rounded,
              text: 'Submitted module is awaiting supervisor/Admin/SI review.',
            ),
          ],
        ] else if (isReopenable)
          FilledButton.icon(
            onPressed: !isBusy && canReopen ? onReopen : null,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Reopen Module'),
            style: FilledButton.styleFrom(
              backgroundColor: BafColors.danger,
              foregroundColor: Colors.white,
            ),
          )
        else
          const _EmptyBox(
            icon: Icons.verified_rounded,
            text: 'This module is accepted/finalised for normal users.',
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StringListBlock extends StatelessWidget {
  final String title;
  final List<String> values;
  final String emptyText;

  const _StringListBlock({
    required this.title,
    required this.values,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.xs),
        if (cleaned.isEmpty)
          Text(
            emptyText,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                cleaned
                    .map(
                      (value) =>
                          StatusBadge(label: value, color: BafColors.admin),
                    )
                    .toList(),
          ),
      ],
    );
  }
}

class _StandardItemTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _StandardItemTile(this.item);

  @override
  Widget build(BuildContext context) {
    final itemId = _display(item['itemId']?.toString(), 'Item');
    final title = _display(item['title']?.toString(), 'Untitled standard item');

    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: BafColors.planned,
            size: 18,
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              '$itemId  $title',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldDefinitionTile extends StatelessWidget {
  final Map<String, dynamic> field;

  const _FieldDefinitionTile(this.field);

  @override
  Widget build(BuildContext context) {
    final label = _display(field['label']?.toString(), 'Field');
    final type = _display(field['type']?.toString(), 'text');
    final unit = _cleanOptionalString(field['unit']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.input_rounded,
            color: BafColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              unit == null ? '$label ($type)' : '$label ($type, $unit)',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: BafColors.textSecondary, size: 20),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleProgressDraft {
  final JobModuleStatus status;
  final String? draftNote;
  final String? pendingIssue;
  final bool requiresFollowUp;

  const _ModuleProgressDraft({
    required this.status,
    required this.draftNote,
    required this.pendingIssue,
    required this.requiresFollowUp,
  });
}

class _ModuleProgressSheet extends StatefulWidget {
  final JobModuleInstance module;

  const _ModuleProgressSheet({required this.module});

  @override
  State<_ModuleProgressSheet> createState() => _ModuleProgressSheetState();
}

class _ModuleProgressSheetState extends State<_ModuleProgressSheet> {
  late JobModuleStatus _status;
  late final TextEditingController _draftController;
  late final TextEditingController _pendingController;
  late bool _requiresFollowUp;

  @override
  void initState() {
    super.initState();
    final current = widget.module.status;
    _status =
        current == JobModuleStatus.notStarted
            ? JobModuleStatus.inProgress
            : current == JobModuleStatus.submitted ||
                current == JobModuleStatus.accepted ||
                current == JobModuleStatus.notApplicable
            ? JobModuleStatus.draftSaved
            : current;
    _draftController = TextEditingController(
      text: widget.module.draftNote ?? '',
    );
    _pendingController = TextEditingController(
      text: widget.module.pendingIssue ?? '',
    );
    _requiresFollowUp = widget.module.requiresFollowUp;
  }

  @override
  void dispose() {
    _draftController.dispose();
    _pendingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BafSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save module progress',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This records module-level progress. Detailed dynamic checklist fields come in the next stage.',
              style: TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<JobModuleStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: _inputDecoration('Status'),
              items:
                  const [
                        JobModuleStatus.inProgress,
                        JobModuleStatus.draftSaved,
                        JobModuleStatus.reopened,
                      ]
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusLabel(status)),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _draftController,
              maxLines: 4,
              decoration: _inputDecoration(
                'Progress note',
              ).copyWith(alignLabelWithHint: true),
            ),
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _pendingController,
              maxLines: 3,
              decoration: _inputDecoration(
                'Pending issue / blocker pointer',
              ).copyWith(alignLabelWithHint: true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _requiresFollowUp,
              onChanged:
                  (value) => setState(() => _requiresFollowUp = value ?? false),
              title: const Text(
                'Requires follow-up',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: BafSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _ModuleProgressDraft(
                      status: _status,
                      draftNote: _cleanOptionalString(_draftController.text),
                      pendingIssue: _cleanOptionalString(
                        _pendingController.text,
                      ),
                      requiresFollowUp: _requiresFollowUp,
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Progress'),
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.sync,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonSheet extends StatefulWidget {
  final String title;
  final String description;
  final String label;
  final bool required;
  final String actionLabel;
  final Color actionColor;

  const _ReasonSheet({
    required this.title,
    required this.description,
    required this.label,
    required this.required,
    required this.actionLabel,
    required this.actionColor,
  });

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BafSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.description,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: _inputDecoration(widget.label).copyWith(
                alignLabelWithHint: true,
                errorText: _showError ? 'Reason is required' : null,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final text = _cleanOptionalString(_controller.text);
                  if (widget.required && text == null) {
                    setState(() => _showError = true);
                    return;
                  }
                  Navigator.pop(context, text ?? '');
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.actionColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: BafColors.textSecondary),
    filled: true,
    fillColor: BafColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.planned, width: 1.4),
    ),
  );
}

List<Map<String, dynamic>> _standardItemsFromSnapshot(
  Map<String, dynamic> snapshot,
) {
  final items = snapshot['standardItems'];
  if (items is! List) return [];
  return items
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _formatDateTime(DateTime value) {
  return DateFormat('dd MMM yyyy, HH:mm').format(value);
}

String _moduleTitle(JobModuleInstance module) {
  final code = _cleanOptionalString(module.moduleCode);
  if (code == null) return module.moduleTitle.trim();
  return '$code - ${module.moduleTitle.trim()}';
}

String _assetTypeLabel(dynamic type) {
  final name = type.toString().split('.').last;
  switch (name) {
    case 'base':
      return 'BASE';
    case 'furnace':
      return 'FURNACE';
    case 'forceCooler':
      return 'FORCED COOLER';
    case 'innerCover':
      return 'INNER COVER';
    default:
      return name.toUpperCase();
  }
}

Color _lineageColor(RuntimeModuleLineageSource source) {
  switch (source) {
    case RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd:
    case RuntimeModuleLineageSource.publishedTemplateVersionModule:
      return BafColors.sync;
    case RuntimeModuleLineageSource.emergencyManualSeed:
    case RuntimeModuleLineageSource.manualRuntimeAdd:
      return BafColors.warning;
    case RuntimeModuleLineageSource.legacyOrManual:
      return BafColors.textSecondary;
  }
}

IconData _lineageIcon(RuntimeModuleLineageSource source) {
  switch (source) {
    case RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd:
    case RuntimeModuleLineageSource.publishedTemplateVersionModule:
      return Icons.verified_rounded;
    case RuntimeModuleLineageSource.emergencyManualSeed:
      return Icons.warning_amber_rounded;
    case RuntimeModuleLineageSource.manualRuntimeAdd:
      return Icons.edit_note_rounded;
    case RuntimeModuleLineageSource.legacyOrManual:
      return Icons.history_rounded;
  }
}

Color _statusColor(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.notStarted:
      return BafColors.admin;
    case JobModuleStatus.inProgress:
    case JobModuleStatus.draftSaved:
      return BafColors.warning;
    case JobModuleStatus.submitted:
      return BafColors.planned;
    case JobModuleStatus.accepted:
      return BafColors.sync;
    case JobModuleStatus.reopened:
      return BafColors.danger;
    case JobModuleStatus.notApplicable:
      return BafColors.textSecondary;
  }
}

IconData _statusIcon(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.notStarted:
      return Icons.radio_button_unchecked_rounded;
    case JobModuleStatus.inProgress:
      return Icons.pending_actions_rounded;
    case JobModuleStatus.draftSaved:
      return Icons.save_rounded;
    case JobModuleStatus.submitted:
      return Icons.outbox_rounded;
    case JobModuleStatus.accepted:
      return Icons.verified_rounded;
    case JobModuleStatus.reopened:
      return Icons.replay_rounded;
    case JobModuleStatus.notApplicable:
      return Icons.block_rounded;
  }
}

String _statusLabel(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.notStarted:
      return 'Not started';
    case JobModuleStatus.inProgress:
      return 'In progress';
    case JobModuleStatus.draftSaved:
      return 'Draft saved';
    case JobModuleStatus.submitted:
      return 'Submitted';
    case JobModuleStatus.accepted:
      return 'Accepted';
    case JobModuleStatus.reopened:
      return 'Reopened';
    case JobModuleStatus.notApplicable:
      return 'Not applicable';
  }
}

String _disciplineLabel(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return 'Mechanical';
    case JobModuleDiscipline.electrical:
      return 'Electrical';
    case JobModuleDiscipline.instrumentation:
      return 'I&A';
    case JobModuleDiscipline.operations:
      return 'Operations';
    case JobModuleDiscipline.emd:
      return 'EMD';
    case JobModuleDiscipline.refractory:
      return 'Refractory';
    case JobModuleDiscipline.shiftInCharge:
      return 'Shift in-charge';
    case JobModuleDiscipline.safety:
      return 'Safety';
    case JobModuleDiscipline.admin:
      return 'Admin/SI';
    case JobModuleDiscipline.shared:
      return 'Shared';
    case JobModuleDiscipline.others:
      return 'Others';
  }
}

Color _disciplineColor(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return BafColors.assets;
    case JobModuleDiscipline.electrical:
      return BafColors.danger;
    case JobModuleDiscipline.instrumentation:
      return BafColors.planned;
    case JobModuleDiscipline.operations:
      return BafColors.sync;
    case JobModuleDiscipline.emd:
      return BafColors.admin;
    case JobModuleDiscipline.refractory:
      return BafColors.warning;
    case JobModuleDiscipline.shiftInCharge:
      return BafColors.charges;
    case JobModuleDiscipline.safety:
      return BafColors.warning;
    case JobModuleDiscipline.admin:
    case JobModuleDiscipline.shared:
    case JobModuleDiscipline.others:
      return BafColors.admin;
  }
}

String _useModeLabel(JobModuleUseMode mode) {
  switch (mode) {
    case JobModuleUseMode.scheduledPM:
      return 'Scheduled PM';
    case JobModuleUseMode.troubleshooting:
      return 'Troubleshooting';
    case JobModuleUseMode.correctiveFollowUp:
      return 'Corrective follow-up';
    case JobModuleUseMode.shutdownWork:
      return 'Shutdown work';
    case JobModuleUseMode.preStartVerification:
      return 'Pre-start verification';
    case JobModuleUseMode.postRepairVerification:
      return 'Post-repair verification';
    case JobModuleUseMode.futurePackage:
      return 'Future package';
    case JobModuleUseMode.adHoc:
      return 'Ad-hoc';
  }
}

String _safetyLabel(JobModuleSafetyClass safetyClass) {
  switch (safetyClass) {
    case JobModuleSafetyClass.normal:
      return 'Normal';
    case JobModuleSafetyClass.lotoRequired:
      return 'LOTO';
    case JobModuleSafetyClass.gasRisk:
      return 'Gas risk';
    case JobModuleSafetyClass.hotSurface:
      return 'Hot surface';
    case JobModuleSafetyClass.pressureTest:
      return 'Pressure test';
    case JobModuleSafetyClass.liftingRisk:
      return 'Lifting risk';
    case JobModuleSafetyClass.electricalPanel:
      return 'Electrical panel';
    case JobModuleSafetyClass.combustionSpecialist:
      return 'Combustion';
    case JobModuleSafetyClass.configurationControl:
      return 'Config control';
  }
}

Color _safetyColor(JobModuleSafetyClass safetyClass) {
  switch (safetyClass) {
    case JobModuleSafetyClass.normal:
      return BafColors.admin;
    case JobModuleSafetyClass.lotoRequired:
    case JobModuleSafetyClass.gasRisk:
    case JobModuleSafetyClass.combustionSpecialist:
      return BafColors.danger;
    case JobModuleSafetyClass.hotSurface:
    case JobModuleSafetyClass.pressureTest:
    case JobModuleSafetyClass.liftingRisk:
      return BafColors.warning;
    case JobModuleSafetyClass.electricalPanel:
    case JobModuleSafetyClass.configurationControl:
      return BafColors.planned;
  }
}

String _display(String? value, String fallback) {
  final cleaned = _cleanOptionalString(value);
  return cleaned ?? fallback;
}

String? _cleanOptionalString(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool _hasText(String? value) => _cleanOptionalString(value) != null;
