part of 'fleet_status_screen.dart';

class OperationsReportViewSelector extends StatelessWidget {
  const OperationsReportViewSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final OperationsReportView selected;
  final ValueChanged<OperationsReportView> onChanged;

  @override
  Widget build(BuildContext context) {
    const choices = [
      (
        value: OperationsReportView.overview,
        icon: Icons.dashboard_outlined,
        label: 'Overview',
      ),
      (
        value: OperationsReportView.work,
        icon: Icons.work_outline_rounded,
        label: 'Work',
      ),
      (
        value: OperationsReportView.reliability,
        icon: Icons.query_stats_rounded,
        label: 'Reliability',
      ),
      (
        value: OperationsReportView.assurance,
        icon: Icons.verified_outlined,
        label: 'Assurance',
      ),
    ];
    return BafSectionSurface(
      padding: const EdgeInsets.all(BafSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            final width = (constraints.maxWidth - BafSpacing.xs) / 2;
            return Wrap(
              spacing: BafSpacing.xs,
              runSpacing: BafSpacing.xs,
              children: [
                for (final choice in choices)
                  SizedBox(
                    width: width,
                    child: ChoiceChip(
                      avatar: Icon(choice.icon, size: 17),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          choice.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: selected == choice.value,
                      showCheckmark: false,
                      onSelected: (_) => onChanged(choice.value),
                    ),
                  ),
              ],
            );
          }
          return SegmentedButton<OperationsReportView>(
            showSelectedIcon: false,
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.single),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: BafSpacing.md),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
              ),
            ),
            segments: [
              for (final choice in choices)
                ButtonSegment(
                  value: choice.value,
                  icon: Icon(choice.icon),
                  label: Text(choice.label),
                ),
            ],
          );
        },
      ),
    );
  }
}

class OperationsManagementReadout extends StatelessWidget {
  const OperationsManagementReadout({super.key, required this.report});

  final OperationsReport report;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _ManagementMetricData(
        label: 'Availability',
        value: _rateLabel(report.assetAvailabilityRate),
        detail: '${report.availableAssetCount} of ${report.assetCount} assets',
        color: BafColors.success,
      ),
      _ManagementMetricData(
        label: 'Issues closed',
        value: _rateLabel(report.issueClosureRate),
        detail:
            '${report.resolvedIssueCount} of ${report.issueCount} in period',
        color: BafColors.cobalt,
      ),
      _ManagementMetricData(
        label: 'Planned complete',
        value: _rateLabel(report.plannedCompletionRate),
        detail:
            '${report.completedPlannedJobCount} of ${report.plannedJobCount} jobs',
        color: BafColors.teal,
      ),
      _ManagementMetricData(
        label: 'Assurance due',
        value: '${report.assuranceBacklogCount}',
        detail: 'Cadence and inspection follow-through',
        color:
            report.assuranceBacklogCount == 0
                ? BafColors.success
                : BafColors.warning,
      ),
    ];

    return BafDarkHeaderSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Management readout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Decision signals for the selected scope',
                      style: TextStyle(color: Color(0xFFC6D7DB), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('dd MMM, HH:mm').format(report.asOf),
                style: const TextStyle(
                  color: Color(0xFF9EB2B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * BafSpacing.sm) /
                  columns;
              return Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: _ManagementMetric(metric: metric),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: BafSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: BafSpacing.md,
              vertical: BafSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(BafRadius.small),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.radar_rounded,
                  size: 18,
                  color: Color(0xFF7FD2D0),
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    'Leading signal: ${report.leadingManagementSignal}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${report.actionBacklogCount} open actions',
                  style: const TextStyle(
                    color: Color(0xFFC6D7DB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _rateLabel(double? rate) =>
      rate == null ? '--' : '${(rate * 100).round()}%';
}

class _ManagementMetricData {
  const _ManagementMetricData({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;
}

class _ManagementMetric extends StatelessWidget {
  const _ManagementMetric({required this.metric});

  final _ManagementMetricData metric;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 96),
    padding: const EdgeInsets.all(BafSpacing.md),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.065),
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: metric.color.withValues(alpha: 0.42)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.value,
          style: TextStyle(
            color: metric.color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metric.detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFADC0C5),
            fontSize: 10,
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}

class OperationsReportSelection {
  const OperationsReportSelection({
    required this.assetClassId,
    required this.assetInstanceId,
  });

  final String? assetClassId;
  final String? assetInstanceId;
}

OperationsReportSelection reconcileOperationsReportSelection({
  required String? assetClassId,
  required String? assetInstanceId,
  required List<AssetClassRecord> classes,
  required List<AssetInstanceRecord> assets,
}) {
  final activeClassIds = {
    for (final item in classes)
      if (item.isActive) item.id,
  };
  final resolvedClassId =
      assetClassId != null && activeClassIds.contains(assetClassId)
          ? assetClassId
          : null;
  final selectedAsset =
      assetInstanceId == null
          ? null
          : assets.where((item) => item.id == assetInstanceId).firstOrNull;
  final assetRemainsAvailable =
      selectedAsset != null &&
      selectedAsset.isActive &&
      activeClassIds.contains(selectedAsset.assetClassId) &&
      (resolvedClassId == null ||
          selectedAsset.assetClassId == resolvedClassId);
  return OperationsReportSelection(
    assetClassId: resolvedClassId,
    assetInstanceId: assetRemainsAvailable ? assetInstanceId : null,
  );
}

void _invalidateReportSources(WidgetRef ref, OperationsReportFilter filter) {
  final period = (
    startInclusive: filter.startInclusive,
    endExclusive: filter.endExclusive,
  );
  ref.invalidate(operationsReportTicketsProvider(period));
  ref.invalidate(operationsReportExecutionsProvider(period));
  ref.invalidate(operationalEventsForReportsProvider);
  ref.invalidate(maintenanceDueStatesProvider);
  ref.invalidate(allInspectionFindingsProvider);
  ref.invalidate(assetClassesProvider);
  ref.invalidate(allAssetInstancesProvider);
  ref.invalidate(assetOperationalConditionsProvider);
  ref.invalidate(equipmentStatusProvider(null));
  ref.invalidate(plantAssetOverviewProvider);
  ref.invalidate(operationsReportClockProvider);
  ref.invalidate(operationsReportProvider(filter));
}
