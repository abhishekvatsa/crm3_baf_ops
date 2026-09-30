import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../data/abnormality_model.dart';
import '../domain/charge_ra_history.dart';

/// A read-only view of recorded links, not a claim that all plant RA events
/// have been recorded. Keeping this in Reports preserves its account gate.
class AbnormalityChargeHistoryCard extends StatelessWidget {
  const AbnormalityChargeHistoryCard({
    super.key,
    required this.chargeNumber,
    required this.history,
    required this.onClose,
  });

  final int chargeNumber;
  final ChargeRaHistory history;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sequence = history.orderedChargeNumbers;
    final pendingCharges =
        history.records
            .where(
              (record) =>
                  record.reannealingStatus ==
                      ReannealingStatus.pendingDecision ||
                  record.reannealingStatus == ReannealingStatus.required,
            )
            .map((record) => record.sourceChargeNo)
            .toSet()
            .toList()
          ..sort();

    return DashboardCard(
      key: const ValueKey('abnormality-charge-history'),
      borderColor: BafColors.audit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recorded RA history for charge $chargeNumber',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            '${history.transitions.length} recorded RA links · ${history.records.length} abnormality entries',
          ),
          const SizedBox(height: BafSpacing.md),
          if (sequence != null && sequence.length > 1)
            Semantics(
              key: const ValueKey('abnormality-charge-sequence'),
              label: 'Recorded charge sequence: ${sequence.join(' to ')}',
              excludeSemantics: true,
              child: Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < sequence.length; i++) ...[
                    if (i > 0)
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    Chip(
                      key: ValueKey('abnormality-charge-stage-${sequence[i]}'),
                      label: Text('${sequence[i]}'),
                    ),
                  ],
                ],
              ),
            )
          else if (history.transitions.isNotEmpty)
            ...history.transitions.map(
              (link) => Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                child: Text('${link.sourceChargeNo} → ${link.targetChargeNo}'),
              ),
            )
          else
            const Text('No completed RA link is recorded for this charge.'),
          if (history.hasRepeatedRa) ...[
            const SizedBox(height: BafSpacing.sm),
            const Text(
              'Repeated RA is recorded across these linked charges.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          for (final warning in history.warnings) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(warning, style: const TextStyle(color: BafColors.maintenance)),
          ],
          if (pendingCharges.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              'RA decision or action remains pending on charge ${pendingCharges.join(', ')}.',
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          const Text(
            'All recorded links are included, regardless of the previous report filters. A Completed label applies to one RA entry, not the whole charge history. Missing dates stay unrecorded; charge numbers order undated stages, but only explicit old/new links connect charges.',
            style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: BafSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('abnormality-history-close'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Back to all abnormalities'),
          ),
        ],
      ),
    );
  }
}
