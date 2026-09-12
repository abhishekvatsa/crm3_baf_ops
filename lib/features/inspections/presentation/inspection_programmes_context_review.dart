part of 'inspection_programmes_screen.dart';

class _InspectionContextReviewDialog extends ConsumerStatefulWidget {
  const _InspectionContextReviewDialog({
    required this.campaign,
    required this.originUid,
  });
  final InspectionCampaign campaign;
  final String originUid;
  @override
  ConsumerState<_InspectionContextReviewDialog> createState() =>
      _InspectionContextReviewDialogState();
}

class _InspectionContextReviewDialogState
    extends ConsumerState<_InspectionContextReviewDialog> {
  final _reason = TextEditingController();
  InspectionCampaignTarget? _target;
  Map<String, Object?>? _reviewed;
  WorkflowCommand? _submitted;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool _authorized() {
    final access = CurrentActorAccess.resolve(ref.read(currentAppUserProvider));
    if (!access.isReady ||
        access.actor!.uid != widget.originUid ||
        !access.actor!.canManageInspectionCampaigns) {
      setState(
        () => _message = !access.isReady
            ? access.message
            : 'Return to the approved account that opened this review. Your entries are retained.',
      );
      return false;
    }
    return true;
  }

  Future<void> _load() async {
    if (_busy || _target == null || !_authorized()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final reviewed = await ref
          .read(inspectionRepositoryProvider)
          .readTargetContext(_target!);
      if (!mounted) return;
      if (!_authorized()) return;
      setState(() => _reviewed = reviewed);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _message = 'The current target could not be checked: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_busy || _target == null || _reviewed == null || !_authorized()) return;
    if (_submitted == null && _reason.text.trim().isEmpty) {
      setState(
        () => _message =
            'Explain why this same physical asset is ready for follow-up.',
      );
      return;
    }
    _submitted ??= WorkflowCommand(
      commandId: 'revalidateInspectionTargetContext_${const Uuid().v4()}',
      type: WorkflowCommandType.revalidateInspectionTargetContext,
      aggregateId: widget.campaign.id,
      expectedVersion: widget.campaign.version,
      payload: {
        'reviewerUid': widget.originUid,
        'targetKey': _target!.targetKey,
        'expectedContextRevision': _target!.contextRevision,
        'reviewedContext': _reviewed!,
        'reason': _reason.text.trim(),
      },
    );
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(inspectionTargetContextCapabilityProvider)(
        widget.originUid,
      );
      if (!mounted || !_authorized()) return;
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(_submitted!);
      if (!mounted) return;
      if (!_authorized()) {
        setState(
          () => _message =
              'The review was accepted. Return to the original account to inspect its updated campaign.',
        );
        return;
      }
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'The review could not be confirmed: $error. Retry checks the same review. Its entries remain unchanged while this form stays open.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    final ready =
        access.isReady &&
        access.actor!.uid == widget.originUid &&
        access.actor!.canManageInspectionCampaigns;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Review the same physical target'),
        content: SizedBox(
          width: 520,
          child: !ready
              ? Text(
                  !access.isReady
                      ? access.message
                      : 'Return to the approved original account to continue. Your entries are retained.',
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Use this after repair or relocation. The original campaign target, readings and baseline are retained. This cannot substitute another Inner Cover serial. Everyone using this campaign must update the app before you approve this review.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('inspection-context-target'),
                        initialValue: _target?.targetKey,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Original campaign target',
                        ),
                        items: widget.campaign.targets
                            .map(
                              (target) => DropdownMenuItem(
                                value: target.targetKey,
                                child: Text(
                                  '${target.rowLabel} · ${target.physicalPosition ?? target.componentNodeId ?? "Asset"}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy || _submitted != null
                            ? null
                            : (key) => setState(() {
                                _target = widget.campaign.targets.firstWhere(
                                  (target) => target.targetKey == key,
                                );
                                _reviewed = null;
                                _message = null;
                              }),
                      ),
                      if (_target != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Original: ${_target!.assetInstanceName} · revision ${_target!.assetInstanceVersion}'
                          '${_target!.hostAssetNumber == null ? "" : " · Base ${_target!.hostAssetNumber}"}',
                        ),
                        if (_target!.contextReview != null)
                          Text(
                            'Previous review ${_target!.contextRevision}: ${_target!.contextReview!.reviewedByName} · ${_target!.contextReview!.reason}',
                          ),
                        TextButton(
                          onPressed: _busy || !ready || _submitted != null
                              ? null
                              : _load,
                          child: const Text('Check current physical context'),
                        ),
                      ],
                      if (_reviewed != null) ...[
                        Text(
                          'Current: ${_reviewed!["assetInstanceName"]} · revision ${_reviewed!["assetInstanceVersion"]}'
                          '${_reviewed!["hostAssetNumber"] == null ? "" : " · Base ${_reviewed!["hostAssetNumber"]} · linkage ${_reviewed!["linkageId"]}"}',
                        ),
                        SelectableText(
                          'Same physical ID: ${_reviewed!["assetInstanceId"]}',
                        ),
                        TextField(
                          key: const ValueKey('inspection-context-reason'),
                          controller: _reason,
                          readOnly: _submitted != null,
                          maxLength: 1000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Review reason',
                          ),
                        ),
                      ],
                      if (_message != null)
                        Text(
                          _message!,
                          style: const TextStyle(color: BafColors.danger),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: _busy || !ready || _reviewed == null ? null : _approve,
            child: Text(
              _busy
                  ? 'Checking…'
                  : _submitted != null
                  ? 'Retry same review'
                  : 'Approve same-target follow-up',
            ),
          ),
        ],
      ),
    );
  }
}
