import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';

class AbnormalityReportSummaryCard extends StatelessWidget {
  final int total;
  final int filtered;
  final int raPending;
  final int raCompleted;
  final int critical;
  final String? selected;
  final VoidCallback onTotal;
  final VoidCallback onMatching;
  final VoidCallback onRaPending;
  final VoidCallback onRaCompleted;
  final VoidCallback onCritical;

  const AbnormalityReportSummaryCard({
    super.key,
    required this.total,
    required this.filtered,
    required this.raPending,
    required this.raCompleted,
    required this.critical,
    required this.selected,
    required this.onTotal,
    required this.onMatching,
    required this.onRaPending,
    required this.onRaCompleted,
    required this.onCritical,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.navy,
      borderColor: BafColors.navySoft.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final icon = Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white),
              );
              const details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abnormality intelligence',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: BafSpacing.xs),
                  Text(
                    'Tap a count to view its records. Total, RA and Critical counts cover all locally available abnormalities.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              );
              final titleScale =
                  MediaQuery.textScalerOf(context).scale(18) / 18;
              final stackHeader =
                  constraints.maxWidth - 46 - BafSpacing.md < 220 * titleScale;
              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(height: BafSpacing.md),
                    details,
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: BafSpacing.md),
                  const Expanded(child: details),
                ],
              );
            },
          ),
          const SizedBox(height: BafSpacing.lg),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _MetricPill(
                label: 'Total',
                selected: selected == 'Total',
                value: total,
                onPressed: onTotal,
              ),
              _MetricPill(
                label: 'Matching',
                selected: selected == 'Matching',
                value: filtered,
                onPressed: onMatching,
              ),
              _MetricPill(
                label: 'RA Pending',
                selected: selected == 'RA Pending',
                value: raPending,
                onPressed: onRaPending,
              ),
              _MetricPill(
                label: 'RA Done',
                selected: selected == 'RA Done',
                value: raCompleted,
                onPressed: onRaCompleted,
              ),
              _MetricPill(
                label: 'Critical',
                selected: selected == 'Critical',
                value: critical,
                onPressed: onCritical,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;

  final VoidCallback onPressed;
  final bool selected;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.onPressed,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value. View records',
      onTap: onPressed,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('abnormality-metric-$label'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(BafRadius.medium),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 82, minHeight: 60),
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: BafSpacing.md,
                vertical: BafSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(BafRadius.medium),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.9 : 0.3),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
