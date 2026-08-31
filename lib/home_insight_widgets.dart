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
    required this.actionCount,
    required this.assuranceCount,
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
  final int actionCount;
  final int assuranceCount;
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
    final overview = plantOverview.value;
    final availability =
        overview == null || overview.total == 0
            ? '--'
            : '${((overview.available / overview.total) * 100).round()}%';
    final availabilityDetail =
        overview == null
            ? 'Plant data unavailable'
            : '${overview.available} of ${overview.total} assets';
    final availabilityColor =
        overview == null || overview.total == 0
            ? BafColors.textSecondary
            : overview.available / overview.total >= 0.9
            ? BafColors.success
            : overview.available / overview.total >= 0.75
            ? BafColors.warning
            : BafColors.danger;
    final unavailableAssets =
        overview == null ? 0 : overview.total - overview.available;
    final highRiskUnavailableAssets =
        overview == null
            ? 0
            : overview.assets
                .where((asset) => asset.isDown || asset.isUnfit)
                .length;
    final leading = _leadingSignal(
      unavailableAssets: unavailableAssets,
      highRiskUnavailableAssets: highRiskUnavailableAssets,
    );

    return BafSectionSurface(
      accent: BafColors.cobalt,
      padding: const EdgeInsets.all(BafSpacing.lg),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Management pulse',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Availability, action pressure and assurance',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
          const SizedBox(height: BafSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - BafSpacing.sm * 2) / 3;
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
                      value: dataUnavailable ? '--' : '$actionCount',
                      label: 'Action queue',
                      detail: 'Issues, work and disruptions',
                      color:
                          actionCount == 0
                              ? BafColors.success
                              : BafColors.warning,
                      onTap:
                          ticketCount > 0
                              ? onIssues
                              : executionCount > 0
                              ? onWork
                              : onControl,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _HomePulseMetric(
                      value: dataUnavailable ? '--' : '$assuranceCount',
                      label: 'Assurance',
                      detail: 'Monitoring, overdue and findings',
                      color:
                          assuranceCount == 0
                              ? BafColors.success
                              : BafColors.maintenance,
                      onTap:
                          overdueMaintenanceCount > 0
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
          const SizedBox(height: BafSpacing.md),
          InkWell(
            onTap: leading.onTap,
            borderRadius: BorderRadius.circular(BafRadius.small),
            child: Padding(
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
    if (dataUnavailable) {
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
        text:
            highRiskUnavailableAssets == 1
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
        text:
            unavailableAssets == 1
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
      text: 'No active exception leads the current plant picture.',
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
  Widget build(BuildContext context) => Material(
    color: BafColors.surfaceTint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BafRadius.small),
      side: BorderSide(color: color.withValues(alpha: 0.20)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BafRadius.small),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(BafSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 9,
                height: 1.15,
              ),
            ),
          ],
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
