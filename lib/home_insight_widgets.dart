part of 'home_screen.dart';

class HomeCommandBar extends StatelessWidget {
  const HomeCommandBar({
    super.key,
    required this.onRaiseIssue,
    required this.onPlantCondition,
    required this.onMorningReview,
    required this.onReports,
    required this.onControl,
  });

  final VoidCallback onRaiseIssue;
  final VoidCallback onPlantCondition;
  final VoidCallback onMorningReview;
  final VoidCallback onReports;
  final VoidCallback onControl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final raiseIssue = FilledButton.icon(
        key: const ValueKey('home-raise-issue'),
        onPressed: onRaiseIssue,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Raise issue'),
        style: FilledButton.styleFrom(
          backgroundColor: BafColors.maintenance,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      );
      final plant = _HomeSecondaryCommand(
        key: const ValueKey('home-plant-condition'),
        icon: Icons.precision_manufacturing_outlined,
        label: 'Plant',
        color: BafColors.assets,
        onPressed: onPlantCondition,
      );
      final reports = _HomeSecondaryCommand(
        key: const ValueKey('home-reports'),
        icon: Icons.insights_outlined,
        label: 'Reports',
        color: BafColors.cobalt,
        onPressed: onReports,
      );
      final morningReview = _HomeSecondaryCommand(
        key: const ValueKey('home-morning-review'),
        icon: Icons.groups_2_outlined,
        label: 'Review',
        color: BafColors.cobalt,
        onPressed: onMorningReview,
      );
      final control = _HomeSecondaryCommand(
        key: const ValueKey('home-control'),
        icon: Icons.radar_rounded,
        label: 'Control',
        color: BafColors.directives,
        onPressed: onControl,
      );

      if (constraints.maxWidth < 430) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            raiseIssue,
            const SizedBox(height: BafSpacing.sm),
            Row(
              children: [
                Expanded(child: plant),
                const SizedBox(width: BafSpacing.sm),
                Expanded(child: morningReview),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            Row(
              children: [
                Expanded(child: control),
                const SizedBox(width: BafSpacing.sm),
                Expanded(child: reports),
              ],
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(flex: 3, child: raiseIssue),
          const SizedBox(width: BafSpacing.sm),
          Expanded(flex: 2, child: plant),
          const SizedBox(width: BafSpacing.sm),
          Expanded(flex: 2, child: morningReview),
          const SizedBox(width: BafSpacing.sm),
          Expanded(flex: 2, child: control),
          const SizedBox(width: BafSpacing.sm),
          Expanded(flex: 2, child: reports),
        ],
      );
    },
  );
}

class _HomeSecondaryCommand extends StatelessWidget {
  const _HomeSecondaryCommand({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: BafSpacing.sm),
      side: BorderSide(color: color.withValues(alpha: 0.32)),
    ),
  );
}

class HomeManagementPulsePanel extends StatelessWidget {
  const HomeManagementPulsePanel({
    super.key,
    required this.plantOverview,
    required this.dataUnavailable,
    required this.onOpenReports,
    required this.onPlantCondition,
    required this.onIssues,
    required this.onWork,
    required this.onControl,
    required this.onQualityMonitoring,
    required this.onRetry,
    required this.onMaintenanceRhythm,
    required this.onInspectionProgrammes,
    required this.ticketCount,
    required this.executionCount,
    required this.directiveCount,
    required this.workflowAttentionCount,
    required this.openOperationalEventCount,
    required this.openQualityWarningCount,
    required this.activeQualityMonitoringCount,
    required this.overdueMaintenanceCount,
    required this.activeInspectionFindingCount,
  });

  final AsyncValue<PlantAssetOverview> plantOverview;
  final bool dataUnavailable;
  final VoidCallback onOpenReports;
  final VoidCallback onPlantCondition;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onControl;
  final VoidCallback onQualityMonitoring;
  final VoidCallback onRetry;
  final VoidCallback onMaintenanceRhythm;
  final VoidCallback onInspectionProgrammes;
  final int ticketCount;
  final int executionCount;
  final int directiveCount;
  final int workflowAttentionCount;
  final int openOperationalEventCount;
  final int openQualityWarningCount;
  final int activeQualityMonitoringCount;
  final int overdueMaintenanceCount;
  final int activeInspectionFindingCount;

