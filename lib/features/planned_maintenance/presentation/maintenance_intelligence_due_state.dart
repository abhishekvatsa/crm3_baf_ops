part of 'maintenance_intelligence_screen.dart';

enum _DueStateFilter { tracked, overdue, dueSoon }

class _DueStateTab extends ConsumerStatefulWidget {
  const _DueStateTab();

  @override
  ConsumerState<_DueStateTab> createState() => _DueStateTabState();
}

class _DueStateTabState extends ConsumerState<_DueStateTab> {
  _DueStateFilter _filter = _DueStateFilter.tracked;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceDueStatesProvider);
    final asOf =
        ref.watch(maintenanceCadenceClockProvider).valueOrNull ??
        DateTime.now();
    return state.when(
      loading: () => const BafLoadingPanel(
        label: 'Loading maintenance due state',
        color: BafColors.planned,
      ),
      error: (_, _) => _RetryState(
        message:
            'Maintenance due-state records need repair or could not be read.',
        onRetry: () => ref.invalidate(maintenanceDueStatesProvider),
      ),
      data: (batch) {
        final rows = batch.records;
        final overdue = rows.where((row) => row.isOverdueAt(asOf)).length;
        final dueSoon = rows.where((row) => row.isDueSoonAt(asOf)).length;
        final filtered = rows
            .where(
              (row) => switch (_filter) {
                _DueStateFilter.tracked => true,
                _DueStateFilter.overdue => row.isOverdueAt(asOf),
                _DueStateFilter.dueSoon => row.isDueSoonAt(asOf),
              },
            )
            .toList(growable: false);
        final unreadable = batch.rejectedDocumentIds.length;
        final unconfirmed = !batch.isServerConfirmed;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(maintenanceDueStatesProvider);
            await ref.read(maintenanceDueStatesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(BafSpacing.lg),
            children: [
              _SummaryBand(
                title: 'Preventive maintenance pulse',
                description:
                    'Completion events reset only their governed counters. Unclassified completed work remains visible without changing cadence.',
                metrics: [
                  _Metric(
                    'Tracked',
                    '${rows.length}',
                    BafColors.planned,
                    selected: _filter == _DueStateFilter.tracked,
                    onTap: () =>
                        setState(() => _filter = _DueStateFilter.tracked),
                  ),
                  _Metric(
                    'Overdue',
                    '$overdue',
                    BafColors.danger,
                    selected: _filter == _DueStateFilter.overdue,
                    onTap: () =>
                        setState(() => _filter = _DueStateFilter.overdue),
                  ),
                  _Metric(
                    'Due soon',
                    '$dueSoon',
                    BafColors.warning,
                    selected: _filter == _DueStateFilter.dueSoon,
                    onTap: () =>
                        setState(() => _filter = _DueStateFilter.dueSoon),
                  ),
                ],
              ),
              // These counts describe the records that could be read. A record
              // that could not be read may carry an outstanding obligation, so
              // the numbers above are not a statement about the whole plant
              // until this says the population is complete.
              if (unreadable > 0 || unconfirmed) ...[
                const SizedBox(height: BafSpacing.sm),
                StatusBadge(
                  label: unreadable > 0
                      ? '$unreadable due-state '
                            '${unreadable == 1 ? 'record' : 'records'} could not be '
                            'read; these counts cover the rest'
                      : 'Due-state snapshot is not server-confirmed; these counts are provisional',
                  color: BafColors.danger,
                  icon: Icons.report_gmailerrorred_rounded,
                ),
              ],
              const SizedBox(height: BafSpacing.lg),
              if (rows.isEmpty && unreadable == 0 && !unconfirmed)
                const _EmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'No classified completion yet',
                  message:
                      'Due state starts when a classified job is completed or an authorised user classifies historical completed work.',
                )
              else if (rows.isEmpty)
                const _EmptyState(
                  icon: Icons.report_gmailerrorred_rounded,
                  title: 'Due state cannot be shown',
                  message:
                      'Every due-state record in this population failed to '
                      'read. This is not an all-clear: repair the records '
                      'before reading anything into an empty list.',
                )
              else if (filtered.isEmpty)
                const _EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No matching due-state records',
                  message:
                      'Choose Tracked to return to all readable records. Incomplete or provisional evidence is still noted above.',
                )
              else
                ...filtered.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    key: ValueKey('maintenance-due-row-${row.id}'),
                    child: _DueStateCard(state: row, asOf: asOf),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DueStateCard extends StatelessWidget {
  const _DueStateCard({required this.state, required this.asOf});

  final MaintenanceDueState state;
  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    final color = state.classificationPending
        ? BafColors.warning
        : state.isOverdueAt(asOf)
        ? BafColors.danger
        : state.isDueSoonAt(asOf)
        ? BafColors.warning
        : BafColors.success;
    final status = state.classificationPending
        ? (state.reviewReason == 'conflicting-same-day-evidence'
              ? 'Review required: conflicting same-day evidence'
              : state.reviewReason == 'legacy-identity-review-required'
              ? 'Review required: legacy asset identity'
              : 'Classification pending')
        : state.nextDueAt == null
        ? 'Monitoring only'
        : state.isOverdueAt(asOf)
        ? '${state.daysUntilDueAt(asOf)!.abs()} days overdue'
        : '${state.daysUntilDueAt(asOf)} days remaining';
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: Icon(Icons.build_circle_outlined, color: color),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.assetDisplayName ?? '${_assetLabel(state.assetTypeKey)} ${state.assetNumber ?? state.assetInstanceId}'} · ${state.counterLabel}',
                      key: ValueKey('maintenance-due-title-${state.id}'),
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.lastCompletionAt == null
                          ? 'No qualifying completion recorded'
                          : 'Last ${state.lastMaintenanceClassCode ?? 'classified work'} · ${DateFormat('dd MMM yyyy').format(state.lastCompletionAt!.toLocal())}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          // Keep the exact asset identity readable. The status may also be a
          // long review reason, so it wraps below rather than squeezing the
          // asset into the remaining space beside a single-line chip.
          Container(
            key: ValueKey('maintenance-due-status-${state.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(BafRadius.small),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isOverdueAt(asOf)
                      ? Icons.error_outline
                      : Icons.schedule_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(status)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
