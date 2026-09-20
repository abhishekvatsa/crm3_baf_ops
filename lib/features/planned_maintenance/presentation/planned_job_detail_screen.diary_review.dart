part of 'planned_job_detail_screen.dart';

extension _DiaryFollowUpReview on _PlannedJobDetailScreenState {
  Future<void> _reviewDiaryFollowUp(JobDiaryEntry original) async {
    final actor = ref.read(currentAppUserProvider).valueOrNull;
    if (actor == null ||
        !actor.canEditJobDiaryEntry(createdByUid: original.createdByUid)) {
      return;
    }
    final decision = await showDialog<_DiaryFollowUpDecision>(
      context: context,
      builder: (_) => _DiaryFollowUpDialog(original: original),
    );
    if (!mounted || decision == null) return;
    final currentActor = ref.read(currentAppUserProvider).valueOrNull;
    if (currentActor == null ||
        currentActor.uid != actor.uid ||
        !currentActor.canEditJobDiaryEntry(
          createdByUid: original.createdByUid,
        )) {
      return;
    }
    final explanation = decision.reason;
    try {
      final changed = JobDiaryEntry.fromMap(
        original.toMap(),
        original.firestoreId!,
      )..id = original.id;
      changed.isSynced = original.isSynced;
      changed.blockerStatus = original.isBlocker ? decision.disposition : null;
      changed.requiresFollowUp = decision.followUp;
      changed.metadataJson = jsonEncode({
        ...changed.syncReviewMetadata,
        'diaryAmendmentReason': explanation,
      });
      changed.actionTaken = explanation;
      await ref
          .read(jobDiaryRepositoryProvider)
          .saveEntry(
            changed,
            actor: currentActor,
            auditContext: AuditContext(
              performedByUid: actor.uid,
              performedByName: actor.name,
              reasonNotes: explanation,
              summary: 'Reviewed diary follow-up',
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Follow-up review saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save review: $error')),
        );
      }
    }
  }
}

class _DiaryFollowUpDecision {
  const _DiaryFollowUpDecision(this.disposition, this.followUp, this.reason);
  final JobBlockerStatus disposition;
  final bool followUp;
  final String reason;
}

class _DiaryFollowUpDialog extends StatefulWidget {
  const _DiaryFollowUpDialog({required this.original});
  final JobDiaryEntry original;
  @override
  State<_DiaryFollowUpDialog> createState() => _DiaryFollowUpDialogState();
}

class _DiaryFollowUpDialogState extends State<_DiaryFollowUpDialog> {
  final reason = TextEditingController();
  late JobBlockerStatus disposition =
      widget.original.blockerStatus ?? JobBlockerStatus.open;
  late bool followUp = widget.original.requiresFollowUp;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review diary follow-up'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This records follow-up disposition and preserves the earlier note. It does not change physical job closure.',
          ),
          if (widget.original.isBlocker)
            DropdownButtonFormField<JobBlockerStatus>(
              isExpanded: true,
              initialValue: disposition,
              items: JobBlockerStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_blockerStatusLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    disposition = value;
                    if (value == JobBlockerStatus.carriedForward ||
                        value == JobBlockerStatus.open) {
                      followUp = true;
                    }
                  });
                }
              },
            ),
          CheckboxListTile(
            title: const Text('Further follow-up remains required'),
            value: followUp,
            onChanged: (value) => setState(() => followUp = value ?? true),
          ),
          TextField(
            controller: reason,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Reason and follow-up owner / reference',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            reason.text.trim().isEmpty ||
                (widget.original.isBlocker &&
                    (disposition == JobBlockerStatus.open ||
                        disposition == JobBlockerStatus.carriedForward) &&
                    !followUp)
            ? null
            : () => Navigator.pop(
                context,
                _DiaryFollowUpDecision(
                  disposition,
                  followUp,
                  reason.text.trim(),
                ),
              ),
        child: const Text('Save review'),
      ),
    ],
  );
}
