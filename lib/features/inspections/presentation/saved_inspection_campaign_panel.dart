import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/inspection_campaign_submission.dart';
import '../providers/inspection_campaign_submission_provider.dart';
import '../providers/inspection_provider.dart';

String inspectionCampaignSubmissionMessage(Object error) => switch (error) {
  InspectionCampaignSubmissionException() => error.message,
  DurableSubmissionException() => error.message,
  CommandCapabilityException() => error.message,
  _ =>
    'The programme could not be confirmed. Any saved entries are retained; check the saved programme before trying again.',
};

/// Visible outside the campaign browse lists, so saved work remains reachable
/// when current definitions or populations cannot be loaded.
class SavedInspectionCampaignPanel extends ConsumerWidget {
  const SavedInspectionCampaignPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    if (!access.isReady || !access.actor!.canManageInspectionCampaigns) {
      return const SizedBox.shrink();
    }
    final pending = ref.watch(pendingInspectionCampaignSubmissionProvider);
    if (pending.isLoading) return const LinearProgressIndicator();
    if (pending.hasError) {
      return ListTile(
        title: const Text('Saved programme evidence could not be checked.'),
        trailing: TextButton(
          onPressed: () =>
              ref.invalidate(pendingInspectionCampaignSubmissionProvider),
          child: const Text('Retry'),
        ),
      );
    }
    final saved = pending.valueOrNull;
    if (saved == null || saved.actorUid != access.actor!.uid) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: const Icon(Icons.pending_actions_outlined),
      title: const Text('A saved programme needs confirmation'),
      subtitle: const Text('Its original entries are retained on this device.'),
      trailing: TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => SavedInspectionCampaignDialog(submission: saved),
        ),
        child: const Text('Review saved programme'),
      ),
    );
  }
}

class SavedInspectionCampaignDialog extends ConsumerStatefulWidget {
  const SavedInspectionCampaignDialog({super.key, required this.submission});
  final DurableSubmission submission;
  @override
  ConsumerState<SavedInspectionCampaignDialog> createState() =>
      _SavedInspectionCampaignDialogState();
}

class _SavedInspectionCampaignDialogState
    extends ConsumerState<SavedInspectionCampaignDialog> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    final allowed =
        access.isReady &&
        access.actor!.canManageInspectionCampaigns &&
        access.actor!.uid == widget.submission.actorUid;
    if (!allowed) {
      return AlertDialog(
        title: const Text('Saved programme'),
        content: Text(
          access.isReady
              ? 'Return to the account that saved this programme to view or check its entries.'
              : access.message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final InspectionCampaignSubmission frozen;
    try {
      frozen = InspectionCampaignSubmission.parse(
        widget.submission.envelopeJson,
      );
    } catch (_) {
      return AlertDialog(
        title: const Text('Saved programme needs review'),
        content: const Text(
          'The original evidence is retained, but its entries cannot be read safely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final payload = frozen.command.payload;
    String values(String key) => (payload[key] as List).join(', ');
    return AlertDialog(
      title: const Text('Saved inspection programme'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'These entries are fixed for this request. Checking uses the same programme and request again.',
              ),
              const SizedBox(height: 16),
              Text(
                payload['purpose'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Definition: ${payload['definitionId']} · revision ${payload['definitionVersion']}',
              ),
              Text('Asset class: ${payload['assetClassId']}'),
              Text('Assets: ${values('targetAssetNumbers')}'),
              Text('Expected targets: ${payload['expectedPopulation']}'),
              Text(
                'Positions: ${values('physicalPositionLabels').isEmpty ? 'Whole asset' : values('physicalPositionLabels')}',
              ),
              Text(
                'Population: ${payload['populationMode'] == 'installedInnerCoversByBase' ? 'Installed Inner Covers by Base' : 'Selected assets'}',
              ),
              if (payload['hostAssetClassId'] != null)
                Text('Host class: ${payload['hostAssetClassId']}'),
              Text(
                'Baseline: ${payload['baselineCampaignId'] ?? 'First campaign'}',
              ),
              Text('Observers: ${values('observerRoleKeys')}'),
              Text('Opening reason: ${payload['reason']}'),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_message!),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (widget.submission.state == DurableSubmissionState.intent &&
            widget.submission.attemptCount == 0)
          TextButton(
            onPressed: _busy ? null : () => _run(cancel: true),
            child: const Text('Cancel unsent programme'),
          ),
        FilledButton(
          onPressed: _busy ? null : () => _run(),
          child: const Text('Check saved programme'),
        ),
      ],
    );
  }

  Future<void> _run({bool cancel = false}) async {
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final controller = container.read(
        inspectionCampaignSubmissionControllerProvider,
      );
      if (cancel) {
        await controller.cancelNeverSent(widget.submission.submissionId);
      } else {
        await controller.check(widget.submission.submissionId);
        container.invalidate(inspectionCampaignsProvider);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _message = inspectionCampaignSubmissionMessage(error));
      }
    } finally {
      container.invalidate(pendingInspectionCampaignSubmissionProvider);
      if (mounted) setState(() => _busy = false);
    }
  }
}