  @override
  Widget build(BuildContext context) {
    final overview = plantOverview.asData?.value;
    // These source populations can share related records. Summarize active
    // queues here; each queue keeps its own record count further down Home.
    final actionQueueCount = [
      ticketCount,
      executionCount,
      directiveCount,
      workflowAttentionCount,
      openOperationalEventCount,
      openQualityWarningCount,
    ].where((count) => count > 0).length;
    final assuranceQueueCount = [
      overdueMaintenanceCount,
      activeInspectionFindingCount,
      activeQualityMonitoringCount,
    ].where((count) => count > 0).length;
    final availableRate = overview?.availabilityRate;
    final availability = availableRate == null
        ? '--'
        : '${(availableRate * 100).round()}%';
    final availabilityDetail = overview == null
        ? 'Plant data unavailable'
        : overview.hasCompleteEvidence
        ? '${overview.available} of ${overview.total} assets'
        : '${overview.available} verified available · ${overview.total} recorded · evidence incomplete';
    final availabilityColor = availableRate == null
        ? BafColors.textSecondary
        : availableRate >= 0.9
        ? BafColors.success
        : availableRate >= 0.75
        ? BafColors.warning
        : BafColors.danger;
    final unavailableAssets = overview == null
        ? 0
        : overview.total - overview.available;
    final highRiskUnavailableAssets = overview == null
        ? 0
        : overview.down + overview.unfit;
    final leading = _leadingSignal(
      unavailableAssets: unavailableAssets,
      highRiskUnavailableAssets: highRiskUnavailableAssets,
    );

    return BafSectionSurface(
      accent: BafColors.cobalt,
      padding: const EdgeInsets.all(BafSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BafColors.cobalt.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 19,
                  color: BafColors.cobalt,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              const Expanded(
                child: Text(
                  'Management pulse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Open operations reports',
                onPressed: onOpenReports,
                icon: const Icon(Icons.arrow_forward_rounded),
                color: BafColors.cobalt,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final minimumWidth =
                  72 * MediaQuery.textScalerOf(context).scale(12) / 12;
              final columns =
                  ((constraints.maxWidth + BafSpacing.sm) /
                          (minimumWidth + BafSpacing.sm))
                      .floor()
                      .clamp(1, 3);
              final width =
                  (constraints.maxWidth - BafSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _HomePulseMetric(
                      value: availability,
                      label: 'Availability',
                      detail: availabilityDetail,
                      color: availabilityColor,
                      onTap: onPlantCondition,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _HomePulseMetric(
                      value: dataUnavailable ? '--' : '$actionQueueCount',
                      label: 'Action queues',
                      detail: 'Active queues for issues, work and disruptions',
                      color: actionQueueCount == 0
                          ? BafColors.success
                          : BafColors.warning,
                      onTap: ticketCount > 0
                          ? onIssues
                          : executionCount > 0 || workflowAttentionCount > 0
                          ? onWork
                          : onControl,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _HomePulseMetric(
                      value: dataUnavailable ? '--' : '$assuranceQueueCount',
                      label: 'Assurance queues',
                      detail:
                          'Active queues for monitoring, overdue maintenance and findings',
                      color: assuranceQueueCount == 0
                          ? BafColors.success
                          : BafColors.maintenance,
                      onTap: overdueMaintenanceCount > 0
                          ? onMaintenanceRhythm
                          : activeInspectionFindingCount > 0
                          ? onInspectionProgrammes
                          : activeQualityMonitoringCount > 0
                          ? onQualityMonitoring
                          : onInspectionProgrammes,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            availabilityDetail,
            key: const ValueKey('home-pulse-availability-detail'),
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11,
            ),
          ),
          InkWell(
            onTap: leading.onTap,
            borderRadius: BorderRadius.circular(BafRadius.small),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: BafSpacing.xs),
              child: Row(
                children: [
                  Icon(leading.icon, color: leading.color, size: 18),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Text(
                      leading.text,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: BafColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _HomeLeadingSignal _leadingSignal({
    required int unavailableAssets,
    required int highRiskUnavailableAssets,
  }) {
    if (dataUnavailable ||
        plantOverview.asData?.value.hasCompleteEvidence != true) {
      return _HomeLeadingSignal(
        text: 'Live sources are incomplete. Refresh before final decisions.',
        icon: Icons.sync_problem_outlined,
        color: BafColors.danger,
        onTap: onRetry,
      );
    }
    if (openQualityWarningCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$openQualityWarningCount quality '
            '${openQualityWarningCount == 1 ? 'warning requires' : 'warnings require'} disposition.',
        icon: Icons.verified_user_outlined,
        color: BafColors.danger,
        onTap: onControl,
      );
    }
    if (highRiskUnavailableAssets > 0) {
      return _HomeLeadingSignal(
        text: highRiskUnavailableAssets == 1
            ? '1 asset is down or unfit.'
            : '$highRiskUnavailableAssets assets are down or unfit.',
        icon: Icons.precision_manufacturing_outlined,
        color: BafColors.danger,
        onTap: onPlantCondition,
      );
    }
    if (openOperationalEventCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$openOperationalEventCount plant '
            '${openOperationalEventCount == 1 ? 'disruption remains' : 'disruptions remain'} open.',
        icon: Icons.crisis_alert_outlined,
        color: BafColors.warning,
        onTap: onControl,
      );
    }
    if (workflowAttentionCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$workflowAttentionCount workflow '
            '${workflowAttentionCount == 1 ? 'obligation requires' : 'obligations require'} action.',
        icon: Icons.account_tree_outlined,
        color: BafColors.warning,
        onTap: onWork,
      );
    }
    if (directiveCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$directiveCount '
            '${directiveCount == 1 ? 'directive remains' : 'directives remain'} active.',
        icon: Icons.assignment_late_outlined,
        color: BafColors.directives,
        onTap: onControl,
      );
    }
    if (overdueMaintenanceCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$overdueMaintenanceCount maintenance '
            '${overdueMaintenanceCount == 1 ? 'counter is' : 'counters are'} overdue.',
        icon: Icons.event_busy_outlined,
        color: BafColors.warning,
        onTap: onMaintenanceRhythm,
      );
    }
    if (unavailableAssets > 0) {
      return _HomeLeadingSignal(
        text: unavailableAssets == 1
            ? '1 asset is outside the available state.'
            : '$unavailableAssets assets are outside the available state.',
        icon: Icons.precision_manufacturing_outlined,
        color: BafColors.warning,
        onTap: onPlantCondition,
      );
    }
    if (activeInspectionFindingCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$activeInspectionFindingCount inspection '
            '${activeInspectionFindingCount == 1 ? 'finding remains' : 'findings remain'} active.',
        icon: Icons.fact_check_outlined,
        color: BafColors.maintenance,
        onTap: onInspectionProgrammes,
      );
    }
    if (ticketCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$ticketCount open '
            '${ticketCount == 1 ? 'issue forms' : 'issues form'} the leading action queue.',
        icon: Icons.report_problem_outlined,
        color: BafColors.maintenance,
        onTap: onIssues,
      );
    }
    if (executionCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$executionCount planned '
            '${executionCount == 1 ? 'job remains' : 'jobs remain'} active.',
        icon: Icons.work_outline_rounded,
        color: BafColors.planned,
        onTap: onWork,
      );
    }
    if (activeQualityMonitoringCount > 0) {
      return _HomeLeadingSignal(
        text:
            '$activeQualityMonitoringCount quality monitoring '
            '${activeQualityMonitoringCount == 1 ? 'request remains' : 'requests remain'} active.',
        icon: Icons.monitor_heart_outlined,
        color: BafColors.instrument,
        onTap: onQualityMonitoring,
      );
    }
    return _HomeLeadingSignal(
      text: 'No exception in these summary queues.',
      icon: Icons.task_alt_rounded,
      color: BafColors.success,
      onTap: onOpenReports,
    );
  }
}

class _HomePulseMetric extends StatelessWidget {
  const _HomePulseMetric({
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: detail,
    child: Material(
      color: BafColors.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.small),
        side: BorderSide(color: color.withValues(alpha: 0.20)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.small),
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(
            horizontal: BafSpacing.xs,
            vertical: BafSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                key: ValueKey('home-pulse-value-$label'),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomeLeadingSignal {
  const _HomeLeadingSignal({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
