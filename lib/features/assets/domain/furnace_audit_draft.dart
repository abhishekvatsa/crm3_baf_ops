import '../data/burner_block_condition_projection.dart';
import '../data/burner_block_lifecycle_event.dart';
import '../data/burner_condition_round.dart';
import '../data/uv_detector_lifecycle_event.dart';

/// What one furnace's condition audit currently says on screen, before it is
/// recorded.
///
/// The screen keeps one of these per furnace and edits it in place, so a draft
/// outlives both the save it was submitted for and the snapshots that arrive
/// while that save is in flight. It therefore carries enough to say which
/// revision of itself was submitted, and whether it may be replaced.

class FurnaceAuditDraft {
  FurnaceAuditDraft({
    required this.sourceKey,
    required this.sourceAt,
    required this.redHotPositions,
    required this.draftSealRedHotObserved,
    required this.hotAirAtDraftSealObserved,
    required this.uvByPosition,
    required this.burnerObservations,
    required this.replacementsByPosition,
    required this.uvReplacementsByPosition,
  });

  factory FurnaceAuditDraft.fromSources({
    required BurnerConditionRound? round,
    required BurnerBlockConditionProjection conditionProjection,
  }) {
    final redHot = conditionProjection.redHotPositions;
    final uv = Map<int, BurnerUvCondition>.of(
      conditionProjection.uvConditionsByPosition,
    );
    final prior = round?.observations;
    return FurnaceAuditDraft(
      sourceKey: conditionProjection.sourceKey,
      sourceAt: conditionProjection.latestEvidenceAt,
      redHotPositions: Set<int>.of(redHot),
      draftSealRedHotObserved: round?.draftSealRedHotObserved ?? false,
      hotAirAtDraftSealObserved: round?.hotAirAtDraftSealObserved ?? false,
      uvByPosition: uv,
      burnerObservations: <BurnerConditionObservation>[
        for (var position = 1; position <= 8; position++)
          BurnerConditionObservation(
            position: position,
            flameObservation:
                prior == null
                    ? BurnerRoundFlameObservation.notChecked
                    : prior[position - 1].flameObservation,
            redHotObserved: redHot.contains(position),
            microampReading:
                prior == null ? null : prior[position - 1].microampReading,
            remarks:
                prior == null
                    ? 'Condition matrix audit did not assess flame signal.'
                    : prior[position - 1].remarks,
          ),
      ],
      replacementsByPosition: Map<int, BurnerBlockLifecycleEvent>.unmodifiable(
        conditionProjection.replacementsByPosition,
      ),
      uvReplacementsByPosition: Map<int, UvDetectorLifecycleEvent>.unmodifiable(
        <int, UvDetectorLifecycleEvent>{
          for (final entry
              in conditionProjection.uvReplacementsByPosition.entries)
            if (round == null ||
                entry.value.actionPerformedAt.isAfter(round.observedAt))
              entry.key: entry.value,
        },
      ),
    );
  }

  final String sourceKey;
  final DateTime? sourceAt;
  final Set<int> redHotPositions;
  bool draftSealRedHotObserved;
  bool hotAirAtDraftSealObserved;
  final Map<int, BurnerUvCondition> uvByPosition;
  List<BurnerConditionObservation> burnerObservations;
  final Map<int, BurnerBlockLifecycleEvent> replacementsByPosition;
  final Map<int, UvDetectorLifecycleEvent> uvReplacementsByPosition;
  bool dirty = false;

  /// How many times this draft has been edited.
  ///
  /// A save is submitted for one particular revision of a draft. The controls
  /// that record an observation stay live while the save is in flight, so the
  /// draft can move on before the answer comes back, and this is what tells
  /// the two apart.
  int revision = 0;

  /// Records an edit, which leaves the draft pending and moves it on.
  void markEdited() {
    dirty = true;
    revision += 1;
  }

  /// Settles a save that was submitted for [submittedRevision].
  ///
  /// The draft stops being pending only if it is still the revision that was
  /// submitted. An observation recorded while the save was in flight was never
  /// in that envelope, so it stays pending and is saved next - rather than
  /// being marked as recorded and then quietly replaced by the server's copy
  /// of the earlier one.
  ///
  /// Returns whether the pending state was cleared.
  bool settleSave(int submittedRevision) {
    if (revision != submittedRevision) return false;
    dirty = false;
    return true;
  }

  /// The condition round this draft was built from, or null when the furnace
  /// had none. [sourceKey] leads with it, which is what makes a draft
  /// recognisably composed against a particular state of the furnace.
  String? get composedAgainstRoundId {
    final head = sourceKey.split('|').first;
    return head == 'none' || head.isEmpty ? null : head;
  }

  /// Whether this draft should be replaced by a newly arrived snapshot of the
  /// same furnace. A draft with unsaved work on it never is.
  bool shouldAdoptSnapshot(String snapshotSourceKey) =>
      !dirty && sourceKey != snapshotSourceKey;

  List<BurnerUvObservation> get uvObservations => <BurnerUvObservation>[
    for (var position = 1; position <= 8; position++)
      BurnerUvObservation(
        position: position,
        condition: uvByPosition[position]!,
      ),
  ];

  void setRedHot(int position, bool value) {
    value ? redHotPositions.add(position) : redHotPositions.remove(position);
    burnerObservations = <BurnerConditionObservation>[
      for (final observation in burnerObservations)
        BurnerConditionObservation(
          position: observation.position,
          flameObservation: observation.flameObservation,
          redHotObserved:
              observation.position == position
                  ? value
                  : observation.redHotObserved,
          microampReading: observation.microampReading,
          remarks: observation.remarks,
        ),
    ];
  }
}
