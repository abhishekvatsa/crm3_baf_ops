import 'burner_block_lifecycle_event.dart';
import 'burner_condition_round.dart';
import 'uv_detector_lifecycle_event.dart';

final class BurnerBlockConditionProjection {
  const BurnerBlockConditionProjection({
    required this.sourceKey,
    required this.latestEvidenceAt,
    required this.redHotPositions,
    required this.replacementsByPosition,
    required this.uvConditionsByPosition,
    required this.uvReplacementsByPosition,
    this.knownRedHotPositions = const {},
  });

  final String sourceKey;
  final DateTime? latestEvidenceAt;
  final Set<int> redHotPositions;
  final Map<int, BurnerBlockLifecycleEvent> replacementsByPosition;
  final Map<int, BurnerUvCondition> uvConditionsByPosition;
  final Map<int, UvDetectorLifecycleEvent> uvReplacementsByPosition;
  final Set<int> knownRedHotPositions;
}

BurnerBlockConditionProjection projectBurnerBlockCondition({
  required BurnerConditionRound? round,
  required Map<int, DateTime> newerRedHotObservations,
  required List<BurnerBlockLifecycleEvent> lifecycleEvents,
  List<BurnerBlockLifecycleEvent> currentLifecycleEvents =
      const <BurnerBlockLifecycleEvent>[],
  List<UvDetectorLifecycleEvent> uvLifecycleEvents =
      const <UvDetectorLifecycleEvent>[],
  List<UvDetectorLifecycleEvent> currentUvLifecycleEvents =
      const <UvDetectorLifecycleEvent>[],
  bool currentCollectionsAuthoritative = false,
  required String assetInstanceId,
}) {
  final replacements = <int, BurnerBlockLifecycleEvent>{};
  // The current collection is the server's effective answer for a physical
  // burner position. It is deliberately not just another candidate: a raw
  // event may retain the date it had before a reviewed correction, while the
  // current row carries the corrected projection. Once a current row exists,
  // raw history for that position must remain history.
  for (final event in currentLifecycleEvents) {
    if (event.assetInstanceId != assetInstanceId) continue;
    final current = replacements[event.burnerPosition];
    if (current == null || _isLaterReplacement(event, current)) {
      replacements[event.burnerPosition] = event;
    }
  }
  final currentBurnerPositions = replacements.keys.toSet();
  for (final event in lifecycleEvents) {
    if (currentCollectionsAuthoritative) break;
    if (event.assetInstanceId != assetInstanceId) continue;
    if (currentBurnerPositions.contains(event.burnerPosition)) continue;
    final current = replacements[event.burnerPosition];
    if (current == null || _isLaterReplacement(event, current)) {
      replacements[event.burnerPosition] = event;
    }
  }

  final uvReplacements = <int, UvDetectorLifecycleEvent>{};
  for (final event in currentUvLifecycleEvents) {
    if (event.assetInstanceId != assetInstanceId) continue;
    final current = uvReplacements[event.burnerPosition];
    if (current == null || _isLaterUvReplacement(event, current)) {
      uvReplacements[event.burnerPosition] = event;
    }
  }
  final currentUvPositions = uvReplacements.keys.toSet();
  for (final event in uvLifecycleEvents) {
    if (currentCollectionsAuthoritative) break;
    if (event.assetInstanceId != assetInstanceId) continue;
    if (currentUvPositions.contains(event.burnerPosition)) continue;
    final current = uvReplacements[event.burnerPosition];
    if (current == null || _isLaterUvReplacement(event, current)) {
      uvReplacements[event.burnerPosition] = event;
    }
  }
  final uvConditions = <int, BurnerUvCondition>{
    for (final observation
        in round?.uvObservations ?? const <BurnerUvObservation>[])
      observation.position: observation.condition,
  };
  for (final entry in uvReplacements.entries) {
    final observedAt = round
        ?.evidenceFor('uv.${entry.key}.condition')
        .observedAt;
    if (round == null ||
        round.uvObservations.isEmpty ||
        (observedAt != null &&
            entry.value.actionPerformedAt.isAfter(observedAt))) {
      uvConditions[entry.key] = BurnerUvCondition.serviceable;
    }
  }

  final redHotObservedAt = <int, DateTime>{
    for (final position in round?.redHotPositions ?? const <int>[])
      if (round!.evidenceFor('burners.$position.redHotObserved').observedAt
          case final observedAt?)
        position: observedAt,
    ...newerRedHotObservations,
  };
  final redHotPositions = <int>{
    // An undated legacy finding remains visible as unverified until checked.
    for (final position in round?.redHotPositions ?? const <int>[])
      if (round!.evidenceFor('burners.$position.redHotObserved').observedAt ==
          null)
        position,
    for (final entry in redHotObservedAt.entries)
      if (replacements[entry.key] == null ||
          !replacements[entry.key]!.actionPerformedAt.isAfter(entry.value))
        entry.key,
  };
  final evidenceTimes = <DateTime>[
    if (round != null)
      for (final field in burnerEvidenceFields)
        if (round.evidenceFor(field).observedAt case final observedAt?)
          observedAt,
    ...newerRedHotObservations.values,
    ...replacements.values.map((event) => event.actionPerformedAt),
    ...uvReplacements.values.map((event) => event.actionPerformedAt),
  ]..sort();
  final positions = <int>{
    ...newerRedHotObservations.keys,
    ...replacements.keys,
    ...uvReplacements.keys,
  }.toList()..sort();
  final sourceKey = <String>[
    round?.roundId ?? 'none',
    for (final position in positions)
      if (newerRedHotObservations[position] case final observedAt?)
        'red:$position:${observedAt.toUtc().toIso8601String()}',
    for (final position in positions)
      if (replacements[position] case final replacement?)
        'replace:$position:${replacement.eventId}:'
            '${replacement.actionPerformedAt.toUtc().toIso8601String()}:${replacement.version}',
    for (final position in positions)
      if (uvReplacements[position] case final replacement?)
        'uv-replace:$position:${replacement.eventId}:'
            '${replacement.actionPerformedAt.toUtc().toIso8601String()}:${replacement.version}',
  ].join('|');

  return BurnerBlockConditionProjection(
    sourceKey: sourceKey,
    latestEvidenceAt: evidenceTimes.isEmpty ? null : evidenceTimes.last,
    redHotPositions: Set<int>.unmodifiable(redHotPositions),
    knownRedHotPositions: {
      ...newerRedHotObservations.keys,
      if (round != null)
        for (var position = 1; position <= 8; position++)
          if (round
                  .evidenceFor('burners.$position.redHotObserved')
                  .observedAt !=
              null)
            position,
      for (final position in replacements.keys)
        if (round == null ||
            round.evidenceFor('burners.$position.redHotObserved').observedAt !=
                null)
          position,
    },
    replacementsByPosition: Map<int, BurnerBlockLifecycleEvent>.unmodifiable(
      replacements,
    ),
    uvConditionsByPosition: Map<int, BurnerUvCondition>.unmodifiable(
      uvConditions,
    ),
    uvReplacementsByPosition: Map<int, UvDetectorLifecycleEvent>.unmodifiable(
      uvReplacements,
    ),
  );
}

