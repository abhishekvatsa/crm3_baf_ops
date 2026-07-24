import 'package:flutter/material.dart';

import '../../data/job_lane_record.dart';
import '../../domain/maintenance_lane.dart';

class WorkflowLaneStrip extends StatelessWidget {
  final List<JobLaneRecord> lanes;
  final ValueChanged<JobLaneRecord>? onLaneTap;

  const WorkflowLaneStrip({
    super.key,
    required this.lanes,
    this.onLaneTap,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...lanes]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ordered.map((lane) {
        final parsed = MaintenanceLaneId.tryParse(lane.laneKey);
        final definition = parsed == null ? null : MaintenanceLaneCatalog.crm3.definition(parsed);
        return ActionChip(
          avatar: Icon(_icon(lane.statusKey), size: 18),
          label: Text('${definition?.code ?? lane.laneKey.toUpperCase()} · ${_status(lane.statusKey)}'),
          onPressed: onLaneTap == null ? null : () => onLaneTap!(lane),
        );
      }).toList(growable: false),
    );
  }

  IconData _icon(String status) {
    switch (status) {
      case 'acknowledged': return Icons.mark_email_read_outlined;
      case 'closed': return Icons.check_circle_outline;
      case 'removed': return Icons.remove_circle_outline;
      case 'terminated': return Icons.cancel_outlined;
      default: return Icons.hourglass_empty;
    }
  }

  String _status(String status) {
    switch (status) {
      case 'pending': return 'Pending acknowledgement';
      case 'acknowledged': return 'Acknowledged';
      case 'closed': return 'Closed';
      case 'removed': return 'Removed';
      case 'terminated': return 'Terminated';
      default: return status;
    }
  }
}
