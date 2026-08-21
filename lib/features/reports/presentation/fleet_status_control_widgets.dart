part of 'fleet_status_screen.dart';

class OperationsControlReportPanel extends StatelessWidget {
  const OperationsControlReportPanel({
    super.key,
    required this.report,
    required this.onQuality,
    required this.onAbnormalities,
    required this.onDirectives,
    required this.onWorkflow,
    required this.onOperationalEvents,
  });

  final OperationsReport report;
  final VoidCallback onQuality;
  final VoidCallback onAbnormalities;
  final VoidCallback onDirectives;
  final VoidCallback onWorkflow;
  final VoidCallback onOperationalEvents;

  @override
  Widget build(BuildContext context) {
    final routes = [
      _ControlReportRoute(
        icon: Icons.verified_user_outlined,
        color: BafColors.charges,
        title: 'Quality disposition',
        value: '${report.openQualityWarningCount}',
        detail:
            '${report.qualityClosureRequestCount} awaiting a closure decision · '
            '${report.activeQualityMonitoringCount} monitoring requests active',
        onTap: onQuality,
      ),
      _ControlReportRoute(
        icon: Icons.assignment_late_outlined,
        color: BafColors.directives,
        title: 'Direction and acknowledgement',
        value: '${report.activeDirectiveCount}',
        detail:
            '${report.highPriorityDirectiveCount} high-priority directives in your visible queue',
        onTap: onDirectives,
      ),
      _ControlReportRoute(
        icon: Icons.account_tree_outlined,
        color: BafColors.warning,
        title: 'Maintenance coordination',
        value: '${report.workflowObligationCount}',
        detail:
            '${report.pendingLaneAcknowledgementCount} pending lane acknowledgements · '
            '${report.dueComplianceRequestCount} due compliance requests',
        onTap: onWorkflow,
      ),
      _ControlReportRoute(
        icon: Icons.monitor_heart_outlined,
        color: BafColors.instrument,
        title: 'Charge abnormalities',
        value: '${report.abnormalities.length}',
        detail:
            '${report.highSeverityAbnormalityCount} high severity · '
            '${report.pendingReannealingCount} require RA follow-through',
        onTap: onAbnormalities,
      ),
      _ControlReportRoute(
        icon: Icons.crisis_alert_outlined,
        color: BafColors.warning,
        title: 'Operational disruptions',
        value: '${report.openDisruptionCount}',
        detail:
            '${report.disruptionCount} occurrences · '
            '${_formatDuration(report.disruptionDuration)} impact in period',
        onTap: onOperationalEvents,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Decision routes',
          subtitle: 'Open the governed record queue behind each signal',
        ),
        const SizedBox(height: BafSpacing.sm),
        BafSectionSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: List<Widget>.generate(routes.length * 2 - 1, (index) {
              if (index.isOdd) {
                return const Divider(height: 1, color: BafColors.border);
              }
              final route = routes[index ~/ 2];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: BafSpacing.md,
                    vertical: BafSpacing.xs,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: route.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(BafRadius.small),
                    ),
                    child: Icon(route.icon, color: route.color, size: 21),
                  ),
                  title: Text(
                    route.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    route.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.25),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(label: route.value, color: route.color),
                      const SizedBox(width: BafSpacing.xs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: BafColors.textSecondary,
                      ),
                    ],
                  ),
                  onTap: route.onTap,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ControlReportRoute {
  const _ControlReportRoute({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String detail;
  final VoidCallback onTap;
}

class _SourceWindowNotice extends StatelessWidget {
  const _SourceWindowNotice({required this.report});
  final OperationsReport report;

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_outlined, size: 17, color: BafColors.textSecondary),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Issues, planned jobs, disruptions, quality warnings, monitoring requests and charge abnormalities were evaluated for the selected period. Current maintenance cadence, inspection findings, visible directives and workflow obligations are included for the selected asset scope.',
            style: TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  if (hours < 24) return '${hours}h';
  final days = hours ~/ 24;
  final remainder = hours % 24;
  return remainder == 0 ? '${days}d' : '${days}d ${remainder}h';
}
