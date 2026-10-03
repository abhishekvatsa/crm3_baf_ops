import 'package:flutter/material.dart';

import '../data/furnace_stuckup_record.dart';

class InnerCoverAssessmentDialog extends StatefulWidget {
  const InnerCoverAssessmentDialog({
    required this.record,
    required this.acceptanceReference,
    super.key,
  });
  final FurnaceStuckupRecord record;
  final String acceptanceReference;
  @override
  State<InnerCoverAssessmentDialog> createState() =>
      _InnerCoverAssessmentDialogState();
}

class _InnerCoverAssessmentDialogState
    extends State<InnerCoverAssessmentDialog> {
  final _reason = TextEditingController();
  bool _confirmed = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settle this Inner Cover assessment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Inner Cover ${widget.record.innerCoverSerialNumber} · event at Base ${widget.record.baseAssetNumber}',
            ),
            Text('Recorded acceptance: ${widget.acceptanceReference}'),
            const Text(
              'The original withdrawal and bulge history remain. This decision settles only this recorded concern.',
            ),
            const SizedBox(height: 12),
            const Text('Technical disposition reason'),
            TextField(
              key: const ValueKey('ic-assessment-reason'),
              controller: _reason,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explain how the post-event inspection resolves this concern (at least 20 characters).',
            ),
            CheckboxListTile(
              key: const ValueKey('ic-assessment-confirm'),
              value: _confirmed,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I reviewed the inspection evidence and confirm it resolves this exact assessment.',
              ),
              onChanged: (value) => setState(() => _confirmed = value == true),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  key: const ValueKey('ic-assessment-submit'),
                  onPressed: _confirmed && _reason.text.trim().length >= 20
                      ? () => Navigator.pop(context, _reason.text.trim())
                      : null,
                  child: const Text('Settle assessment'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Explicit administrative review of retained command evidence. This form does
/// not certify the cover and cannot itself clear an assessment or a journal row.
class InnerCoverSavedRequestReviewDialog extends StatefulWidget {
  const InnerCoverSavedRequestReviewDialog({
    required this.commandId,
    super.key,
  });
  final String commandId;
  @override
  State<InnerCoverSavedRequestReviewDialog> createState() =>
      _InnerCoverSavedRequestReviewDialogState();
}

class _InnerCoverSavedRequestReviewDialogState
    extends State<InnerCoverSavedRequestReviewDialog> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review saved assessment request',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'First check the current assessment and original records. The server will check whether this exact request was accepted. A missing receipt alone does not permit a new request.',
            ),
            const SizedBox(height: 8),
            Text(widget.commandId),
            const SizedBox(height: 12),
            const Text(
              'Describe what you checked and why this saved request needs review (10–1600 characters).',
            ),
            TextField(
              controller: _reason,
              key: const ValueKey('ic-saved-review-reason'),
              minLines: 2,
              maxLines: 6,
              maxLength: 1600,
              decoration: const InputDecoration(labelText: 'Review reason'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keep saved request'),
                ),
                FilledButton(
                  key: const ValueKey('ic-saved-review-inspect'),
                  onPressed: _reason.text.trim().length < 10
                      ? null
                      : () => Navigator.of(context).pop(_reason.text.trim()),
                  child: const Text('Inspect server outcome'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// The receipt observation is shown separately from the administrative reason;
/// the user must explicitly confirm the server-side review decision.
class InnerCoverSavedRequestConfirmationDialog extends StatelessWidget {
  const InnerCoverSavedRequestConfirmationDialog({
    required this.adopt,
    super.key,
  });
  final bool adopt;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              adopt ? 'Use the verified result?' : 'Close this saved request?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              adopt
                  ? 'The server found matching acceptance evidence. Its original result and history will be retained; no replacement assessment is created.'
                  : 'No acceptance receipt was found. The server must permanently block this exact old request before a fresh review is allowed. The original request and concern remain recorded.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep saved request'),
                ),
                FilledButton(
                  key: const ValueKey('ic-saved-review-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    adopt ? 'Use verified result' : 'Close saved request',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Layout only; the panel supplies admitted actions and prerequisite state.
class InnerCoverAssessmentRetainedView extends StatelessWidget {
  const InnerCoverAssessmentRetainedView({
    required this.caseId,
    required this.serialNumber,
    required this.sameActor,
    required this.failure,
    required this.showAcceptanceReminder,
    required this.actions,
    super.key,
  });
  final String caseId;
  final String serialNumber;
  final bool sameActor;
  final String? failure;
  final bool showAcceptanceReminder;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      key: ValueKey('ic-assessment-retained-$caseId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InnerCoverAssessmentGuidance(
          serialNumber: serialNumber,
          sameActor: sameActor,
          failure: failure,
        ),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
        if (showAcceptanceReminder)
          const Text(
            'A current, unassigned cover with a recorded post-event acceptance is required before review.',
          ),
      ],
    ),
  );
}

/// Plain guidance is separated from current-evidence admission and command state.
class InnerCoverAssessmentGuidance extends StatelessWidget {
  const InnerCoverAssessmentGuidance({
    required this.serialNumber,
    this.sameActor = true,
    this.failure,
    super.key,
  });
  final String serialNumber;
  final bool sameActor;
  final String? failure;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Withdrawn issue · assessment still required',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      Text(
        'Inner Cover $serialNumber remains restricted by this recorded concern. Withdrawal did not certify its condition.',
      ),
      const SizedBox(height: 8),
      const Text(
        'An Admin must delink the cover if installed, record its inspection and acceptance after this event, then an Admin or SI can review and settle this exact assessment. Other restrictions still apply.',
      ),
      if (!sameActor)
        const Text(
          'Return to the approved account that created the saved assessment request. Its original evidence is retained.',
        ),
      if (failure != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(failure!)),
    ],
  );
}

