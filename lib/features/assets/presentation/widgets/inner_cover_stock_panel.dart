import 'package:flutter/material.dart';
import '../../domain/inner_cover_stock_summary.dart';

class InnerCoverStockPanel extends StatelessWidget {
  const InnerCoverStockPanel({super.key, required this.summary});
  final InnerCoverStockSummary summary;
  @override
  Widget build(BuildContext context) {
    String count(int? value) => value?.toString() ?? 'unverified';
    final review = summary.review;
    final concernCounts = [
      if ((summary.activeConfirmedBulging ?? 0) > 0)
        'confirmed bulging ${summary.activeConfirmedBulging}',
      if (summary.rows.any((r) => r.needsCurrentAssessment))
        'assessment needed ${summary.rows.where((r) => r.needsCurrentAssessment).length}',
      if (summary.activeIssueRestrictions > 0)
        'issues ${summary.activeIssueRestrictions}',
      if (summary.activeMaintenanceRestrictions > 0)
        'maintenance ${summary.activeMaintenanceRestrictions}',
    ];
    final evidenceUnverified =
        !summary.inventoryConfirmed ||
        !summary.linkageConfirmed ||
        !summary.bulgeEvidenceConfirmed ||
        !summary.dependencyEvidenceConfirmed ||
        summary.unverified > 0;
    final style = Theme.of(context).textTheme.bodySmall;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('Installed ${count(summary.installed)}', style: style),
              Text(
                'Spare candidates ${count(summary.acceptedUnassigned)}',
                style: style,
              ),
              Text('Excluded ${count(summary.excluded)}', style: style),
              if (summary.assessmentRequired == null ||
                  summary.assessmentRequired! > 0)
                Text(
                  'Needs assessment ${count(summary.assessmentRequired)}',
                  style: style,
                ),
            ],
          ),
          if (concernCounts.isNotEmpty)
            Text(
              'Current concerns: ${concernCounts.join(' · ')}',
              style: style,
            ),
          if (evidenceUnverified)
            Text(
              'Some current records are unverified; candidate count is unconfirmed.',
              style: style,
            ),
          Text('Candidates need a physical check before use.', style: style),
          if (review.isNotEmpty)
            ExpansionTile(
              key: PageStorageKey(
                'inner-cover-stock-review-${summary.rows.first.profile.assetClassId}',
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                'Review ${review.length} cover${review.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: (summary.bulgeHistory ?? 0) > 0
                  ? Text(
                      'Bulge history: ${summary.bulgeHistory} · Check current condition',
                      style: style,
                    )
                  : null,
              children: [
                for (final row in review)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Inner Cover ${row.profile.serialNumber}: ${row.reviewReasons.join(' · ')}',
                      style: style,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
