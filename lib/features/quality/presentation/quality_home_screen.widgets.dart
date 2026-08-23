part of 'quality_home_screen.dart';

class _RaStateBand extends StatelessWidget {
  const _RaStateBand({required this.abnormality});

  final ChargeAbnormality abnormality;

  @override
  Widget build(BuildContext context) {
    final label = switch (abnormality.reannealingStatus) {
      ReannealingStatus.notApplicable => 'RA not applicable',
      ReannealingStatus.pendingDecision => 'RA decision pending',
      ReannealingStatus.required => 'RA required',
      ReannealingStatus.notRequired => 'RA not required',
      ReannealingStatus.completed =>
        'RA completed · Charge ${abnormality.reannealedToChargeNo}',
    };
    final color = switch (abnormality.reannealingStatus) {
      ReannealingStatus.required => BafColors.danger,
      ReannealingStatus.pendingDecision => BafColors.warning,
      ReannealingStatus.completed ||
      ReannealingStatus.notRequired => BafColors.sync,
      ReannealingStatus.notApplicable => BafColors.textSecondary,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.repeat_rounded, size: 18, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final QualityWarningStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      QualityWarningStatus.open => 'Open',
      QualityWarningStatus.closureRequested => 'Review',
      QualityWarningStatus.closed => 'Closed',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _WarningCard._statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _WarningCard._statusColor(status),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: BafColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: BafColors.textSecondary),
      ),
    ],
  );
}