/// Render only after current server evidence has validated this exact decision.
class InnerCoverAssessmentSettledSummary extends StatelessWidget {
  const InnerCoverAssessmentSettledSummary({
    required this.caseId,
    required this.disposition,
    super.key,
  });
  final String caseId;
  final InnerCoverConcernDisposition disposition;
  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('ic-assessment-settled-$caseId'),
    leading: const Icon(Icons.fact_check_outlined),
    title: const Text('This assessment was settled'),
    subtitle: Text(
      '${disposition.acceptanceReference} · ${disposition.settledByName}\n${disposition.reason}\nOriginal issue and bulge history retained.',
    ),
  );
}

class InnerCoverAssessmentEvidenceError extends StatelessWidget {
  const InnerCoverAssessmentEvidenceError({required this.onRetry, super.key});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Assessment evidence could not be checked. The concern remains in place.',
      ),
      TextButton(
        onPressed: onRetry,
        child: const Text('Check assessment again'),
      ),
    ],
  );
}

class InnerCoverAssessmentMismatchedSummary extends StatelessWidget {
  const InnerCoverAssessmentMismatchedSummary({
    required this.onCheck,
    super.key,
  });
  final VoidCallback onCheck;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'The saved assessment does not match this concern. Its condition has not been cleared; ask an Admin to review the original records.',
      ),
      TextButton(
        onPressed: onCheck,
        child: const Text('Check current assessment'),
      ),
    ],
  );
}

class InnerCoverSavedRequestReviewAction extends StatelessWidget {
  const InnerCoverSavedRequestReviewAction({
    required this.caseId,
    required this.isAdmin,
    required this.busy,
    required this.unavailable,
    required this.onInspect,
    super.key,
  });
  final String caseId;
  final bool isAdmin;
  final bool busy;
  final bool unavailable;
  final VoidCallback onInspect;
  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return unavailable
          ? const SizedBox.shrink()
          : const Text(
              'An Admin can inspect the saved request and, after a verified server review, allow a fresh assessment.',
            );
    }
    return FilledButton(
      onPressed: busy || unavailable ? null : onInspect,
      key: ValueKey('ic-assessment-saved-review-$caseId'),
      child: Text(
        unavailable
            ? 'Saved-request recovery unavailable'
            : 'Inspect saved assessment request',
      ),
    );
  }
}
