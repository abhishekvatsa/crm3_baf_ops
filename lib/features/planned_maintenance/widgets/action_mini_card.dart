// FILE: lib/features/planned_maintenance/widgets/action_mini_card.dart

import 'package:flutter/material.dart';

import '../models/component_action_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

class ActionMiniCard extends StatelessWidget {
  final ComponentAction action;

  const ActionMiniCard({
    super.key,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(action.status);
    final icon = _iconForType(action.actionType);

    final componentText = action.component.trim().isNotEmpty
        ? action.component.trim()
        : 'Unnamed component';
    final tagText = (action.tag ?? '').trim();
    final systemText = (action.system ?? '').trim();
    final subsystemText = (action.subsystem ?? '').trim();
    final issueText = (action.issue ?? '').trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        componentText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (tagText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: tagText,
                        color: BafColors.assets,
                      ),
                    ],
                  ],
                ),
                if (systemText.isNotEmpty || subsystemText.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (systemText.isNotEmpty) systemText,
                      if (subsystemText.isNotEmpty) subsystemText,
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
                if (issueText.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    issueText,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: _typeLabel(action.actionType),
                      color: color,
                    ),
                    if (action.status != null)
                      StatusBadge(
                        label: _statusLabel(action.status!),
                        color: color,
                      ),
                    StatusBadge(
                      label: TimeOfDay.fromDateTime(action.createdAt).format(context),
                      color: BafColors.admin,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForStatus(ActionStatus? status) {
    switch (status) {
      case ActionStatus.issue:
        return BafColors.danger;
      case ActionStatus.inProgress:
        return BafColors.warning;
      case ActionStatus.resolved:
        return BafColors.sync;
      case null:
        return BafColors.admin;
    }
  }

  IconData _iconForType(ActionType type) {
    switch (type) {
      case ActionType.issue:
        return Icons.warning_amber_rounded;
      case ActionType.repair:
        return Icons.build_rounded;
      case ActionType.replacement:
        return Icons.swap_horiz_rounded;
      case ActionType.inspection:
        return Icons.search_rounded;
    }
  }

  String _typeLabel(ActionType type) {
    switch (type) {
      case ActionType.issue:
        return 'Issue';
      case ActionType.repair:
        return 'Repair';
      case ActionType.replacement:
        return 'Replacement';
      case ActionType.inspection:
        return 'Inspection';
    }
  }

  String _statusLabel(ActionStatus status) {
    switch (status) {
      case ActionStatus.issue:
        return 'Issue';
      case ActionStatus.inProgress:
        return 'In progress';
      case ActionStatus.resolved:
        return 'Resolved';
    }
  }
}
