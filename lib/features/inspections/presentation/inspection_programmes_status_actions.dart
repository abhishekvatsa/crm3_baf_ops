part of 'inspection_programmes_screen.dart';

Future<void> _transitionCampaign(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  String status,
) async {
  final originUid = ref.read(currentAppUserProvider).value?.uid;
  if (originUid == null) return;
  final reopening =
      campaign.status == InspectionCampaignStatus.closed && status == 'open';
  String? reopeningReason;
  if (reopening) {
    reopeningReason = await showDialog<String>(
      context: context,
      builder: (_) => const _InspectionReasonDialog(
        title: 'Reopen survey scope?',
        message:
            'Existing findings already allow follow-up and verification while the survey stays closed. '
            'Reopen only to resume survey work. The original closure and readings remain in its '
            'audit history. Explain why the survey itself needs reopening.',
        actionLabel: 'Reopen campaign',
      ),
    );
    if (reopeningReason == null || !context.mounted) return;
  }
  if (status == 'closed' && !campaign.canClose) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${campaign.remainingPopulation} target${campaign.remainingPopulation == 1 ? '' : 's'} still need evidence or an explicit disposition.',
        ),
        backgroundColor: BafColors.warning,
      ),
    );
    return;
  }
  final confirmed =
      status != 'closed' ||
      await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Close this programme?'),
              content: const Text(
                'All targets are accounted. Outstanding findings and their maintenance work remain open. Follow-up readings and verification can continue from those findings without reopening this survey.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep open'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Close'),
                ),
              ],
            ),
          ) ==
          true;
  if (!confirmed || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'setInspectionCampaignStatus_${const Uuid().v4()}',
      type: WorkflowCommandType.setInspectionCampaignStatus,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'status': status,
        'reason':
            reopeningReason ?? 'Move the inspection programme to $status.',
      },
    ),
    reopening
        ? 'Inspection survey reopened.'
        : 'Inspection campaign moved to $status.',
    originUid: originUid,
  );
}
