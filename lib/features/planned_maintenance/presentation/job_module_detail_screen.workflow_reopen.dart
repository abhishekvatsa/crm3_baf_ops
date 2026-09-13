part of 'job_module_detail_screen.dart';

extension _WorkflowModuleReopenActions on _JobModuleDetailScreenState {
  void _requireReopenOrigin(AppUser origin) {
    if (!mounted) {
      throw StateError(
        'The module screen was closed. Its saved request is retained.',
      );
    }
    final message = currentActorActionMessage(
      CurrentActorAccess.resolve(ref.read(currentAppUserProvider)),
      originUid: origin.uid,
      permission: (actor) => actor.canReopenJobModule,
    );
    if (message != null) throw StateError(message);
  }

  Future<void> _checkSavedWorkflowReopen(String submissionId) async {
    final actor = await _readActor();
    if (!mounted || actor == null) return;
    await _runBusyAction(
      successMessage: 'Current module state confirmed',
      action: () async {
        _requireReopenOrigin(actor);
        final confirmed = await ref
            .read(workflowModuleReopenControllerProvider)
            .check(submissionId);
        _requireReopenOrigin(actor);
        _showConfirmedWorkflowModule(confirmed);
        ref.invalidate(
          pendingWorkflowModuleReopenProvider(confirmed.firestoreId!),
        );
      },
    );
  }

  Future<void> _reopenModule() async {
    final actor = await _readActor();
    if (!mounted || actor == null) return;
    try {
      _requireReopenOrigin(actor);
      final executionId = _cleanOptionalString(widget.execution.firestoreId);
      final moduleId = _cleanOptionalString(_module.firestoreId);
      final workflowManaged = widget.execution.workflowSchemaVersion == 1;
      final baseline = copyJobModuleForEditing(_module);
      if (workflowManaged && (executionId == null || moduleId == null)) {
        throw StateError(
          'Workflow identity is incomplete. Sync this job before reopening.',
        );
      }
      if (workflowManaged && !kIsWeb) {
        final pending = await ref
            .read(workflowModuleReopenControllerProvider)
            .restore(moduleId!);
        _requireReopenOrigin(actor);
        if (pending != null) {
          await _checkSavedWorkflowReopen(pending.submissionId);
          return;
        }
      }
      final reason = await _openReasonSheet(
        title: 'Reopen module',
        description:
            'Reopening makes the module editable again and records an audit reason.',
        label: 'Reopen reason',
        required: true,
        actionLabel: 'Reopen Module',
        actionColor: BafColors.danger,
        originUid: actor.uid,
      );
      if (!mounted || reason == null) return;
      _requireReopenOrigin(actor);
      await _runBusyAction(
        successMessage: 'Module state confirmed',
        action: () async {
          _requireReopenOrigin(actor);
          if (workflowManaged) {
            final workflow = await ref
                .read(workflowRepositoryProvider)
                .getWorkflow(executionId!);
            _requireReopenOrigin(actor);
            if (workflow == null) {
              throw StateError('Sync the maintenance workflow and retry.');
            }
            JobModuleInstance confirmed;
            if (!kIsWeb) {
              final controller = ref.read(
                workflowModuleReopenControllerProvider,
              );
              final saved = await controller.prepare(
                actorUid: actor.uid,
                executionId: executionId,
                workflowVersion: workflow.version,
                reason: reason,
                baseline: baseline,
              );
              ref.invalidate(pendingWorkflowModuleReopenProvider(moduleId!));
              confirmed = await controller.check(saved.submissionId);
            } else {
              // Web keeps its existing workflow receipt store; display only a
              // fresh server projection instead of manufacturing lifecycle state.
              final command = WorkflowCommandFactory.create(
                type: WorkflowCommandType.reopenWorkflowModule,
                aggregateId: executionId,
                expectedVersion: workflow.version,
                payload: {'moduleFirestoreId': moduleId, 'reason': reason},
              );
              final receipt = await ref
                  .read(workflowCommandControllerProvider.notifier)
                  .execute(command);
              _requireReopenOrigin(actor);
              confirmed = await readWorkflowReopenedModule(
                read: readWorkflowModuleDocumentFromServer,
                receipt: receipt,
                executionId: executionId,
                moduleId: moduleId!,
                actorUid: actor.uid,
                reason: reason,
                baseline: baseline,
              );
            }
            _requireReopenOrigin(actor);
            _showConfirmedWorkflowModule(confirmed);
            if (!kIsWeb) {
              ref.invalidate(pendingWorkflowModuleReopenProvider(moduleId));
            }
            return;
          }
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
          _requireReopenOrigin(actor);
          final current = copyJobModuleForEditing(_module)
            ..status = JobModuleStatus.reopened
            ..reopenedByUid = actor.uid
            ..reopenedByName = actor.name
            ..reopenedAt = DateTime.now().toUtc()
            ..reopenReason = reason
            ..updatedByUid = actor.uid
            ..updatedByName = actor.name
            ..isSynced = kIsWeb;
          _showConfirmedWorkflowModule(current);
        },
      );
    } catch (error) {
      if (mounted) _showSnack(error.toString(), isError: true);
    }
  }
}

class _SavedWorkflowModuleReopen extends ConsumerWidget {
  const _SavedWorkflowModuleReopen({
    required this.moduleId,
    required this.isBusy,
    required this.onCheck,
  });
  final String moduleId;
  final bool isBusy;
  final Future<void> Function(String) onCheck;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkflowModuleReopenProvider(moduleId));
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const CurrentActorNotice(
        message:
            'A saved module reopen needs the original account or storage review.',
      ),
      data: (row) => row == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: BafSpacing.md),
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => onCheck(row.submissionId),
                icon: const Icon(Icons.restore),
                label: const Text('Check saved reopen'),
              ),
            ),
    );
  }
}
