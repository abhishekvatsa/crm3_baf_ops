// FILE: lib/core/widgets/dashboard/dashboard_widgets.dart

import 'package:flutter/material.dart';

import '../../theme/baf_design_system.dart';
import 'status_badge.dart';

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color? borderColor;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = BafColors.card,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: borderColor ?? BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: child,
    );
  }
}

class DashboardHeader extends StatelessWidget {
  final String userName;
  final Widget avatar;
  final Widget syncIndicator;
  final VoidCallback onProfileTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.avatar,
    required this.syncIndicator,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstName =
        userName.trim().isEmpty
            ? 'there'
            : userName.trim().split(RegExp(r'\s+')).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.factory_outlined,
              color: BafColors.navySoft,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'CRM-III BAF Ops',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            syncIndicator,
            const SizedBox(width: 8),
            GestureDetector(onTap: onProfileTap, child: avatar),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Welcome, $firstName',
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your operational priorities.',
          style: TextStyle(
            color: BafColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class ModeSwitchCard extends StatelessWidget {
  final bool attendMode;
  final ValueChanged<bool> onChanged;

  const ModeSwitchCard({
    super.key,
    required this.attendMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              selected: !attendMode,
              color: BafColors.maintenance,
              icon: Icons.add_circle_rounded,
              label: 'Raise Issue',
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              selected: attendMode,
              color: BafColors.planned,
              icon: Icons.person_search_rounded,
              label: 'Attend Issues',
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModeButton({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? color : BafColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.11) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IssueRaiserCard extends StatelessWidget {
  final VoidCallback onRaiseIssue;
  final VoidCallback onTrackIssues;
  final VoidCallback onRecentReports;

  const IssueRaiserCard({
    super.key,
    required this.onRaiseIssue,
    required this.onTrackIssues,
    required this.onRecentReports,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: const Color(0xFFFFFBF5),
      borderColor: BafColors.maintenance.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _HumanCircleIcon(
                color: BafColors.maintenance,
                icon: Icons.engineering_rounded,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOR ISSUE RAISERS',
                      style: TextStyle(
                        color: BafColors.maintenance,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Report issues and get things moving',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Simple reporting, visible status, clear ownership.',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onRaiseIssue,
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.maintenance,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Raise Issue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MiniActionTile(
                  color: BafColors.maintenance,
                  icon: Icons.search_rounded,
                  title: 'Track My Issues',
                  subtitle: 'View status and updates',
                  onTap: onTrackIssues,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniActionTile(
                  color: BafColors.maintenance,
                  icon: Icons.description_rounded,
                  title: 'Recent Reports',
                  subtitle: 'See latest submissions',
                  onTap: onRecentReports,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AttendingTeamCard extends StatelessWidget {
  final int assignedCount;
  final int openTicketCount;
  final int plannedJobCount;
  final VoidCallback onAssigned;
  final VoidCallback onOpenTickets;
  final VoidCallback onPlannedJobs;

  const AttendingTeamCard({
    super.key,
    required this.assignedCount,
    required this.openTicketCount,
    required this.plannedJobCount,
    required this.onAssigned,
    required this.onOpenTickets,
    required this.onPlannedJobs,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: const Color(0xFFF7FBFF),
      borderColor: BafColors.planned.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HumanCircleIcon(
                color: BafColors.planned,
                icon: Icons.assignment_ind_rounded,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOR ATTENDING TEAMS',
                      style: TextStyle(
                        color: BafColors.planned,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your work at a glance',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Act, update and keep things moving.',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  color: BafColors.planned,
                  icon: Icons.person_rounded,
                  value: assignedCount,
                  label: 'Assigned',
                  onTap: onAssigned,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  color: BafColors.planned,
                  icon: Icons.folder_rounded,
                  value: openTicketCount,
                  label: 'Open',
                  onTap: onOpenTickets,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  color: BafColors.planned,
                  icon: Icons.calendar_month_rounded,
                  value: plannedJobCount,
                  label: 'Planned',
                  onTap: onPlannedJobs,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniActionTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MiniActionTile({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int value;
  final String label;
  final VoidCallback onTap;

  const MetricTile({
    super.key,
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(color: BafColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleListTile extends StatelessWidget {
  final int number;
  final ModuleVisual module;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;
  final bool enabled;

  const ModuleListTile({
    super.key,
    required this.number,
    required this.module,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(BafRadius.large),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BafRadius.large),
              border: Border.all(color: BafColors.border),
              boxShadow: BafShadows.subtle,
              color: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: module.color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, color: module.color, size: 26),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: module.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        module.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: status, color: statusColor),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: BafColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MoreActionTile extends StatelessWidget {
  final ModuleVisual module;
  final String status;
  final VoidCallback onTap;

  const MoreActionTile({
    super.key,
    required this.module,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModuleListTile(
      number: 0,
      module: module,
      status: status,
      statusColor: module.color,
      onTap: onTap,
    );
  }
}

class _HumanCircleIcon extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _HumanCircleIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}