// What is installed now is what was installed last, physically. A report
// entered late about earlier work is history, not a correction of what came
// after it, and reading it as current brought back red-hot and melted-UV
// evidence a later replacement had cleared. This is the order the backend uses
// to decide the same thing, and the current state it stores is authoritative:
// physical action time, then the time the work was recorded, then the event's
// own identity so the answer never depends on delivery order.
bool _isLaterReplacement(
  BurnerBlockLifecycleEvent candidate,
  BurnerBlockLifecycleEvent current,
) {
  final performedComparison = candidate.actionPerformedAt.compareTo(
    current.actionPerformedAt,
  );
  if (performedComparison != 0) return performedComparison > 0;
  final recordedComparison = candidate.recordedAt.compareTo(current.recordedAt);
  if (recordedComparison != 0) return recordedComparison > 0;
  return candidate.eventId.compareTo(current.eventId) > 0;
}

bool _isLaterUvReplacement(
  UvDetectorLifecycleEvent candidate,
  UvDetectorLifecycleEvent current,
) {
  final performedComparison = candidate.actionPerformedAt.compareTo(
    current.actionPerformedAt,
  );
  if (performedComparison != 0) return performedComparison > 0;
  final recordedComparison = candidate.recordedAt.compareTo(current.recordedAt);
  if (recordedComparison != 0) return recordedComparison > 0;
  return candidate.eventId.compareTo(current.eventId) > 0;
}
