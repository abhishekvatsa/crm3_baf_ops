part of 'quality_home_screen.dart';

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.open,
    required this.review,
    required this.closed,
  });

  final int open;
  final int review;
  final int closed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _SummaryMetric(label: 'Open', value: open)),
      const SizedBox(width: BafSpacing.sm),
      Expanded(child: _SummaryMetric(label: 'Review', value: review)),
      const SizedBox(width: BafSpacing.sm),
      Expanded(child: _SummaryMetric(label: 'Closed', value: closed)),
    ],
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BafSpacing.md,
      vertical: BafSpacing.md,
    ),
    decoration: BoxDecoration(
      color: BafColors.card,
      border: Border.all(color: BafColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: BafColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: BafColors.textSecondary),
        ),
      ],
    ),
  );
}

class _WarningCard extends ConsumerWidget {
  const _WarningCard({
    required this.warning,
    required this.actor,
    required this.busy,
    required this.onRequestClosure,
    required this.onDeclareRaRequired,
    required this.onRecordRaCompleted,
    required this.onClose,
    required this.onReopen,
  });

  final QualityWarning warning;
  final AppUser? actor;
  final bool busy;
  final VoidCallback onRequestClosure;
  final VoidCallback onDeclareRaRequired;
  final ValueChanged<ChargeAbnormality> onRecordRaCompleted;
  final ValueChanged<ChargeAbnormality?> onClose;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedCase = ref.watch(
      linkedQualityAbnormalityProvider(linkedQualityAbnormalityId(warning)),
    );
    final linkedAbnormality = linkedCase.valueOrNull;
    final linkedCaseReady =
        linkedCase.hasValue && !linkedCase.isLoading && !linkedCase.hasError;
    final governedIssueCase =
        warning.sourceType == QualityWarningSourceType.issue &&
        warning.affectedAssets.any(
          (asset) => asset.assetHierarchyReference != null,
        );
    final mandatoryLinkedCaseMissing =
        (warning.sourceType == QualityWarningSourceType.abnormality ||
            governedIssueCase) &&
        linkedCaseReady &&
        linkedAbnormality == null;
    final linkedCaseActionBlocked =
        !linkedCaseReady || mandatoryLinkedCaseMissing;
    final componentPaths = <String>[
      for (final asset in warning.affectedAssets)
        if (asset.componentLabel != null)
          '${asset.label}: ${asset.assetHierarchyReference!.hierarchyPath.join(' > ')}',
    ];
    if (componentPaths.isEmpty && linkedAbnormality != null) {
      componentPaths.addAll(<String>[
        for (final asset in linkedAbnormality.affectedAssets)
          if (asset.componentLabel != null)
            '${asset.label}: ${asset.assetHierarchyReference!.hierarchyPath.join(' > ')}',
      ]);
    }
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _statusIcon(warning.status),
                  color: _statusColor(warning.status),
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    'Charge ${warning.sourceChargeNo}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: BafColors.textPrimary,
                    ),
                  ),
                ),
                _StatusLabel(status: warning.status),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(
              warning.sourceSummary,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: BafColors.textPrimary,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            _RecordedOpinion(reason: warning.warningReason),
            if (componentPaths.isNotEmpty) ...[
              const SizedBox(height: BafSpacing.sm),
              for (final componentPath in componentPaths)
                Padding(
                  padding: const EdgeInsets.only(bottom: BafSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.account_tree_outlined,
                        size: 16,
                        color: BafColors.assets,
                      ),
                      const SizedBox(width: BafSpacing.xs),
                      Expanded(
                        child: Text(
                          componentPath,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: BafSpacing.md),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.xs,
              children: [
                _Fact(
                  icon: Icons.precision_manufacturing_outlined,
                  text:
                      warning.affectedAssets.isEmpty
                          ? 'No asset recorded'
                          : warning.affectedAssets
                              .map((asset) => asset.label)
                              .join(', '),
                ),
                if (warning.component != null)
                  _Fact(
                    icon: Icons.settings_outlined,
                    text: warning.component!,
                  ),
                _Fact(
                  icon: Icons.schedule_outlined,
                  text: DateFormat(
                    'dd MMM yyyy, HH:mm',
                  ).format(warning.createdAt),
                ),
              ],
            ),
            if (linkedCase.hasError) ...[
              const SizedBox(height: BafSpacing.md),
              const _LinkedCaseState(
                icon: Icons.cloud_off_outlined,
                text: 'Linked RA case is unavailable. Refresh before acting.',
                color: BafColors.danger,
              ),
            ] else if (linkedCase.isLoading) ...[
              const SizedBox(height: BafSpacing.md),
              const _LinkedCaseState(
                icon: Icons.sync_rounded,
                text: 'Loading linked RA case...',
                color: BafColors.textSecondary,
              ),
            ] else if (linkedAbnormality != null) ...[
              const SizedBox(height: BafSpacing.md),
              _RaStateBand(abnormality: linkedAbnormality),
            ] else if (mandatoryLinkedCaseMissing) ...[
              const SizedBox(height: BafSpacing.md),
              const _LinkedCaseState(
                icon: Icons.link_off_rounded,
                text:
                    'This warning is missing its mandatory abnormality record. Quality decisions are blocked pending repair.',
                color: BafColors.danger,
              ),
            ],
            if (warning.closureRequestReason != null) ...[
              const SizedBox(height: BafSpacing.md),
              _ClosureRequestEvidence(
                warning: warning,
                isRaCompletion:
                    linkedAbnormality?.reannealingStatus ==
                    ReannealingStatus.completed,
              ),
            ],
            if (warning.status == QualityWarningStatus.closed) ...[
              const SizedBox(height: BafSpacing.md),
              Text(
                _closureLabel(warning),
                style: const TextStyle(
                  color: BafColors.sync,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: BafSpacing.md),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                if (warning.status == QualityWarningStatus.open &&
                    actor?.canRequestQualityWarningClosure == true)
                  OutlinedButton.icon(
                    onPressed:
                        busy || linkedCaseActionBlocked
                            ? null
                            : onRequestClosure,
                    icon: const Icon(Icons.forward_to_inbox_outlined),
                    label: const Text('Request closure'),
                  ),
                if (warning.status != QualityWarningStatus.closed &&
                    actor?.canProgressQualityReannealing == true)
                  OutlinedButton.icon(
                    onPressed:
                        busy ||
                                !linkedCaseReady ||
                                linkedAbnormality == null ||
                                linkedAbnormality.reannealingStatus ==
                                    ReannealingStatus.required ||
                                linkedAbnormality.reannealingStatus ==
                                    ReannealingStatus.completed
                            ? null
                            : onDeclareRaRequired,
                    icon: const Icon(Icons.repeat_rounded),
                    label: const Text('RA required'),
                  ),
                if (warning.status != QualityWarningStatus.closed &&
                    actor?.canProgressQualityReannealing == true &&
                    linkedCaseReady &&
                    linkedAbnormality?.reannealingStatus ==
                        ReannealingStatus.required)
                  FilledButton.icon(
                    onPressed:
                        busy
                            ? null
                            : () => onRecordRaCompleted(linkedAbnormality!),
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('Record RA completion'),
                  ),
                if (warning.status != QualityWarningStatus.closed &&
                    actor?.canCloseQualityWarning == true)
                  FilledButton.icon(
                    onPressed:
                        busy || linkedCaseActionBlocked
                            ? null
                            : () => onClose(linkedAbnormality),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Adjudicate'),
                  ),
                if (warning.status == QualityWarningStatus.closed &&
                    actor?.canCloseQualityWarning == true)
                  OutlinedButton.icon(
                    onPressed:
                        busy || linkedCaseActionBlocked ? null : onReopen,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reopen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _statusIcon(QualityWarningStatus status) => switch (status) {
    QualityWarningStatus.open => Icons.warning_amber_rounded,
    QualityWarningStatus.closureRequested => Icons.hourglass_top_rounded,
    QualityWarningStatus.closed => Icons.verified_rounded,
  };

  static Color _statusColor(QualityWarningStatus status) => switch (status) {
    QualityWarningStatus.open => BafColors.danger,
    QualityWarningStatus.closureRequested => BafColors.warning,
    QualityWarningStatus.closed => BafColors.sync,
  };

  static String _closureLabel(QualityWarning warning) {
    final disposition = warning.closureDisposition;
    final label = switch (disposition) {
      QualityWarningClosureDisposition.coilFoundAcceptable =>
        'Coil found acceptable',
      QualityWarningClosureDisposition.reannealingCompleted =>
        'Closed after re-annealing',
      QualityWarningClosureDisposition.qualityAdjudication =>
        'Closed by quality adjudication',
      null => 'Closed',
    };
    final ra = warning.linkedReannealingChargeNos;
    return ra.isEmpty ? label : '$label · RA ${ra.join(', ')}';
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    required this.request,
    required this.canClose,
    required this.busy,
    required this.onClose,
  });

  final QualityMonitoringRequest request;
  final bool canClose;
  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: BafColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                color: BafColors.charges,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Base ${request.baseNumber} · ${request.grade}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: BafColors.textPrimary,
                  ),
                ),
              ),
              Text(
                request.status == QualityMonitoringStatus.active
                    ? 'Active'
                    : 'Closed',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color:
                      request.status == QualityMonitoringStatus.active
                          ? BafColors.warning
                          : BafColors.sync,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            request.cycleReference,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: BafColors.textPrimary,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            request.reason,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          const SizedBox(height: BafSpacing.sm),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.xs,
            children: [
              _Fact(
                icon: Icons.person_outline_rounded,
                text:
                    'Requested by ${request.createdByName ?? request.createdByUid}',
              ),
              _Fact(
                icon: Icons.schedule_outlined,
                text: DateFormat(
                  'dd MMM yyyy, HH:mm',
                ).format(request.createdAt),
              ),
            ],
          ),
          if (request.chargeNumbers.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              'Charges: ${request.chargeNumbers.join(', ')}',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          ],
          if (request.status == QualityMonitoringStatus.closed) ...[
            const SizedBox(height: BafSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BafSpacing.md),
              decoration: BoxDecoration(
                color: BafColors.surfaceTint,
                border: Border.all(color: BafColors.border),
                borderRadius: BorderRadius.circular(BafRadius.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.closeReason!,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.xs,
                    children: [
                      _Fact(
                        icon: Icons.verified_user_outlined,
                        text:
                            'Closed by ${request.closedByName ?? request.closedByUid}',
                      ),
                      _Fact(
                        icon: Icons.event_available_outlined,
                        text: DateFormat(
                          'dd MMM yyyy, HH:mm',
                        ).format(request.closedAt!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (request.status == QualityMonitoringStatus.active && canClose) ...[
            const SizedBox(height: BafSpacing.md),
            OutlinedButton.icon(
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Complete monitoring'),
            ),
          ],
        ],
      ),
    ),
  );
}
