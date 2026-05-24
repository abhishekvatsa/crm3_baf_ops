// FILE: lib/features/planned_maintenance/presentation/widgets/knowledge_audit_timeline.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../providers/knowledge_governance_provider.dart';

class KnowledgeAuditTimeline extends ConsumerWidget {
  const KnowledgeAuditTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(knowledgeGovernanceAuditFeedProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(knowledgeGovernanceAuditFeedProvider);
        await ref.read(knowledgeGovernanceAuditFeedProvider.future);
      },
      child: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(BafSpacing.lg),
              child: Text('Audit feed failed:\n$e'),
            ),
          ],
        ),
        data: (events) {
          if (events.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(BafSpacing.xl),
                  child: Text(
                    'No knowledge governance audit events yet.\n\nEvery create, edit, retire, archive, or restore writes a structured audit row here with the full before/after diff.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BafColors.textSecondary),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(BafSpacing.md),
            itemBuilder: (_, i) => _AuditCard(event: events[i]),
            separatorBuilder: (_, __) => const SizedBox(height: BafSpacing.sm),
            itemCount: events.length,
          );
        },
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditEvent event;

  const _AuditCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final after = event.after ?? const <String, dynamic>{};
    final governanceAction = (after['governanceAction'] ?? '').toString();
    final versionAfter = after['versionAfter'];
    final diff = after['diff'];
    final changeCount = (diff is Map && diff['changeCount'] is num)
        ? (diff['changeCount'] as num).toInt()
        : 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.entityId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (governanceAction.isNotEmpty)
                  StatusBadge(
                    label: governanceAction,
                    color: _actionColor(governanceAction),
                  ),
                const SizedBox(width: 6),
                if (versionAfter != null)
                  StatusBadge(
                    label: 'v$versionAfter',
                    color: BafColors.audit,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              '${event.performedByName ?? "unknown"} · ${formatter.format(event.timestamp.toLocal())}',
              style: const TextStyle(
                fontSize: 12,
                color: BafColors.textSecondary,
              ),
            ),
            if ((event.summary ?? '').isNotEmpty) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(event.summary!, style: const TextStyle(fontSize: 12)),
            ],
            if ((event.reasonNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: BafSpacing.xs),
              Container(
                padding: const EdgeInsets.all(BafSpacing.sm),
                decoration: BoxDecoration(
                  color: BafColors.background,
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: Text(
                  event.reasonNotes!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (changeCount > 0) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(
                '$changeCount field change${changeCount == 1 ? "" : "s"}',
                style: const TextStyle(
                  fontSize: 12,
                  color: BafColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'created':
      case 'restored':
      case 'promotedFromTagCorrection':
        return BafColors.success;
      case 'edited':
      case 'importedFromExternal':
        return BafColors.planned;
      case 'retired':
        return BafColors.warning;
      case 'archived':
        return BafColors.danger;
      default:
        return BafColors.audit;
    }
  }
}
