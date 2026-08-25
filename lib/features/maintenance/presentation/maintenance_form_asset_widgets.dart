part of 'maintenance_form.dart';

class _SelectedAssetSummary extends StatelessWidget {
  const _SelectedAssetSummary({required this.asset});

  final AssetInstanceRecord asset;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      asset.serviceState.label,
      if (asset.plantTag case final tag? when tag.trim().isNotEmpty) tag.trim(),
      if (asset.location case final location? when location.trim().isNotEmpty)
        location.trim(),
      asset.ownershipStatus.label,
    ];
    final color = switch (asset.serviceState) {
      AssetServiceState.inService => BafColors.sync,
      AssetServiceState.standby => BafColors.warning,
      AssetServiceState.outOfService => BafColors.danger,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_outlined, color: color, size: 18),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            details.join(' · '),
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetSelectorMessage extends StatelessWidget {
  const _AssetSelectorMessage({
    required this.icon,
    required this.message,
    required this.color,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final Color color;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (showProgress) ...[
          const SizedBox(height: BafSpacing.sm),
          LinearProgressIndicator(
            minHeight: 2,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ],
      ],
    );
  }
}

class _SubmitIssueBar extends StatelessWidget {
  final bool isSubmitting;
  final bool isCritical;
  final VoidCallback? onSubmit;

  const _SubmitIssueBar({
    required this.isSubmitting,
    required this.isCritical,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isCritical ? Icons.priority_high_rounded : Icons.sync_rounded,
                  color: isCritical ? BafColors.danger : BafColors.maintenance,
                  size: 18,
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    isCritical
                        ? 'Critical issue: sends immediately.'
                        : 'Issue sends immediately when connected.',
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isCritical ? BafColors.danger : BafColors.maintenance,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: BafColors.border,
                  disabledForegroundColor: BafColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
                ),
                icon:
                    isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.add_task_rounded),
                label: Text(
                  isSubmitting ? 'Submitting...' : 'Submit Issue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriticalIssueToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CriticalIssueToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            value
                ? BafColors.danger.withValues(alpha: 0.08)
                : BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color:
              value
                  ? BafColors.danger.withValues(alpha: 0.34)
                  : BafColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked == true),
        activeColor: BafColors.danger,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.sm,
          vertical: BafSpacing.xs,
        ),
        title: const Text(
          'Critical / safety-sensitive issue',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'Tick this for H₂-sensitive or urgent breakdowns. All issues synchronize immediately; critical issues receive additional visual priority.',
          style: TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String? appUserName;

  const _IntroCard({this.appUserName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(
          color: BafColors.maintenance.withValues(alpha: 0.18),
        ),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.maintenance.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: BafColors.maintenance,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raise an issue',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                const Text(
                  'Give the attending team enough context to act quickly and safely.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (appUserName != null && appUserName!.trim().isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.sm),
                  StatusBadge(
                    label: 'Logging as $appUserName',
                    color: BafColors.maintenance,
                    icon: Icons.person_outline_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
