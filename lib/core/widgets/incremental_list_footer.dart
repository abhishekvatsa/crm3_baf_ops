import 'package:flutter/material.dart';

import '../theme/baf_design_system.dart';

/// Display batch size only. Do not apply this limit to stored records, totals,
/// synchronization or exported reports.
const businessListPageSize = 15;

class IncrementalListFooter extends StatelessWidget {
  const IncrementalListFooter({
    super.key,
    required this.visibleCount,
    required this.totalCount,
    required this.onShowMore,
    this.isLoading = false,
  });

  final int visibleCount;
  final int totalCount;
  final VoidCallback onShowMore;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0 && !isLoading) return const SizedBox.shrink();
    final shown = visibleCount.clamp(0, totalCount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Showing $shown of $totalCount',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          ),
          if (shown < totalCount || isLoading) ...[
            const SizedBox(height: BafSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('business-list-show-more'),
              onPressed: isLoading ? null : onShowMore,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(isLoading ? 'Loading…' : 'Show more'),
            ),
          ],
        ],
      ),
    );
  }
}
