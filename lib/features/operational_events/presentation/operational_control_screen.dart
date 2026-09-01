import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';

class OperationalControlScreen extends StatelessWidget {
  const OperationalControlScreen({
    super.key,
    required this.appUser,
    required this.directiveCount,
    required this.workflowAttentionCount,
    required this.operationalEventCount,
    required this.qualityWarningCount,
    required this.qualityMonitoringCount,
    required this.inspectionFindingCount,
    required this.criticalAlarmCount,
    required this.directiveDataUnavailable,
    required this.workflowDataUnavailable,
    required this.operationalEventsUnavailable,
    required this.qualityWarningsUnavailable,
    required this.qualityMonitoringUnavailable,
    required this.inspectionFindingsUnavailable,
    required this.criticalAlarmsUnavailable,
    required this.onDirectives,
    required this.onWorkflow,
    required this.onOperationalEvents,
    required this.onQuality,
    required this.onQualityMonitoring,
    required this.onAbnormalities,
    required this.onInspections,
    required this.onCriticalAlarms,
  });

  final AppUser appUser;
  final int directiveCount;
  final int workflowAttentionCount;
  final int operationalEventCount;
  final int qualityWarningCount;
  final int qualityMonitoringCount;
  final int inspectionFindingCount;
  final int criticalAlarmCount;
  final bool directiveDataUnavailable;
  final bool workflowDataUnavailable;
  final bool operationalEventsUnavailable;
  final bool qualityWarningsUnavailable;
  final bool qualityMonitoringUnavailable;
  final bool inspectionFindingsUnavailable;
  final bool criticalAlarmsUnavailable;
  final VoidCallback onDirectives;
  final VoidCallback onWorkflow;
  final VoidCallback onOperationalEvents;
  final VoidCallback onQuality;
  final VoidCallback onQualityMonitoring;
  final VoidCallback onAbnormalities;
  final VoidCallback onInspections;
  final VoidCallback onCriticalAlarms;

