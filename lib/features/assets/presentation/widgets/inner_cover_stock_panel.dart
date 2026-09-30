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
        '${summary.activeConfirmedBulging} active confirmed',
      if ((summary.pendingBulgeAssessment ?? 0) > 0)
        '${summary.pendingBulgeAssessment} assessment pending',
      if ((summary.inconclusiveBulgeAssessment ?? 0) > 0)
        '${summary.inconclusiveBulgeAssessment} inconclusive',
      if ((summary.bulgeHistory ?? 0) > 0)
        '${summary.bulgeHistory} with history',
    ];
    final workCounts = [
      if (summary.activeIssueRestrictions > 0)
        '${summary.activeIssueRestrictions} with active issues',
      if (summary.activeMaintenanceRestrictions > 0)
        '${summary.activeMaintenanceRestrictions} with open maintenance',
    ];
    const style = TextStyle(fontSize: 12);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Installed ${count(summary.installed)} · Accepted, unassigned candidates ${count(summary.acceptedUnassigned)}',
            style: style,
          ),
          Text(
            'Not spare candidates ${count(summary.excluded)}${summary.unverified == 0 ? '' : ' · ${summary.unverified} evidence unverified'}',
            style: style,
          ),
          if (workCounts.isNotEmpty)
            Text('Work concerns: ${workCounts.join(' · ')}', style: style),
          if (!summary.dependencyEvidenceConfirmed)
            const Text(
              'Current issue/maintenance evidence is unverified; spare candidates are unconfirmed.',
              style: style,
            ),
          if (summary.bulgeHistory != null)
            Text(
              'Bulge: ${concernCounts.isEmpty ? 'none recorded' : concernCounts.join(' · ')}',
              style: style,
            ),
          if ((summary.acceptedUnassignedWithHistory ?? 0) > 0)
            Text(
              '${summary.acceptedUnassignedWithHistory} accepted/unassigned with bulge history — confirm present condition',
              style: style,
            ),
          const Text(
            'Candidates exclude recorded active work; confirm present condition before installation.',
            style: style,
          ),
          if (!summary.bulgeEvidenceConfirmed)
            const Text(
              'Current bulge/condition evidence is unverified.',
              style: style,
            ),
          if (review.isNotEmpty)
            ExpansionTile(
              key: ValueKey(
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
              children: [
                for (final row in review)
                  Text(
                    'Inner Cover ${row.profile.serialNumber}: ${row.reviewReasons.join(' · ')}',
                    style: style,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
