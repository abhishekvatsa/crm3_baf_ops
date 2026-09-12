import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/user_model.dart';
import '../../../auth/domain/current_actor_access.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/job_module_model.dart';
import '../../providers/job_module_provider.dart';
import '../../widgets/action_mini_card.dart';
import 'job_module_response_summary.dart';

/// Opens actor-owned native conflict history. A fresh module preimage is
/// captured before review; confirmation never bypasses the repository CAS.
Future<JobModuleInstance?> showJobModuleDraftRecovery(
  BuildContext context,
  WidgetRef ref, {
  required JobModuleInstance module,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  AppUser actor([String? origin]) {
    final access = CurrentActorAccess.resolve(
      container.read(currentAppUserProvider),
    );
    final current = access.actor;
    if (!access.isReady ||
        current == null ||
        (origin != null && current.uid != origin) ||
        !current.canSaveJobModuleWorkFor(module.discipline.name)) {
      throw StateError(
        'Verify the original account to review its saved drafts.',
      );
    }
    return current;
  }

  try {
    final origin = actor();
    final recovery = JobModuleDraftRecovery(
      repository: IsarJobModuleRepository(
        verifyActor: (expected) {
          actor(expected.uid);
        },
      ),
    );
    final saved = await recovery.list(actor: origin, moduleLocalId: module.id);
    actor(origin.uid);
    if (!context.mounted) return null;
    final selected = await showDialog<JobModuleSavedDraft>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final access = CurrentActorAccess.resolve(
            ref.watch(currentAppUserProvider),
          );
          final sameActor =
              access.isReady &&
              access.actor?.uid == origin.uid &&
              access.actor!.canSaveJobModuleWorkFor(module.discipline.name);
          return AlertDialog(
            title: const Text('Saved drafts'),
            content: SizedBox(
              width: 560,
              child: !sameActor
                  ? const Text(
                      'Verify the original account to view these drafts.',
                    )
                  : saved.isEmpty
                  ? const Text(
                      'There are no saved edit conflicts for this module.',
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        const Text(
                          'These drafts were kept when a save could not safely change the module.',
                        ),
                        for (final draft in saved)
                          ListTile(
                            leading: const Icon(Icons.history_rounded),
                            title: Text(
                              DateFormat(
                                'd MMM yyyy, HH:mm',
                              ).format(draft.savedAt),
                            ),
                            subtitle: const Text('Review saved work'),
                            onTap: () => Navigator.pop(context, draft),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    if (selected == null) return null;
    final review = await recovery.review(
      actor: actor(origin.uid),
      saved: selected,
    );
    actor(origin.uid);
    if (!context.mounted) return null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          JobModuleDraftReviewDialog(review: review, originUid: origin.uid),
    );
    if (confirmed != true) return null;
    final result = await recovery.apply(
      actor: actor(origin.uid),
      review: review,
    );
    actor(origin.uid);
    return result;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is JobModuleSaveConflict
                ? error.toString()
                : 'The saved draft could not be applied. It is still retained. Refresh the job and verify your account.',
          ),
        ),
      );
    }
    return null;
  }
}

class JobModuleDraftReviewDialog extends ConsumerStatefulWidget {
  final JobModuleDraftReview review;
  final String originUid;
  const JobModuleDraftReviewDialog({
    super.key,
    required this.review,
    required this.originUid,
  });
  @override
  ConsumerState<JobModuleDraftReviewDialog> createState() =>
      JobModuleDraftReviewDialogState();
}

class JobModuleDraftReviewDialogState
    extends ConsumerState<JobModuleDraftReviewDialog> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    final sameActor =
        access.isReady &&
        access.actor?.uid == widget.originUid &&
        access.actor!.canSaveJobModuleWorkFor(
          widget.review.current.discipline.name,
        );
    if (!sameActor) {
      return AlertDialog(
        title: const Text('Verify your account'),
        content: const Text('Use the original account to review this draft.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final draft = widget.review.recoveryCandidate();
    final blocked = widget.review.blockingReason != null;
    return AlertDialog(
      title: const Text('Review before restoring work'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compare the current work with your saved draft. Restoring replaces responses, component actions and progress notes with the saved values. The original conflict remains in history.',
              ),
              const SizedBox(height: 16),
              _WorkEvidence(
                title: 'Current module',
                module: widget.review.current,
              ),
              const Divider(height: 32),
              _WorkEvidence(title: 'Your saved draft', module: draft),
              if (blocked)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'This module or its parent job is not open for editing. Your draft remains available for review.',
                  ),
                )
              else
                CheckboxListTile(
                  value: confirmed,
                  onChanged: (value) =>
                      setState(() => confirmed = value == true),
                  title: const Text(
                    'I have reviewed both versions and want to replace the current work with this draft.',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep both'),
        ),
        FilledButton(
          onPressed: !blocked && confirmed
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Restore reviewed work'),
        ),
      ],
    );
  }
}

class _WorkEvidence extends StatelessWidget {
  final String title;
  final JobModuleInstance module;
  const _WorkEvidence({required this.title, required this.module});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      Text('Progress: ${module.status.name}'),
      Text('Notes: ${module.draftNote ?? "None"}'),
      Text('Pending issue: ${module.pendingIssue ?? "None"}'),
      Text('Follow-up needed: ${module.requiresFollowUp ? "Yes" : "No"}'),
      const SizedBox(height: 8),
      JobModuleResponseSummary(responses: module.responses),
      for (final action in module.actions) ActionMiniCard(action: action),
      if (module.actions.isEmpty) const Text('No component actions.'),
    ],
  );
}
