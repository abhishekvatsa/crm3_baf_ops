part of 'ticket_screen.dart';

/// Compact, wrapping metadata without the height of a separate status pill.
class _TicketSummaryLabel extends StatelessWidget {
  const _TicketSummaryLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _StateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.xl),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        children: [
          Icon(icon, size: 62, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceIncompleteNotice extends StatelessWidget {
  const _MaintenanceIncompleteNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('maintenance-incomplete-feed-notice'),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.09),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: BafColors.warning),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Issue list incomplete: $count malformed record${count == 1 ? '' : 's'} '
              'were withheld. Valid issues remain visible; do not infer that '
              'withheld issues are absent. Retry after the source data is repaired.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundedIssuesContent extends StatelessWidget {
  final Widget child;

  const _BoundedIssuesContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }
}

class _IssuesHeader extends StatelessWidget {
  final int count;
  final int totalCount;
  final bool canSeeAll;
  final bool canSeeAssigned;
  final bool isSyncing;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final _IssueListStatus status;
  final bool canViewHistory;
  final ValueChanged<_IssueListStatus> onStatusChanged;
  final VoidCallback onRaiseIssue;
  final VoidCallback onViewResolved;
  final Future<void> Function() onSyncNow;

  const _IssuesHeader({
    required this.count,
    required this.totalCount,
    required this.canSeeAll,
    required this.canSeeAssigned,
    required this.isSyncing,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.status,
    required this.canViewHistory,
    required this.onStatusChanged,
    required this.onRaiseIssue,
    required this.onViewResolved,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BafScreenIntro(
          title: switch (status) {
            _IssueListStatus.open => 'Open issues',
            _IssueListStatus.all => 'All issues',
            _IssueListStatus.closed => 'Closed issues',
          },
          subtitle: status != _IssueListStatus.open
              ? 'Issue records and retained closure evidence.'
              : canSeeAll
              ? 'Issues needing attention across the floor.'
              : canSeeAssigned
              ? 'Issues raised by you or routed to your team.'
              : 'Issues raised by you and still active.',
          icon: Icons.report_problem_outlined,
          accent: BafColors.maintenance,
        ),
        const SizedBox(height: BafSpacing.sm),
        Wrap(
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.xs,
          children: [
            for (final option in _IssueListStatus.values)
              ChoiceChip(
                key: ValueKey('issues-status-${option.name}'),
                label: Text(switch (option) {
                  _IssueListStatus.open => 'Open',
                  _IssueListStatus.all => 'All',
                  _IssueListStatus.closed => 'Closed',
                }),
                selected: option == status,
                onSelected: option == _IssueListStatus.open || canViewHistory
                    ? (_) => onStatusChanged(option)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final search = BafSearchField(
              fieldKey: const ValueKey('issues-search'),
              controller: searchController,
              hintText: 'Search asset, component or description',
              onChanged: onQueryChanged,
            );
            final sync = Tooltip(
              message: isSyncing ? 'Sync in progress' : 'Refresh issues',
              child: OutlinedButton.icon(
                key: const ValueKey('issues-sync-now'),
                onPressed: isSyncing ? null : () => onSyncNow(),
                icon: isSyncing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Sync'),
                style: _compactIssueActionStyle(),
              ),
            );
            final raise = FilledButton.icon(
              key: const ValueKey('issues-raise-issue'),
              onPressed: onRaiseIssue,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Raise'),
              style: _compactIssueActionStyle(
                backgroundColor: BafColors.maintenance,
                foregroundColor: Colors.white,
              ),
            );
            final resolved = OutlinedButton.icon(
              key: const ValueKey('issues-view-resolved'),
              onPressed: canViewHistory ? onViewResolved : null,
              icon: const Icon(Icons.task_alt_rounded, size: 19),
              label: const Text('Resolved'),
              style: _compactIssueActionStyle(),
            );
            final actions = Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [raise, resolved, sync],
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: BafSpacing.sm),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: BafSpacing.md),
                Flexible(child: actions),
              ],
            );
          },
        ),
        const SizedBox(height: BafSpacing.sm),
        Text(
          query.trim().isEmpty
              ? '$totalCount ${status == _IssueListStatus.all ? 'issues' : status.name}'
              : '$count of $totalCount matching',
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  ButtonStyle _compactIssueActionStyle({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return OutlinedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: BafSpacing.sm),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

/// Closed records in the combined list are navigation-only. Reopen,
/// classification and closure-review controls remain in governed history.
class _ClosedIssueSummary extends StatelessWidget {
  const _ClosedIssueSummary({
    required this.ticket,
    required this.onViewDetails,
  });

  final MaintenanceRecord ticket;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final closureRead = ticket.administrativeClosureReadResult;
    return Card(
      child: InkWell(
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BafSpacing.sm),
              StatusBadge(
                label: closureRead.isValid
                    ? ticket.lifecycleSummaryLabel
                    : 'Closure evidence needs review',
                color: closureRead.isValid
                    ? BafColors.audit
                    : BafColors.warning,
                icon: Icons.history_rounded,
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(ticket.description),
              const SizedBox(height: BafSpacing.sm),
              Text(
                'Closed ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.endDate ?? ticket.updatedAt)}',
                style: const TextStyle(color: BafColors.textSecondary),
              ),
              TextButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
