part of 'inspection_programmes_screen.dart';

class _FindingCard extends StatelessWidget {
  const _FindingCard({
    required this.finding,
    required this.observations,
    required this.canSupervise,
    required this.onVerify,
    required this.onAdjudicate,
  });

  final InspectionFinding finding;
  final List<InspectionObservation> observations;
  final bool canSupervise;
  final VoidCallback onVerify;
  final ValueChanged<String> onAdjudicate;

  @override
  Widget build(BuildContext context) {
    final color = finding.blocksCampaignClosure
        ? BafColors.danger
        : _inspectionFindingIsTerminal(finding)
        ? BafColors.success
        : BafColors.warning;
    final hasLaterObservation = observations.any(
      (observation) =>
          observation.targetKey == finding.targetKey &&
          observation.id == finding.currentObservationId &&
          observation.observedAt.isAtSameMomentAs(finding.latestObservedAt) &&
          observation.observedAt.isAfter(finding.firstObservedAt),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BafRadius.small),
              ),
              child: Icon(Icons.rule_rounded, color: color),
            ),
            const SizedBox(width: BafSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${finding.rowLabel} · ${finding.componentName ?? 'Asset level'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _findingStatusLabel(finding.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  if (finding.evidenceReviewMessage != null)
                    Text(finding.evidenceReviewMessage!),
                  if (finding.physicalPosition != null)
                    Text(
                      finding.physicalPosition!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.xs,
                    children: [
                      _InfoChip(
                        icon: Icons.replay_rounded,
                        text:
                            '${finding.effectiveAbnormalReadingCount} effective abnormal reading${finding.effectiveAbnormalReadingCount == 1 ? '' : 's'}',
                      ),
                      if (finding.linkedTicketId != null)
                        _InfoChip(
                          icon: Icons.link_rounded,
                          text: 'Corrective issue: ${finding.linkedTicketId}',
                        ),
                      if (finding.verificationCount > 0)
                        _InfoChip(
                          icon: Icons.verified_outlined,
                          text:
                              '${finding.verificationCount} verification${finding.verificationCount == 1 ? '' : 's'}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canSupervise)
              PopupMenuButton<String>(
                tooltip: 'Finding actions',
                onSelected: (value) =>
                    value == 'verify' ? onVerify() : onAdjudicate(value),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'verify',
                    enabled:
                        hasLaterObservation && !finding.evidenceReviewRequired,
                    child: const ListTile(
                      leading: Icon(Icons.verified_outlined),
                      title: Text('Verify from later reading'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'acceptedCondition',
                    child: ListTile(
                      leading: Icon(Icons.fact_check_outlined),
                      title: Text('Accept continuing condition'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'invalidated',
                    child: ListTile(
                      leading: Icon(Icons.block_outlined),
                      title: Text('Invalidate with reason'),
                    ),
                  ),
                  if (_inspectionFindingIsTerminal(finding))
                    const PopupMenuItem(
                      value: 'open',
                      child: ListTile(
                        leading: Icon(Icons.replay_rounded),
                        title: Text('Reopen finding'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _verifyFinding(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionFinding finding,
  List<InspectionObservation> observations,
) async {
  final originUid = ref.read(currentAppUserProvider).value?.uid;
  if (originUid == null) return;
  final candidates =
      observations
          .where(
            (observation) =>
                observation.targetKey == finding.targetKey &&
                observation.id == finding.currentObservationId &&
                observation.observedAt.isAtSameMomentAs(
                  finding.latestObservedAt,
                ) &&
                observation.observedAt.isAfter(finding.firstObservedAt),
          )
          .toList()
        ..sort((left, right) => right.observedAt.compareTo(left.observedAt));
  if (candidates.isEmpty) return;
  final draft = await showDialog<_FindingVerificationDraft>(
    context: context,
    builder: (_) => _FindingVerificationDialog(
      observations: candidates,
      suggestedOutcome: candidates.first.outOfRange ? 'recurred' : 'resolved',
    ),
  );
  if (draft == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'verifyInspectionFinding_${const Uuid().v4()}',
      type: WorkflowCommandType.verifyInspectionFinding,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'findingId': finding.id,
        'observationId': draft.observationId,
        'expectedFindingVersion': finding.version,
        'outcome': draft.outcome,
        'reason': draft.reason,
      },
    ),
    'Finding verification recorded.',
    originUid: originUid,
  );
}

Future<void> _adjudicateFinding(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionFinding finding,
  String status,
) async {
  final originUid = ref.read(currentAppUserProvider).value?.uid;
  if (originUid == null) return;
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _InspectionReasonDialog(
      title: status == 'open'
          ? 'Reopen finding'
          : status == 'invalidated'
          ? 'Invalidate finding'
          : 'Accept continuing condition',
      message:
          'This is an SI/Admin adjudication. The original reading remains immutable.',
      minimumLength: 1,
    ),
  );
  if (reason == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'adjudicateInspectionFinding_${const Uuid().v4()}',
      type: WorkflowCommandType.adjudicateInspectionFinding,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      // The dialog reviewed this finding revision, not whichever revision
      // happens to exist by the time the request reaches the server.
      payload: {
        'findingId': finding.id,
        'expectedFindingVersion': finding.version,
        'status': status,
        'reason': reason,
      },
    ),
    'Finding adjudication recorded.',
    originUid: originUid,
  );
}

class _FindingVerificationDraft {
  const _FindingVerificationDraft({
    required this.observationId,
    required this.outcome,
    required this.reason,
  });

  final String observationId;
  final String outcome;
  final String reason;
}

class _FindingVerificationDialog extends StatefulWidget {
  const _FindingVerificationDialog({
    required this.observations,
    required this.suggestedOutcome,
  });

  final List<InspectionObservation> observations;
  final String suggestedOutcome;

  @override
  State<_FindingVerificationDialog> createState() =>
      _FindingVerificationDialogState();
}

class _FindingVerificationDialogState
    extends State<_FindingVerificationDialog> {
  late String _observationId;
  late String _outcome;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _observationId = widget.observations.first.id;
    _outcome = widget.suggestedOutcome;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify inspection finding'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _observationId,
            decoration: const InputDecoration(
              labelText: 'Later verification reading',
            ),
            items: widget.observations
                .map(
                  (observation) => DropdownMenuItem(
                    value: observation.id,
                    child: Text(
                      '${observation.displayValue} · ${DateFormat('dd MMM, HH:mm').format(observation.observedAt.toLocal())}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _observationId = value!),
          ),
          const SizedBox(height: BafSpacing.md),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _outcome,
            decoration: const InputDecoration(labelText: 'Outcome'),
            items: const [
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              DropdownMenuItem(value: 'improved', child: Text('Improved')),
              DropdownMenuItem(value: 'unchanged', child: Text('Unchanged')),
              DropdownMenuItem(
                value: 'deteriorated',
                child: Text('Deteriorated'),
              ),
              DropdownMenuItem(value: 'recurred', child: Text('Recurred')),
              DropdownMenuItem(
                value: 'notComparable',
                child: Text('Not comparable'),
              ),
            ],
            onChanged: (value) => setState(() => _outcome = value!),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Verification reasoning',
              alignLabelWithHint: true,
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
      FilledButton.icon(
        onPressed: _reason.text.trim().isNotEmpty
            ? () => Navigator.pop(
                context,
                _FindingVerificationDraft(
                  observationId: _observationId,
                  outcome: _outcome,
                  reason: _reason.text.trim(),
                ),
              )
            : null,
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Verify'),
      ),
    ],
  );
}

String _targetDispositionLabel(InspectionTargetDisposition value) =>
    switch (value) {
      InspectionTargetDisposition.pending => 'Pending',
      InspectionTargetDisposition.observed => 'Observed',
      InspectionTargetDisposition.deferred => 'Deferred',
      InspectionTargetDisposition.unavailable => 'Unavailable',
      InspectionTargetDisposition.excludedWithReason => 'Excluded with reason',
      InspectionTargetDisposition.requiresReaudit => 'Requires re-audit',
    };

String _findingStatusLabel(InspectionFindingStatus value) => switch (value) {
  InspectionFindingStatus.open => 'Open finding',
  InspectionFindingStatus.correctiveActionLinked => 'Corrective action linked',
  InspectionFindingStatus.awaitingVerification => 'Awaiting verification',
  InspectionFindingStatus.verifiedResolved => 'Verified resolved',
  InspectionFindingStatus.acceptedCondition => 'Continuing condition accepted',
  InspectionFindingStatus.invalidated => 'Invalidated with audit evidence',
};

String _comparisonLabel(InspectionComparisonOutcome value) => switch (value) {
  InspectionComparisonOutcome.improved => 'Improved from baseline',
  InspectionComparisonOutcome.unchanged => 'Unchanged from baseline',
  InspectionComparisonOutcome.deteriorated => 'Deteriorated from baseline',
  InspectionComparisonOutcome.resolved => 'Resolved from baseline',
  InspectionComparisonOutcome.recurred => 'Recurred from baseline',
  InspectionComparisonOutcome.notComparable => 'Not comparable to baseline',
};
