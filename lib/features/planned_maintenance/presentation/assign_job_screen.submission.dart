part of 'assign_job_screen.dart';

extension _AssignJobSubmission on _AssignJobScreenState {
  Future<void> _submit() async {
    final templateFirestoreId = widget.template.firestoreId?.trim();
    if (templateFirestoreId == null || templateFirestoreId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot assign: template is missing its local sync ID.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final actorAsync = ref.read(currentAppUserProvider);
    final appUser = actorAsync.isLoading || actorAsync.hasError
        ? null
        : actorAsync.value;
    if (appUser == null || !appUser.canAssignJobExecution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authorized to assign planned jobs.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    if (_isSubmitting) return;
    _setSubmitting(true);

    void Function()? releaseAdmission;
    try {
      releaseAdmission = claimLegacyAssignmentAdmission(
        appUser.uid,
        templateFirestoreId,
      );
      final saved = retainedLegacyAssignment(
        await ref.read(workflowRepositoryProvider).getPendingCommands(),
        actorUid: appUser.uid,
        templateId: templateFirestoreId,
      );
      if (!mounted) return;
      final liveActor = ref.read(currentAppUserProvider).asData?.value;
      if (liveActor?.uid != appUser.uid ||
          liveActor?.canAssignJobExecution != true) {
        throw StateError(
          'The original account is no longer active. Nothing was sent.',
        );
      }
      WorkflowCommand command;
      if (saved != null) {
        final check = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Check earlier assignment'),
            content: Text(
              'This template has an assignment awaiting confirmation. Check its original request before starting another.\n\nAsset: ${saved.payload['assetInstanceId']}\nCharge: ${saved.payload['chargeNoAtEvent'] ?? 'Not recorded'}\nRemarks: ${saved.payload['remarks'] ?? 'None'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep saved'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Check original request'),
              ),
            ],
          ),
        );
        if (!mounted || check != true) return;
        command = saved;
      } else {
        if (!_formKey.currentState!.validate()) return;
        final selectedAsset = _selectedGovernedAsset();
        if (selectedAsset == null) {
          throw const WorkflowException(
            WorkflowErrorCode.invalidArgument,
            'Choose an active physical asset from the governed register.',
          );
        }
        final payload = <String, Object?>{
          'assignmentSchemaVersion': 2,
          'templateFirestoreId': templateFirestoreId,
          'expectedTemplateVersion': widget.template.version,
          'assetClassId': selectedAsset.assetClassId,
          'assetInstanceId': selectedAsset.id,
          if (_parseOptionalInt(_chargeNoController.text) case final chargeNo?)
            'chargeNoAtEvent': chargeNo,
          if (_cleanOptionalText(_remarksController.text) case final remarks?)
            'remarks': remarks,
        };
        final fingerprint = jsonEncode(payload);
        if (_pendingCommandId != null &&
            _pendingSubmissionFingerprint != fingerprint) {
          throw StateError(
            'The earlier assignment is still awaiting confirmation. Restore its original entries and check it before starting different work. Your new entries have not been sent.',
          );
        }
        if (_pendingSubmissionFingerprint != fingerprint ||
            _pendingExecutionId == null ||
            _pendingCommandId == null) {
          _pendingSubmissionFingerprint = fingerprint;
          _pendingExecutionId = const Uuid().v4();
          _pendingCommandId = WorkflowCommandFactory.uniqueId(
            'createLegacyWorkflowJob_$_pendingExecutionId',
          );
        }
        final executionId = _pendingExecutionId!;
        command = WorkflowCommand(
          commandId: _pendingCommandId!,
          type: WorkflowCommandType.createLegacyWorkflowJob,
          aggregateId: executionId,
          expectedVersion: 0,
          payload: {...payload, 'executionId': executionId},
        );
      }
      final liveBeforeSend = ref.read(currentAppUserProvider).asData?.value;
      if (liveBeforeSend?.uid != appUser.uid ||
          liveBeforeSend?.canAssignJobExecution != true) {
        throw StateError(
          'Return to the account that saved this request. Nothing was sent.',
        );
      }
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'workflow_job_assigned',
          force: true,
        ),
      );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      Navigator.pop(context);

      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Job assigned to ${widget.template.assignedAgencies.map((a) => a.toUpperCase()).join(', ')}',
          ),
          backgroundColor: BafColors.sync,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message =
          e is WorkflowException && e.code == WorkflowErrorCode.unavailable
          ? 'Assignment outcome could not be confirmed. Reopen this template while connected to check the saved original request before starting another assignment.'
          : 'Failed to assign job: $e';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: BafColors.danger),
      );
    } finally {
      releaseAdmission?.call();
      if (mounted) _setSubmitting(false);
    }
  }
}
