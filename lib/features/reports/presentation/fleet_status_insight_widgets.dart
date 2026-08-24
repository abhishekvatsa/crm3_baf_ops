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
        value: OperationsReportView.control,
        icon: Icons.radar_outlined,
        label: 'Control',
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
        label: 'Issue outcomes',
        value: _rateLabel(report.issueClosureRate),
        detail:
            '${report.resolvedIssueCount} resolved · '
            '${report.administrativelyClosedIssueCount} admin-closed'
            '${report.retainedUnresolvedClosureCount == 0 ? '' : ' · ${report.retainedUnresolvedClosureCount} still relevant'}',
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

class OperationsDecisionBrief extends StatelessWidget {
  const OperationsDecisionBrief({
    super.key,
    required this.report,
    required this.onPlantCondition,
    required this.onIssues,
    required this.onOperationalEvents,
    required this.onMaintenanceRhythm,
    required this.onInspections,
    required this.onPlannedWork,
    required this.onQuality,
    required this.onAbnormalities,
    required this.onDirectives,
    required this.onWorkflow,
  });

  final OperationsReport report;
  final VoidCallback onPlantCondition;
  final VoidCallback onIssues;
  final VoidCallback onOperationalEvents;
  final VoidCallback onMaintenanceRhythm;
  final VoidCallback onInspections;
  final VoidCallback onPlannedWork;
  final VoidCallback onQuality;
  final VoidCallback onAbnormalities;
  final VoidCallback onDirectives;
  final VoidCallback onWorkflow;

  @override
  Widget build(BuildContext context) {
    final signals = report.managementSignals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decision brief',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Risk-ranked conditions with direct operational routes',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label:
                  signals.isEmpty ? 'All clear' : '${signals.length} signals',
              color:
                  signals.isEmpty
                      ? BafColors.success
                      : _signalColor(signals.first.level),
            ),
          ],
        ),
        const SizedBox(height: BafSpacing.sm),
        if (signals.isEmpty)
          const BafSectionSurface(
            padding: EdgeInsets.all(BafSpacing.md),
            child: Row(
              children: [
                Icon(Icons.task_alt_rounded, color: BafColors.success),
                SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    'No active exception leads the selected scope.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          BafSectionSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: List<Widget>.generate(signals.length * 2 - 1, (index) {
                if (index.isOdd) {
                  return const Divider(height: 1, color: BafColors.border);
                }
                final signal = signals[index ~/ 2];
                return _DecisionSignalRow(
                  signal: signal,
                  onTap: _actionFor(signal.type),
                );
              }),
            ),
          ),
      ],
    );
  }

  VoidCallback _actionFor(
    OperationsManagementSignalType type,
  ) => switch (type) {
    OperationsManagementSignalType.unavailableAssets => onPlantCondition,
    OperationsManagementSignalType.criticalIssues => onIssues,
    OperationsManagementSignalType.operationalDisruptions =>
      onOperationalEvents,
    OperationsManagementSignalType.overdueMaintenance => onMaintenanceRhythm,
    OperationsManagementSignalType.inspectionFindings => onInspections,
    OperationsManagementSignalType.qualityWarnings => onQuality,
    OperationsManagementSignalType.workflowObligations => onWorkflow,
    OperationsManagementSignalType.activeDirectives => onDirectives,
    OperationsManagementSignalType.criticalAbnormalities => onAbnormalities,
    OperationsManagementSignalType.qualityMonitoring => onQuality,
    OperationsManagementSignalType.openIssues => onIssues,
    OperationsManagementSignalType.openPlannedWork => onPlannedWork,
  };

  static Color _signalColor(OperationsManagementSignalLevel level) =>
      switch (level) {
        OperationsManagementSignalLevel.critical => BafColors.danger,
        OperationsManagementSignalLevel.warning => BafColors.warning,
        OperationsManagementSignalLevel.attention => BafColors.cobalt,
      };
}

class _DecisionSignalRow extends StatelessWidget {
  const _DecisionSignalRow({required this.signal, required this.onTap});

  final OperationsManagementSignal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = OperationsDecisionBrief._signalColor(signal.level);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.md,
          vertical: BafSpacing.xs,
        ),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          child: Icon(_signalIcon(signal.type), color: color, size: 20),
        ),
        title: Text(
          signal.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          signal.detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, height: 1.25),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: BafColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  static IconData _signalIcon(OperationsManagementSignalType type) =>
      switch (type) {
        OperationsManagementSignalType.unavailableAssets =>
          Icons.precision_manufacturing_outlined,
        OperationsManagementSignalType.criticalIssues =>
          Icons.report_problem_outlined,
        OperationsManagementSignalType.operationalDisruptions =>
          Icons.crisis_alert_outlined,
        OperationsManagementSignalType.overdueMaintenance =>
          Icons.event_busy_outlined,
        OperationsManagementSignalType.inspectionFindings =>
          Icons.fact_check_outlined,
        OperationsManagementSignalType.qualityWarnings =>
          Icons.verified_user_outlined,
        OperationsManagementSignalType.workflowObligations =>
          Icons.account_tree_outlined,
        OperationsManagementSignalType.activeDirectives =>
          Icons.assignment_late_outlined,
        OperationsManagementSignalType.criticalAbnormalities =>
          Icons.monitor_heart_outlined,
        OperationsManagementSignalType.qualityMonitoring =>
          Icons.visibility_outlined,
        OperationsManagementSignalType.openIssues => Icons.build_outlined,
        OperationsManagementSignalType.openPlannedWork =>
          Icons.work_outline_rounded,
      };
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

void _invalidateReportSources(
  WidgetRef ref, [
  OperationsReportScope? reportScope,
]) {
  ref.invalidate(operationsReportTicketsProvider);
  ref.invalidate(operationsReportExecutionsProvider);
  ref.invalidate(operationalEventsForReportsProvider);
  ref.invalidate(maintenanceDueStatesProvider);
  ref.invalidate(allInspectionFindingsProvider);
  ref.invalidate(qualityWarningsProvider);
  ref.invalidate(qualityMonitoringRequestsForReportsProvider);
  ref.invalidate(operationsReportAbnormalitiesProvider);
  ref.invalidate(openDirectivesProvider);
  ref.invalidate(workflowAllLanesProvider);
  ref.invalidate(workflowAllComplianceProvider);
  ref.invalidate(assetClassesProvider);
  ref.invalidate(allAssetInstancesProvider);
  ref.invalidate(assetOperationalConditionsProvider);
  ref.invalidate(equipmentStatusProvider(null));
  ref.invalidate(plantAssetOverviewProvider);
  ref.invalidate(operationsReportClockProvider);
  if (reportScope != null) {
    ref.invalidate(operationsReportProvider(reportScope));
  }
}
