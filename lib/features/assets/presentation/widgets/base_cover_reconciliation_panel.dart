import 'package:flutter/material.dart';
import '../../domain/base_cover_reconciliation.dart';
import '../../../reports/domain/base_inner_cover_register.dart';

/// Review navigation only. Linking or declaring availability remains subject to
/// the existing screens' permissions and physical-confirmation workflows.
class BaseCoverReconciliationPanel extends StatelessWidget {
  const BaseCoverReconciliationPanel({
    super.key,
    required this.summary,
    required this.onReviewBase,
    required this.onReviewLinks,
  });

  final BaseCoverReconciliation summary;
  final ValueChanged<BaseCoverRegisterRow> onReviewBase;
  final VoidCallback onReviewLinks;

  @override
  Widget build(BuildContext context) {
    if (summary.rows.isEmpty && summary.populationConfirmed) {
      return const SizedBox.shrink();
    }
    final needsReview = summary.needsReview;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Base / Inner Cover records',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${summary.rows.length} ${summary.populationConfirmed ? 'active' : 'observed active'} Bases · ${summary.linked} linked · ${summary.noRecordedLinkage} not linked',
            ),
            if (!summary.populationConfirmed || summary.linkageUnverified > 0)
              Text(
                '${summary.linkageUnverified} linkage unverified. Incomplete or conflicting records are not treated as unlinked.',
              ),
            if (summary.conditionUnverified > 0)
              Text(
                '${summary.conditionUnverified} unlinked Base condition unverified; no non-Down conclusion.',
              ),
            if (needsReview.isNotEmpty)
              ExpansionTile(
                key: const PageStorageKey('base-cover-reconciliation-review'),
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'No Inner Cover linked, but Base not marked Down',
                ),
                subtitle: Text(
                  'Base ${needsReview.take(6).map((r) => r.base.assetNumber).join(', ')}${needsReview.length > 6 ? ' and ${needsReview.length - 6} more' : ''}',
                ),
                children: [
                  const Text(
                    'Confirm the physical position, then review availability or link the actual installed cover. No status has been changed.',
                  ),
                  for (final row in needsReview)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => onReviewBase(row),
                        child: Text(
                          'Review Base ${row.base.assetNumber} availability',
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onReviewLinks,
                      child: const Text('Review Inner Cover links'),
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