  @override
  Widget build(BuildContext context) {
    final signal = _leadingSignal();
    final domains = <_ControlDomain>[
      _ControlDomain(
        icon: Icons.notification_important_outlined,
        color: BafColors.danger,
        title: 'Critical safety alarms',
        value: criticalAlarmsUnavailable ? '--' : '$criticalAlarmCount',
        detail: 'Live CRM3 coordination alarms and approved contacts',
        onTap: onCriticalAlarms,
      ),
      _ControlDomain(
        icon: Icons.assignment_late_outlined,
        color: BafColors.directives,
        title: 'Directives',
        value: directiveDataUnavailable ? '--' : '$directiveCount',
        detail: 'Instructions awaiting acknowledgement or closure',
        onTap: onDirectives,
      ),
      _ControlDomain(
        icon: Icons.account_tree_outlined,
        color: BafColors.warning,
        title: 'Workflow obligations',
        value: workflowDataUnavailable ? '--' : '$workflowAttentionCount',
        detail: 'Lane acknowledgements and compliance follow-through',
        onTap: onWorkflow,
      ),
      _ControlDomain(
        icon: Icons.crisis_alert_outlined,
        color: BafColors.warning,
        title: 'Plant disruptions',
        value: operationalEventsUnavailable ? '--' : '$operationalEventCount',
        detail: 'Utilities, cranes, transfer cars and delays',
        onTap: onOperationalEvents,
      ),
      if (appUser.canViewQuality)
        _ControlDomain(
          icon: Icons.verified_user_outlined,
          color: BafColors.charges,
          title: 'Quality warnings',
          value: qualityWarningsUnavailable ? '--' : '$qualityWarningCount',
          detail: 'Open warnings and closure requests',
          onTap: onQuality,
        ),
      if (appUser.canViewQuality)
        _ControlDomain(
          icon: Icons.monitor_heart_outlined,
          color: BafColors.instrument,
          title: 'Cycle monitoring',
          value:
              qualityMonitoringUnavailable ? '--' : '$qualityMonitoringCount',
          detail: 'Active Base, Grade and charge surveillance',
          onTap: onQualityMonitoring,
        ),
      _ControlDomain(
        icon: Icons.memory_outlined,
        color: BafColors.instrument,
        title: 'Cycle abnormalities',
        value: 'Review',
        detail: 'Charge-level exceptions and re-annealing follow-through',
        onTap: onAbnormalities,
      ),
      _ControlDomain(
        icon: Icons.fact_check_outlined,
        color: BafColors.maintenance,
        title: 'Inspection findings',
        value: inspectionFindingsUnavailable ? '--' : '$inspectionFindingCount',
        detail: 'Open findings, corrective action and verification',
        onTap: onInspections,
      ),
    ];

    return ColoredBox(
      color: BafColors.background,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.md,
                BafSpacing.md,
                BafSpacing.md,
                BafSpacing.xl,
              ),
              children: [
                const BafScreenIntro(
                  title: 'Operational control',
                  subtitle:
                      'Directives, plant disruptions, quality and assurance.',
                  icon: Icons.radar_rounded,
                  accent: BafColors.cobalt,
                ),
                const SizedBox(height: BafSpacing.lg),
                _ControlPriorityBrief(signal: signal),
                const SizedBox(height: BafSpacing.xl),
                const _ControlSectionTitle(
                  title: 'Control queues',
                  subtitle: 'Open a queue to review evidence and act',
                ),
                const SizedBox(height: BafSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 620 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * BafSpacing.sm) /
                        columns;
                    return Wrap(
                      spacing: BafSpacing.sm,
                      runSpacing: BafSpacing.sm,
                      children: [
                        for (final domain in domains)
                          SizedBox(
                            width: width,
                            child: _ControlDomainTile(domain: domain),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: BafSpacing.xl),
                const _ControlSectionTitle(
                  title: 'Common actions',
                  subtitle: 'Start from the business event you are recording',
                ),
                const SizedBox(height: BafSpacing.sm),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onCriticalAlarms,
                      icon: const Icon(Icons.notification_important_outlined),
                      label: const Text('Safety alarm'),
                    ),
                    if (appUser.canRecordOperationalEvent)
                      FilledButton.icon(
                        onPressed: onOperationalEvents,
                        icon: const Icon(Icons.add_alert_outlined),
                        label: const Text('Record disruption'),
                      ),
                    if (appUser.canLogChargeAbnormality)
                      OutlinedButton.icon(
                        onPressed: onAbnormalities,
                        icon: const Icon(Icons.monitor_heart_outlined),
                        label: const Text('Record abnormality'),
                      ),
                    if (appUser.canManageQualityMonitoring)
                      OutlinedButton.icon(
                        onPressed: onQualityMonitoring,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Monitor cycles'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onInspections,
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('Inspection programmes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ControlSignal _leadingSignal() {
    final unavailableQueues = <({String label, VoidCallback onTap})>[
      if (directiveDataUnavailable) (label: 'Directives', onTap: onDirectives),
      if (workflowDataUnavailable) (label: 'Workflow', onTap: onWorkflow),
      if (operationalEventsUnavailable)
        (label: 'Plant disruptions', onTap: onOperationalEvents),
      if (qualityWarningsUnavailable && appUser.canViewQuality)
        (label: 'Quality warnings', onTap: onQuality),
      if (qualityMonitoringUnavailable && appUser.canViewQuality)
        (label: 'Cycle monitoring', onTap: onQualityMonitoring),
      if (inspectionFindingsUnavailable)
        (label: 'Inspection findings', onTap: onInspections),
      if (criticalAlarmsUnavailable)
        (label: 'Critical alarms', onTap: onCriticalAlarms),
    ];
    if (unavailableQueues.isNotEmpty) {
      return _ControlSignal(
        icon: Icons.sync_problem_outlined,
        color: BafColors.danger,
        eyebrow: 'DATA CHECK REQUIRED',
        title:
            unavailableQueues.length == 1
                ? '${unavailableQueues.first.label} data is unavailable'
                : '${unavailableQueues.length} live control queues are unavailable',
        detail:
            'Refresh or open the affected queue before treating the control picture as complete.',
        actionLabel: 'Open affected queue',
        onTap: unavailableQueues.first.onTap,
      );
    }
    if (criticalAlarmCount > 0) {
      return _ControlSignal(
        icon: Icons.notification_important,
        color: BafColors.danger,
        eyebrow: 'CRITICAL SAFETY',
        title:
            '$criticalAlarmCount active ${criticalAlarmCount == 1 ? 'alarm requires' : 'alarms require'} immediate attention',
        detail:
            'Open the live record, follow the plant emergency procedure and coordinate confirmed support.',
        actionLabel: 'Open alarms',
        onTap: onCriticalAlarms,
      );
    }
    if (qualityWarningCount > 0 && appUser.canViewQuality) {
      return _ControlSignal(
        icon: Icons.verified_user_outlined,
        color: BafColors.danger,
        eyebrow: 'QUALITY DISPOSITION',
        title:
            '$qualityWarningCount quality '
            '${qualityWarningCount == 1 ? 'warning remains' : 'warnings remain'} open',
        detail:
            'Review affected charges, evidence and any pending closure requests.',
        actionLabel: 'Open quality',
        onTap: onQuality,
      );
    }
    if (operationalEventCount > 0) {
      return _ControlSignal(
        icon: Icons.crisis_alert_outlined,
        color: BafColors.warning,
        eyebrow: 'PLANT DISRUPTION',
        title:
            '$operationalEventCount operational '
            '${operationalEventCount == 1 ? 'event remains' : 'events remain'} open',
        detail:
            'Confirm impact, linked issues and restoration evidence for each event.',
        actionLabel: 'Open events',
        onTap: onOperationalEvents,
      );
    }
    if (workflowAttentionCount > 0) {
      return _ControlSignal(
        icon: Icons.account_tree_outlined,
        color: BafColors.warning,
        eyebrow: 'WORKFLOW OBLIGATION',
        title:
            '$workflowAttentionCount workflow '
            '${workflowAttentionCount == 1 ? 'action requires' : 'actions require'} attention',
        detail:
            'Lane acknowledgement or compliance confirmation is still pending.',
        actionLabel: 'Open workflow',
        onTap: onWorkflow,
      );
    }
    if (inspectionFindingCount > 0) {
      return _ControlSignal(
        icon: Icons.fact_check_outlined,
        color: BafColors.maintenance,
        eyebrow: 'ASSURANCE FOLLOW-THROUGH',
        title:
            '$inspectionFindingCount inspection '
            '${inspectionFindingCount == 1 ? 'finding remains' : 'findings remain'} active',
        detail:
            'Review corrective-action linkage and evidence awaiting verification.',
        actionLabel: 'Open findings',
        onTap: onInspections,
      );
    }
    if (directiveCount > 0) {
      return _ControlSignal(
        icon: Icons.assignment_late_outlined,
        color: BafColors.directives,
        eyebrow: 'ACTIVE DIRECTION',
        title:
            '$directiveCount '
            '${directiveCount == 1 ? 'directive remains' : 'directives remain'} active',
        detail: 'Check acknowledgement, compliance and closure ownership.',
        actionLabel: 'Open directives',
        onTap: onDirectives,
      );
    }
    if (qualityMonitoringCount > 0 && appUser.canViewQuality) {
      return _ControlSignal(
        icon: Icons.monitor_heart_outlined,
        color: BafColors.instrument,
        eyebrow: 'ACTIVE QUALITY MONITORING',
        title:
            '$qualityMonitoringCount cycle monitoring '
            '${qualityMonitoringCount == 1 ? 'request remains' : 'requests remain'} active',
        detail:
            'Review the selected Bases, Grades, cycles and charge coverage.',
        actionLabel: 'Open monitoring',
        onTap: onQualityMonitoring,
      );
    }
    return _ControlSignal(
      icon: Icons.task_alt_rounded,
      color: BafColors.success,
      eyebrow: 'CONTROL PICTURE',
      title: 'No open control exception leads the current picture',
      detail:
          'Continue routine surveillance and record new plant events when observed.',
      actionLabel: 'Open directives',
      onTap: onDirectives,
    );
  }
}

class _ControlPriorityBrief extends StatelessWidget {
  const _ControlPriorityBrief({required this.signal});

  final _ControlSignal signal;

  @override
  Widget build(BuildContext context) => BafDarkHeaderSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: signal.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(BafRadius.small),
              ),
              child: Icon(signal.icon, color: signal.color, size: 23),
            ),
            const SizedBox(width: BafSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal.eyebrow,
                    style: TextStyle(
                      color: signal.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    signal.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    signal.detail,
                    style: const TextStyle(
                      color: Color(0xFFC6D7DB),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: signal.onTap,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(signal.actionLabel),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _ControlDomainTile extends StatelessWidget {
  const _ControlDomainTile({required this.domain});

  final _ControlDomain domain;

  @override
  Widget build(BuildContext context) => BafRecordSurface(
    onTap: domain.onTap,
    accent: domain.color,
    padding: const EdgeInsets.all(BafSpacing.md),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 92),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: domain.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(domain.icon, color: domain.color, size: 22),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        domain.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusBadge(label: domain.value, color: domain.color),
                  ],
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  domain.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            color: BafColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}

class _ControlSectionTitle extends StatelessWidget {
  const _ControlSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(color: BafColors.textSecondary, fontSize: 12),
      ),
    ],
  );
}

class _ControlDomain {
  const _ControlDomain({
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

class _ControlSignal {
  const _ControlSignal({
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onTap;
}
