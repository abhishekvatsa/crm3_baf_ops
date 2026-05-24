// FILE: lib/features/planned_maintenance/presentation/widgets/knowledge_version_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../domain/baf_knowledge_repository.dart';

/// Compact banner that surfaces matrix-version provenance.
///
/// The cloud → Isar → static fallback chain is visualised as three pills
/// (one per source) plus the active matrix version, last-cached timestamp,
/// and a stale-indicator. A row stops being "fresh" when its cloud
/// timestamp is more than 24h older than `now`.
class KnowledgeVersionDashboard extends StatelessWidget {
  final BafKnowledgeMatrixMeta meta;
  final int totalRowCount;

  const KnowledgeVersionDashboard({
    super.key,
    required this.meta,
    required this.totalRowCount,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final cloudWhen = meta.cloudUpdatedAt;
    final stale = cloudWhen == null
        ? meta.isStaticFallback
        : DateTime.now().difference(cloudWhen).inHours > 24;
    final activeSourceColor = meta.isStaticFallback
        ? BafColors.warning
        : meta.source == 'cloud'
            ? BafColors.success
            : BafColors.planned;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.md,
        BafSpacing.md,
        BafSpacing.md,
        BafSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, color: BafColors.planned, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meta.sourceLabel,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              StatusBadge(
                label: 'matrix ${meta.matrixVersion}',
                color: activeSourceColor,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(
                label: 'source: ${meta.source}',
                color: activeSourceColor,
              ),
              StatusBadge(
                label: 'rows: $totalRowCount',
                color: BafColors.assets,
              ),
              StatusBadge(
                label: 'tag rows: ${meta.tagRowCount}',
                color: BafColors.charges,
              ),
              if (cloudWhen != null)
                StatusBadge(
                  label: 'cloud @ ${formatter.format(cloudWhen.toLocal())}',
                  color: BafColors.audit,
                  icon: Icons.cloud_done_rounded,
                ),
              if (meta.localCachedAt != null)
                StatusBadge(
                  label: 'isar @ ${formatter.format(meta.localCachedAt!.toLocal())}',
                  color: BafColors.sync,
                  icon: Icons.save_alt_rounded,
                ),
              if (meta.isStaticFallback)
                const StatusBadge(
                  label: 'static fallback active',
                  color: BafColors.warning,
                  icon: Icons.warning_amber_rounded,
                ),
              if (stale)
                const StatusBadge(
                  label: 'stale (>24h)',
                  color: BafColors.danger,
                  icon: Icons.access_time_rounded,
                ),
            ],
          ),
          if (meta.note.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.xs),
            Text(
              meta.note,
              style: const TextStyle(
                fontSize: 11,
                color: BafColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
