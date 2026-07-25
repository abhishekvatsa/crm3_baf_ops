import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/job_lane_record.dart';
import 'workflow_providers.dart';

class LaneInboxQuery {
  final String laneKey;
  final bool includeClosed;
  const LaneInboxQuery(this.laneKey, {this.includeClosed = false});

  @override
  bool operator ==(Object other) =>
      other is LaneInboxQuery && other.laneKey == laneKey && other.includeClosed == includeClosed;

  @override
  int get hashCode => Object.hash(laneKey, includeClosed);
}

final laneInboxProvider = StreamProvider.family<List<JobLaneRecord>, LaneInboxQuery>((ref, query) {
  final repository = ref.watch(workflowRepositoryProvider);
  return repository.watchLanesByLane(query.laneKey).map((rows) {
    if (query.includeClosed) return rows;
    return rows.where((row) => row.statusKey != 'closed' && row.statusKey != 'removed' && row.statusKey != 'terminated').toList(growable: false);
  });
});
