import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/release/command_capability_service.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/published_template_assignment_server_service.dart';
import '../services/published_template_assignment_submission_controller.dart';

String publishedAssignmentSubmissionMessage(Object error) => switch (error) {
  PublishedTemplateAssignmentServerException() => error.operatorMessage,
  DurableSubmissionException() => error.message,
  CommandCapabilityException() => error.message,
  _ =>
    'The assignment could not be confirmed. Its saved evidence is retained; check the saved assignment before starting another.',
};

class SavedPublishedAssignmentScreen extends ConsumerStatefulWidget {
  const SavedPublishedAssignmentScreen({super.key, required this.submission});
  final DurableSubmission submission;
  @override
  ConsumerState<SavedPublishedAssignmentScreen> createState() =>
      _SavedPublishedAssignmentScreenState();
}

class _SavedPublishedAssignmentScreenState
    extends ConsumerState<SavedPublishedAssignmentScreen> {
  bool _busy = false;
  String? _message;
  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    final allowed =
        access.isReady &&
        access.actor!.canAssignJobExecution &&
        access.actor!.uid == widget.submission.actorUid;
    if (!allowed || widget.submission.isLegacy) {
      return BafScreenScaffold(
        title: 'Saved assignment',
        subtitle: 'Confirm the original planned-work request',
        icon: Icons.assignment_turned_in_outlined,
        accent: BafColors.planned,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.submission.isLegacy && access.isReady
                ? 'An older assignment has incomplete retry evidence. It is retained for support review. Its original entries and outcome must be confirmed before another assignment is sent.'
                : 'Verify the original assignment account to view saved entries.',
          ),
        ),
      );
    }
    final PublishedTemplateAssignmentRequest request;
    try {
      request = ref
          .read(publishedTemplateAssignmentSubmissionControllerProvider)
          .requestFromSaved(widget.submission);
    } catch (_) {
      return const BafScreenScaffold(
        title: 'Saved assignment',
        subtitle: 'Confirm the original planned-work request',
        icon: Icons.assignment_turned_in_outlined,
        accent: BafColors.planned,
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The saved assignment needs review. Its original evidence is retained.',
          ),
        ),
      );
    }
    return BafScreenScaffold(
      title: 'Saved assignment',
      subtitle: 'Confirm the original planned-work request',
      icon: Icons.assignment_turned_in_outlined,
      accent: BafColors.planned,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'These complete entries are saved on this device. Checking uses the original assignment request.',
          ),
          const SizedBox(height: 20),
          Text('Catalogue: ${request.packageFirestoreId}'),
          Text(
            'Published version: ${request.expectedVersionNumber} · ${request.versionFirestoreId}',
          ),
          Text('Asset: ${request.assetType.name} ${request.assetNumber}'),
          if (request.assetInstanceId != null)
            Text('Governed asset: ${request.assetInstanceId}'),
          Text('Charge: ${request.chargeNoAtEvent ?? 'Not recorded'}'),
          Text('Remarks: ${request.remarks ?? 'None'}'),
          if (request.sourcePlanId != null)
            Text(
              'Source plan: ${request.sourcePlanId} · revision ${request.sourcePlanExpectedVersion}',
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(_message!),
            ),
          const SizedBox(height: 24),
          if (_busy) const LinearProgressIndicator(),
          FilledButton(
            onPressed: _busy ? null : () => _run(),
            child: const Text('Check saved assignment'),
          ),
          if (widget.submission.state == DurableSubmissionState.intent &&
              widget.submission.attemptCount == 0)
            TextButton(
              onPressed: _busy ? null : () => _run(cancel: true),
              child: const Text('Cancel unsent assignment'),
            ),
        ],
      ),
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
        publishedTemplateAssignmentSubmissionControllerProvider,
      );
      if (cancel) {
        await controller.cancelNeverSent(widget.submission.submissionId);
      } else {
        await controller.check(widget.submission.submissionId);
        if (mounted) Navigator.maybePop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = publishedAssignmentSubmissionMessage(error));
      }
    } finally {
      container.invalidate(pendingPublishedTemplateAssignmentProvider);
      if (mounted) setState(() => _busy = false);
    }
  }
}
