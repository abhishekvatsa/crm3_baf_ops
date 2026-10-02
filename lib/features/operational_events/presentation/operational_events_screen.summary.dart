part of 'operational_events_screen.dart';

bool _isCriticalEvent(OperationalEvent event) =>
    event.severity == OperationalEventSeverity.critical;

String _eventFilterLabel(_OperationalEventFilter filter) => switch (filter) {
  _OperationalEventFilter.open => 'Open',
  _OperationalEventFilter.critical => 'Critical open',
  _OperationalEventFilter.resolved => 'Recent resolved',
  _OperationalEventFilter.withdrawn => 'Withdrawn',
};

class _EventSummary extends StatelessWidget {
  const _EventSummary({
    required this.openCount,
    required this.criticalCount,
    required this.resolvedCount,
    required this.withdrawnCount,
    required this.selected,
    required this.onSelected,
  });

  final int openCount;
  final int criticalCount;
  final int resolvedCount;
  final int withdrawnCount;
  final _OperationalEventFilter selected;
  final ValueChanged<_OperationalEventFilter> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final minimumWidth =
            140 * MediaQuery.textScalerOf(context).scale(12) / 12;
        final columns = ((constraints.maxWidth + 8) / (minimumWidth + 8))
            .floor()
            .clamp(1, 4);
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _OperationalEventFilter.values)
              SizedBox(
                width: width,
                child: _Metric(
                  filter: filter,
                  value: switch (filter) {
                    _OperationalEventFilter.open => openCount,
                    _OperationalEventFilter.critical => criticalCount,
                    _OperationalEventFilter.resolved => resolvedCount,
                    _OperationalEventFilter.withdrawn => withdrawnCount,
                  },
                  color: switch (filter) {
                    _OperationalEventFilter.open => BafColors.warning,
                    _OperationalEventFilter.critical => BafColors.danger,
                    _OperationalEventFilter.resolved => BafColors.success,
                    _OperationalEventFilter.withdrawn =>
                      BafColors.textSecondary,
                  },
                  selected: selected == filter,
                  onTap: () => onSelected(filter),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _EventImpactPanel extends StatelessWidget {
  const _EventImpactPanel({
    required this.eventsAsync,
    required this.selectedMonth,
    required this.selectedTopic,
    required this.asOf,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickMonth,
    required this.onTopicChanged,
    required this.onRetry,
  });

  final AsyncValue<List<OperationalEvent>> eventsAsync;
  final DateTime selectedMonth;
  final OperationalEventType? selectedTopic;
  final DateTime asOf;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback onPickMonth;
  final ValueChanged<OperationalEventType?> onTopicChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      key: const ValueKey('operational-events-monthly-impact'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.cobalt.withValues(alpha: 0.24)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.query_stats_rounded, color: BafColors.cobalt),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly impact',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Complete recorded event history',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final monthControl = Row(
                children: [
                  IconButton(
                    onPressed: onPreviousMonth,
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickMonth,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        DateFormat('MMMM yyyy').format(selectedMonth),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onNextMonth,
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );
              final topicControl =
                  DropdownButtonFormField<OperationalEventType?>(
                    key: ValueKey<String>(
                      'operational-event-topic-${selectedTopic?.name ?? 'all'}',
                    ),
                    initialValue: selectedTopic,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<OperationalEventType?>(
                        value: null,
                        child: Text('All topics'),
                      ),
                      ...OperationalEventType.values.map(
                        (value) => DropdownMenuItem<OperationalEventType?>(
                          value: value,
                          child: Text(
                            value.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onTopicChanged,
                  );
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    monthControl,
                    const SizedBox(height: 10),
                    topicControl,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: monthControl),
                  const SizedBox(width: 12),
                  Expanded(child: topicControl),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          eventsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly impact is unavailable.',
                  style: TextStyle(
                    color: BafColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry impact summary'),
                ),
              ],
            ),
            data: (events) {
              final summary = summarizeOperationalEventImpact(
                events: events,
                month: selectedMonth,
                asOf: asOf,
                topic: selectedTopic,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImpactMetrics(summary: summary),
                  if (selectedTopic == null && summary.leadingType != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Highest impact topic: ${summary.leadingType!.label} '
                      '(${_formatImpactDuration(summary.leadingTypeDuration)})',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Cumulative event time sums every recorded disruption; '
                    'events that overlap in time are counted separately.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _ImpactMetrics extends StatelessWidget {
  const _ImpactMetrics({required this.summary});

  final OperationalEventImpactSummary summary;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _ImpactMetric(
          value: _formatImpactDuration(summary.cumulativeDuration),
          label: 'Cumulative impact',
        ),
      ),
      const SizedBox(
        height: 58,
        child: VerticalDivider(color: BafColors.border),
      ),
      Expanded(
        child: _ImpactMetric(
          value: '${summary.occurrenceCount}',
          label: 'Occurrences',
        ),
      ),
      const SizedBox(
        height: 58,
        child: VerticalDivider(color: BafColors.border),
      ),
      Expanded(
        child: _ImpactMetric(
          value: '${summary.eventCount}',
          label: 'Event records',
        ),
      ),
    ],
  );
}

class _ImpactMetric extends StatelessWidget {
  const _ImpactMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 26,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: BafColors.cobalt,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _HistoryWindowNotice extends StatelessWidget {
  const _HistoryWindowNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BafColors.planned.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: BafColors.planned, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              operationalEventResolvedHistoryDisclosure,
              style: TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _IncompleteFeedNotice extends StatelessWidget {
  const _IncompleteFeedNotice({required this.malformedDocumentCount});

  final int malformedDocumentCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: BafColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The live event list is incomplete: $malformedDocumentCount '
              '${malformedDocumentCount == 1 ? 'record could' : 'records could'} '
              'not be read. Do not infer that no event exists; retry after '
              'the malformed data is repaired.',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.filter,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final _OperationalEventFilter filter;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('operational-event-summary-${filter.name}'),
    button: true,
    selected: selected,
    label: '${_eventFilterLabel(filter)}, $value events',
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: selected ? color.withValues(alpha: 0.10) : BafColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          side: BorderSide(
            color: color.withValues(alpha: selected ? 0.8 : 0.24),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _eventFilterLabel(filter),
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _OperationalEventFilter filter;

  bool get showingOpen =>
      filter == _OperationalEventFilter.open ||
      filter == _OperationalEventFilter.critical;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showingOpen
                ? Icons.check_circle_outline
                : filter == _OperationalEventFilter.withdrawn
                ? Icons.remove_circle_outline
                : Icons.history_rounded,
            size: 44,
            color: BafColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            showingOpen
                ? filter == _OperationalEventFilter.critical
                      ? 'No critical open operational events'
                      : 'No open operational events'
                : filter == _OperationalEventFilter.withdrawn
                ? 'No withdrawn operational events'
                : 'No resolved events',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
