import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/job_lane_record.dart';
import '../../domain/maintenance_lane.dart';
import '../models/lane_closure_readiness.dart';

class WorkflowLaneStrip extends StatelessWidget {
  final List<JobLaneRecord> lanes;
  final ValueChanged<JobLaneRecord>? onLaneTap;
  final Map<String, LaneClosureReadiness>? readinessByLaneId;
  final bool readinessLoading;
  final String? readinessError;

  const WorkflowLaneStrip({
    super.key,
    required this.lanes,
    this.onLaneTap,
    this.readinessByLaneId,
    this.readinessLoading = false,
    this.readinessError,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...lanes]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List<Widget>.generate(ordered.isEmpty ? 0 : ordered.length * 2 - 1, (
          index,
        ) {
          if (index.isOdd) {
            return Divider(height: 1, color: colorScheme.outlineVariant);
          }

          final lane = ordered[index ~/ 2];
          final parsed = MaintenanceLaneId.tryParse(lane.laneKey);
          final definition =
              parsed == null
                  ? null
                  : MaintenanceLaneCatalog.crm3.definition(parsed);
          final laneId = lane.firestoreId?.trim();
          final readiness = laneId == null ? null : readinessByLaneId?[laneId];
          final progress = readiness?.moduleProgress;
          final enabled = onLaneTap != null;
          final statusColor = _statusColor(context, lane.statusKey, readiness);

          return InkWell(
            key: ValueKey<String>(
              'workflow-lane-${lane.laneKey}-${lane.activationGeneration}',
            ),
            onTap: enabled ? () => onLaneTap!(lane) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _icon(lane.statusKey, readiness),
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition?.displayName ?? lane.laneKey.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          readiness?.summary ?? _status(lane.statusKey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (lane.closedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Closed ${DateFormat('dd MMM yyyy, HH:mm').format(lane.closedAt!.toLocal())}'
                            '${lane.closedByName?.trim().isNotEmpty == true ? ' by ${lane.closedByName!.trim()}' : ''}',
                            key: ValueKey<String>(
                              'workflow-lane-closure-${lane.laneKey}-${lane.activationGeneration}',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (progress != null) ...[
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2),
                            color: statusColor,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ],
              ),
            ),
          );
        }),
        if (readinessLoading) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Checking module and compliance readiness')),
            ],
          ),
        ] else if (readinessError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  readinessError!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  IconData _icon(String status, LaneClosureReadiness? readiness) {
    if (readiness?.readyForClosure == true) return Icons.task_alt_rounded;
    switch (status) {
      case 'acknowledged':
        return Icons.mark_email_read_outlined;
      case 'closed':
        return Icons.check_circle_outline;
      case 'removed':
        return Icons.remove_circle_outline;
      case 'terminated':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _status(String status) {
    switch (status) {
      case 'pending':
        return 'Pending acknowledgement';
      case 'acknowledged':
        return 'Acknowledged';
      case 'closed':
        return 'Closed';
      case 'removed':
        return 'Removed';
      case 'terminated':
        return 'Terminated';
      default:
        return status;
    }
  }

  Color _statusColor(
    BuildContext context,
    String status,
    LaneClosureReadiness? readiness,
  ) {
    final colors = Theme.of(context).colorScheme;
    if (readiness?.readyForClosure == true || status == 'closed') {
      return colors.primary;
    }
    if (status == 'removed' || status == 'terminated') return colors.error;
    if (readiness != null && readiness.blockingReasons.isNotEmpty) {
      return colors.tertiary;
    }
    return colors.secondary;
  }
}
