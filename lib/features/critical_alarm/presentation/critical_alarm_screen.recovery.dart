part of 'critical_alarm_screen.dart';

class _PendingCriticalAlarmCommands extends ConsumerWidget {
  const _PendingCriticalAlarmCommands();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(criticalAlarmPendingSubmissionsProvider);
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Material(
        color: BafColors.danger.withValues(alpha: 0.08),
        child: const ListTile(
          leading: Icon(Icons.storage_outlined, color: BafColors.danger),
          title: Text('Saved alarm recovery unavailable'),
          subtitle: Text(
            'Restart CRM3 before raising or checking a command so the original request can be retained safely.',
          ),
        ),
      ),
      data: (submissions) {
        if (submissions.isEmpty) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView(
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            children: [
              for (final submission in submissions)
                Material(
                  color: BafColors.warning.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          submissions.length == 1
                              ? 'Saved alarm command needs review'
                              : '${submissions.length} saved alarm commands need review',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          submission.lastErrorMessage ??
                              'The original request is preserved on this device.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        TextButton(
                          onPressed: () => _resume(context, ref, submission),
                          child: const Text('Review and retry'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    DurableSubmission submission,
  ) async {
    final String preview;
    try {
      preview = _savedCommandPreview(submission);
    } catch (error) {
      _showCommandFailure(context, error);
      return;
    }
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry this saved action?'),
        content: SingleChildScrollView(
          child: Text(
            '$preview\n\nThis sends the original saved action again. '
            'If it was already accepted, its receipt is returned. '
            'If it was never accepted, it may take effect now. '
            'Retry only if this action is still appropriate. '
            'Follow the plant emergency procedure first.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep saved'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm and retry'),
          ),
        ],
      ),
    );
    if (retry != true || !context.mounted) return;
    _showProgress(context, 'Retrying saved critical alarm command');
    try {
      await ref
          .read(criticalAlarmCommandServiceProvider)
          .resume(submission.submissionId);
      ref.invalidate(criticalAlarmPendingSubmissionsProvider);
      ref.invalidate(criticalAlarmFeedProvider);
      ref.invalidate(activeCriticalAlarmsProvider);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved alarm command confirmed.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showCommandFailure(context, error, dispatch: true);
      ref.invalidate(criticalAlarmPendingSubmissionsProvider);
    }
  }
}

String _savedCommandPreview(DurableSubmission submission) {
  final command = submission.envelope['command'];
  if (command is! Map || command['payload'] is! Map) {
    throw const DurableSubmissionException(
      'invalid-alarm-command',
      'The saved alarm action cannot be read safely. It remains preserved for review.',
    );
  }
  final action = switch (command['commandType']) {
    'raiseCriticalAlarm' => 'Raise alarm',
    'provideCriticalAlarmDetails' => 'Update alarm details',
    'confirmCriticalAlarmSupport' => 'Confirm support',
    'resolveCriticalAlarm' => 'Resolve alarm',
    'withdrawCriticalAlarmInError' => 'Withdraw alarm entered in error',
    'upsertCriticalAlarmContact' => 'Save emergency contact',
    'setCriticalAlarmContactStatus' => 'Change emergency contact status',
    'upsertCriticalAlarmDefinition' => 'Save alarm reason',
    'setCriticalAlarmDefinitionStatus' => 'Change alarm reason status',
    _ => throw const DurableSubmissionException(
      'unsupported-alarm-command',
      'This saved action needs review before it can be retried.',
    ),
  };
  final payload = command['payload'] as Map;
  final lines = <String>[
    action,
    'Saved: ${DateFormat('d MMM yyyy, HH:mm').format(submission.createdAt.toLocal())}',
    'Reference: ${submission.aggregateId}',
  ];
  void addFields(Map data, Map<String, String> labels) {
    for (final entry in labels.entries) {
      final value = data[entry.key];
      if (value != null && value.toString().trim().isNotEmpty) {
        lines.add(
          '${entry.value}: ${value is List ? value.join(', ') : value}',
        );
      }
    }
  }

  addFields(payload, const {
    'alarmTypeKey': 'Alarm reason',
    'location': 'Location',
    'assetTypeKey': 'Equipment type',
    'assetNumber': 'Equipment number',
    'initialDetails': 'Details',
    'details': 'Details',
    'basis': 'Support basis',
    'responderNote': 'Support note',
    'resolutionSummary': 'Resolution',
    'status': 'Status',
    'reason': 'Reason for change',
  });
  final contact = payload['contact'];
  if (contact is Map) {
    addFields(contact, const {
      'label': 'Contact',
      'contactKind': 'Contact type',
      'dialValue': 'Phone',
      'alarmTypeKeys': 'Alarm reasons',
      'priority': 'Priority',
      'notes': 'Notes',
    });
  }
  final definition = payload['definition'];
  if (definition is Map) {
    addFields(definition, const {
      'name': 'Alarm reason',
      'criticalityKey': 'Criticality',
      'criticalityRank': 'Priority',
    });
  }
  return lines.join('\n');
}
