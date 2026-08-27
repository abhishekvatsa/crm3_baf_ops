import 'burner_block_lifecycle_event.dart';
import 'burner_condition_round.dart';

final class BurnerBlockConditionProjection {
  const BurnerBlockConditionProjection({
    required this.sourceKey,
    required this.latestEvidenceAt,
    required this.redHotPositions,
    required this.replacementsByPosition,
  });

  final String sourceKey;
  final DateTime? latestEvidenceAt;
  final Set<int> redHotPositions;
  final Map<int, BurnerBlockLifecycleEvent> replacementsByPosition;
}

BurnerBlockConditionProjection projectBurnerBlockCondition({
  required BurnerConditionRound? round,
  required Map<int, DateTime> newerRedHotObservations,
  required List<BurnerBlockLifecycleEvent> lifecycleEvents,
  required String assetInstanceId,
}) {
  final replacements = <int, BurnerBlockLifecycleEvent>{};
  for (final event in lifecycleEvents) {
    if (event.assetInstanceId != assetInstanceId) continue;
    final current = replacements[event.burnerPosition];
    if (current == null || _isLaterReplacement(event, current)) {
      replacements[event.burnerPosition] = event;
    }
  }

  final redHotObservedAt = <int, DateTime>{
    for (final position in round?.redHotPositions ?? const <int>[])
      position: round!.observedAt,
    ...newerRedHotObservations,
  };
  final redHotPositions = <int>{
    for (final entry in redHotObservedAt.entries)
      if (replacements[entry.key] == null ||
          !replacements[entry.key]!.actionPerformedAt.isAfter(entry.value))
        entry.key,
  };
  final evidenceTimes = <DateTime>[
    if (round != null) round.observedAt,
    ...newerRedHotObservations.values,
    ...replacements.values.map((event) => event.actionPerformedAt),
  ]..sort();
  final positions =
      <int>{...newerRedHotObservations.keys, ...replacements.keys}.toList()
        ..sort();
  final sourceKey = <String>[
    round?.roundId ?? 'none',
    for (final position in positions)
      if (newerRedHotObservations[position] case final observedAt?)
        'red:$position:${observedAt.toUtc().toIso8601String()}',
    for (final position in positions)
      if (replacements[position] case final replacement?)
        'replace:$position:${replacement.eventId}',
  ].join('|');

  return BurnerBlockConditionProjection(
    sourceKey: sourceKey,
    latestEvidenceAt: evidenceTimes.isEmpty ? null : evidenceTimes.last,
    redHotPositions: Set<int>.unmodifiable(redHotPositions),
    replacementsByPosition: Map<int, BurnerBlockLifecycleEvent>.unmodifiable(
      replacements,
    ),
  );
}

bool _isLaterReplacement(
  BurnerBlockLifecycleEvent candidate,
  BurnerBlockLifecycleEvent current,
) {
  final performedComparison = candidate.actionPerformedAt.compareTo(
    current.actionPerformedAt,
  );
  if (performedComparison != 0) return performedComparison > 0;
  final completionComparison = candidate.completedAt.compareTo(
    current.completedAt,
  );
  if (completionComparison != 0) return completionComparison > 0;
  return candidate.eventId.compareTo(current.eventId) > 0;
}
