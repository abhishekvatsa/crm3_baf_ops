part of 'home_screen.dart';

/// Queue identity is the source/destination, never its translated display title.
/// Counts describe their own populations; related records in different queues
/// remain separate obligations rather than being merged by a matching label.
enum HomeQueueKind {
  qualityWarnings,
  operationalEvents,
  issues,
  plannedJobs,
  workflow,
  directives,
  overdueMaintenance,
  inspectionFindings,
  qualityMonitoring,
  abnormalities,
}

class HomeQueueItem {
  const HomeQueueItem({
    required this.kind,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.needsAction,
    this.count,
    this.unavailable = false,
  });

  final HomeQueueKind kind;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool needsAction;
  final int? count;
  final bool unavailable;
}

class HomeQueuePartition {
  HomeQueuePartition(Iterable<HomeQueueItem> items) {
    final unique = <HomeQueueKind, HomeQueueItem>{};
    for (final item in items) {
      final previous = unique[item.kind];
      if (previous != null &&
          (previous.count != item.count ||
              previous.unavailable != item.unavailable)) {
        throw StateError('Conflicting population for ${item.kind.name}');
      }
      if (previous == null || item.needsAction && !previous.needsAction) {
        unique[item.kind] = item;
      }
    }
    attention = unique.values.where((item) => item.needsAction).toList();
    watch = unique.values.where((item) => !item.needsAction).toList();
  }

  late final List<HomeQueueItem> attention;
  late final List<HomeQueueItem> watch;
  int get attentionQueueCount => attention.length;
}

class HomeAttentionQueues extends StatelessWidget {
  const HomeAttentionQueues({
    super.key,
    required this.items,
    required this.dataUnavailable,
    required this.onRetry,
    this.attentionTitle = 'Needs attention',
  });

  final List<HomeQueueItem> items;
  final bool dataUnavailable;
  final VoidCallback onRetry;
  final String attentionTitle;

  @override
  Widget build(BuildContext context) {
    final queues = HomeQueuePartition(items);
    final incomplete = dataUnavailable || items.any((item) => item.unavailable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSectionHeader(
          title: attentionTitle,
          icon: Icons.rule_folder_outlined,
          trailing: StatusBadge(
            label: incomplete
                ? 'Incomplete'
                : queues.attentionQueueCount == 0
                ? 'No actions'
                : '${queues.attentionQueueCount} ${queues.attentionQueueCount == 1 ? 'queue' : 'queues'}',
            color: incomplete
                ? BafColors.danger
                : queues.attentionQueueCount == 0
                ? BafColors.success
                : BafColors.warning,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        BafSectionSurface(
          padding: const EdgeInsets.symmetric(horizontal: BafSpacing.md),
          child: Column(
            children: [
              if (incomplete)
                _HomeQueueRow(
                  item: HomeQueueItem(
                    kind: HomeQueueKind.abnormalities,
                    title: 'Refresh incomplete data',
                    detail:
                        'Some counts are unavailable. Known work remains below.',
                    icon: Icons.sync_problem_outlined,
                    color: BafColors.danger,
                    onTap: onRetry,
                    needsAction: true,
                    unavailable: true,
                  ),
                  rowKey: const ValueKey('home-attention-refresh'),
                ),
              if (queues.attention.isEmpty && !incomplete)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: BafSpacing.lg),
                  child: Row(
                    children: [
                      Icon(Icons.task_alt_rounded, color: BafColors.success),
                      SizedBox(width: BafSpacing.sm),
                      Expanded(child: Text('No actions in these queues.')),
                    ],
                  ),
                ),
              for (var index = 0; index < queues.attention.length; index++) ...[
                if (index > 0 || incomplete) const Divider(height: 1),
                _HomeQueueRow(item: queues.attention[index]),
              ],
            ],
          ),
        ),
        if (queues.watch.isNotEmpty) ...[
          const SizedBox(height: BafSpacing.lg),
          const _HomeSectionHeader(
            title: 'Operational watch',
            icon: Icons.monitor_heart_outlined,
          ),
          const SizedBox(height: BafSpacing.sm),
          BafSectionSurface(
            padding: const EdgeInsets.symmetric(horizontal: BafSpacing.md),
            child: Column(
              children: [
                for (var index = 0; index < queues.watch.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  _HomeQueueRow(item: queues.watch[index]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeQueueRow extends StatelessWidget {
  const _HomeQueueRow({required this.item, this.rowKey});

  final HomeQueueItem item;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) => InkWell(
    key: rowKey ?? ValueKey('home-queue-${item.kind.name}'),
    onTap: item.onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
            padding: const EdgeInsets.all(BafSpacing.xs),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: item.unavailable || item.count == null
                ? Icon(item.icon, color: item.color, size: 23)
                : Text(
                    '${item.count}',
                    style: TextStyle(
                      color: item.color,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BafColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: BafColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}
