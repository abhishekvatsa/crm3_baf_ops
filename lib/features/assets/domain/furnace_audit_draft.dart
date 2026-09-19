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
    this.openIssueBasis = const [],
    Set<String>? knownEvidenceFields,
  }) : knownEvidenceFields = knownEvidenceFields ?? burnerEvidenceFields {
    _basisValues = _values();
    _lastValues = Map.of(_basisValues);
  }

  factory FurnaceAuditDraft.fromSources({
    required BurnerConditionRound? round,
    required BurnerBlockConditionProjection conditionProjection,
    List<Map<String, dynamic>> openIssueBasis = const [],
  }) {
    final redHot = conditionProjection.redHotPositions;
    final uv = Map<int, BurnerUvCondition>.of(
      conditionProjection.uvConditionsByPosition,
    );
    final prior = round?.observations;
    return FurnaceAuditDraft(
      sourceKey: [
        conditionProjection.sourceKey,
        for (final issue in openIssueBasis)
          'issue:${issue['id']}:${issue['version']}:${issue['updatedAt']}',
      ].join('|'),
      sourceAt: conditionProjection.latestEvidenceAt,
      openIssueBasis: openIssueBasis,
      knownEvidenceFields: {
        for (final position in conditionProjection.knownRedHotPositions)
          'burners.$position.redHotObserved',
        if (round != null)
          for (final field in burnerEvidenceFields)
            if (round.evidenceFor(field).observedAt != null) field,
        for (final position in conditionProjection.replacementsByPosition.keys)
          if (round == null ||
              round
                      .evidenceFor('burners.$position.redHotObserved')
                      .observedAt !=
                  null)
            'burners.$position.redHotObserved',
        for (final position
            in conditionProjection.uvReplacementsByPosition.keys)
          if (round == null ||
              round.uvObservations.isEmpty ||
              round.evidenceFor('uv.$position.condition').observedAt != null)
            'uv.$position.condition',
      },
      redHotPositions: Set<int>.of(redHot),
      draftSealRedHotObserved: round?.draftSealRedHotObserved ?? false,
      hotAirAtDraftSealObserved: round?.hotAirAtDraftSealObserved ?? false,
      uvByPosition: uv,
      burnerObservations: <BurnerConditionObservation>[
        for (var position = 1; position <= 8; position++)
          BurnerConditionObservation(
            position: position,
            flameObservation: prior == null
                ? BurnerRoundFlameObservation.notChecked
                : prior[position - 1].flameObservation,
            redHotObserved: redHot.contains(position),
            microampReading: prior == null
                ? null
                : prior[position - 1].microampReading,
            remarks: prior == null
                ? 'Condition matrix audit did not assess flame signal.'
                : prior[position - 1].remarks,
          ),
      ],
      replacementsByPosition: Map<int, BurnerBlockLifecycleEvent>.unmodifiable(
        conditionProjection.replacementsByPosition,
      ),
      uvReplacementsByPosition: Map<int, UvDetectorLifecycleEvent>.unmodifiable(
        conditionProjection.uvReplacementsByPosition,
      ),
    );
  }

  String sourceKey;
  DateTime? sourceAt;
  final Set<int> redHotPositions;
  bool draftSealRedHotObserved;
  bool hotAirAtDraftSealObserved;
  final Map<int, BurnerUvCondition> uvByPosition;
  List<BurnerConditionObservation> burnerObservations;
  Map<int, BurnerBlockLifecycleEvent> replacementsByPosition;
  Map<int, UvDetectorLifecycleEvent> uvReplacementsByPosition;
  List<Map<String, dynamic>> openIssueBasis;
  Set<String> knownEvidenceFields;
  late Map<String, Object?> _basisValues;
  late Map<String, Object?> _lastValues;
  final Map<String, int> _fieldRevisions = {};
  FurnaceAuditSubmission? _acceptedSubmission;
  String? _acceptedRoundId;
  DateTime? _acceptedAt;
  FurnaceAuditDraft? _reviewSnapshot;
  bool requiresReview = false;
  Set<String> conflicts = {};
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
    final values = _values();
    for (final field in values.keys) {
      if (values[field] != _lastValues[field]) {
        _fieldRevisions[field] = revision;
      }
    }
    _lastValues = values;
  }

  Set<String> get observedFields => _fieldRevisions.keys.toSet();
  bool get awaitingAcceptedBasis => _acceptedSubmission != null;
  bool isKnown(String field) =>
      knownEvidenceFields.contains(field) || observedFields.contains(field);

  void confirmFields(Iterable<String> fields) {
    for (final field in fields) {
      _fieldRevisions[field] = revision + 1;
    }
  }

  Map<String, dynamic> get installationBasis => {
    'burner': [
      for (final position in (replacementsByPosition.keys.toList()..sort()))
        {
          'position': position,
          'eventId': replacementsByPosition[position]!.eventId,
          'actionPerformedAt': replacementsByPosition[position]!
              .actionPerformedAt
              .toUtc()
              .toIso8601String(),
        },
    ],
    'uv': [
      for (final position in (uvReplacementsByPosition.keys.toList()..sort()))
        {
          'position': position,
          'eventId': uvReplacementsByPosition[position]!.eventId,
          'actionPerformedAt': uvReplacementsByPosition[position]!
              .actionPerformedAt
              .toUtc()
              .toIso8601String(),
        },
    ],
  };

  FurnaceAuditSubmission captureSubmission() => FurnaceAuditSubmission(
    revision: revision,
    values: Map.unmodifiable(_values()),
    observedFields: Set.unmodifiable(observedFields),
    installationBasis: installationBasis,
  );

  void acceptSubmission(
    FurnaceAuditSubmission submitted,
    String roundId,
    DateTime committedAt,
  ) {
    _acceptedSubmission = submitted;
    _acceptedRoundId = roundId;
    _acceptedAt = committedAt;
    requiresReview = false;
    conflicts = {};
    settleSave(submitted.revision);
  }

  /// Adopt untouched current values, preserving only the fields actually edited.
  /// Accepted replies rebase later edits against the immutable submitted values.
  void updateBasis(
    FurnaceAuditDraft fresh, {
    String? roundId,
    DateTime? observedAt,
  }) {
    final submitted = _acceptedSubmission;
    if (submitted != null &&
        roundId != _acceptedRoundId &&
        (observedAt == null ||
            _acceptedAt == null ||
            observedAt.isBefore(_acceptedAt!))) {
      return;
    }
    if (submitted == null && fresh.sourceKey == sourceKey && !requiresReview) {
      return;
    }
    final edits = submitted == null
        ? observedFields
        : {
            for (final entry in _fieldRevisions.entries)
              if (entry.value > submitted.revision) entry.key,
          };
    final preimages = submitted?.values ?? _basisValues;
    final incoming = fresh._values();
    final oldBasis = submitted?.installationBasis ?? installationBasis;
    conflicts = {
      for (final field in edits)
        if (incoming[field] != preimages[field] ||
            _installationForField(oldBasis, field) !=
                _installationForField(fresh.installationBasis, field))
          field,
    };
    _reviewSnapshot = fresh;
    if (requiresReview || conflicts.isNotEmpty) {
      requiresReview = true;
      return;
    }
    _adopt(fresh, edits);
  }

  void reviewCurrent({required bool keepLocalEdits}) {
    final fresh = _reviewSnapshot;
    if (fresh == null) return;
    final submitted = _acceptedSubmission;
    final edits = !keepLocalEdits
        ? <String>{}
        : submitted == null
        ? observedFields
        : {
            for (final entry in _fieldRevisions.entries)
              if (entry.value > submitted.revision) entry.key,
          };
    _adopt(fresh, edits);
  }

  void _adopt(FurnaceAuditDraft fresh, Set<String> edits) {
    final local = _values();
    final incoming = fresh._values();
    sourceKey = fresh.sourceKey;
    sourceAt = fresh.sourceAt;
    replacementsByPosition = fresh.replacementsByPosition;
    uvReplacementsByPosition = fresh.uvReplacementsByPosition;
    openIssueBasis = fresh.openIssueBasis;
    knownEvidenceFields = fresh.knownEvidenceFields;
    _basisValues = Map.of(incoming);
    for (final field in edits) {
      incoming[field] = local[field];
    }
    _applyValues(incoming);
    _fieldRevisions.removeWhere((field, _) => !edits.contains(field));
    _lastValues = _values();
    dirty = edits.isNotEmpty;
    _acceptedSubmission = null;
    _acceptedRoundId = null;
    _acceptedAt = null;
    _reviewSnapshot = null;
    requiresReview = false;
    conflicts = {};
  }

  Map<String, Object?> _values() => {
    for (final item in burnerObservations) ...{
      'burners.${item.position}.redHotObserved': redHotPositions.contains(
        item.position,
      ),
      'burners.${item.position}.flameObservation': item.flameObservation,
      'burners.${item.position}.microampReading': item.microampReading,
      'burners.${item.position}.remarks': item.remarks,
    },
    for (var position = 1; position <= 8; position++)
      'uv.$position.condition': uvByPosition[position],
    'draftSealRedHotObserved': draftSealRedHotObserved,
    'hotAirAtDraftSealObserved': hotAirAtDraftSealObserved,
  };

  void _applyValues(Map<String, Object?> values) {
    redHotPositions.clear();
    uvByPosition.clear();
    for (var position = 1; position <= 8; position++) {
      if (values['burners.$position.redHotObserved'] == true) {
        redHotPositions.add(position);
      }
      final uv = values['uv.$position.condition'];
      if (uv is BurnerUvCondition) uvByPosition[position] = uv;
    }
    burnerObservations = [
      for (var position = 1; position <= 8; position++)
        BurnerConditionObservation(
          position: position,
          redHotObserved: redHotPositions.contains(position),
          flameObservation:
              values['burners.$position.flameObservation']
                  as BurnerRoundFlameObservation,
          microampReading:
              values['burners.$position.microampReading'] as double?,
          remarks: values['burners.$position.remarks'] as String?,
        ),
    ];
    draftSealRedHotObserved = values['draftSealRedHotObserved'] as bool;
    hotAirAtDraftSealObserved = values['hotAirAtDraftSealObserved'] as bool;
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
        condition: uvByPosition[position] ?? BurnerUvCondition.serviceable,
      ),
  ];

  void setRedHot(int position, bool value) {
    value ? redHotPositions.add(position) : redHotPositions.remove(position);
    burnerObservations = <BurnerConditionObservation>[
      for (final observation in burnerObservations)
        BurnerConditionObservation(
          position: observation.position,
          flameObservation: observation.flameObservation,
          redHotObserved: observation.position == position
              ? value
              : observation.redHotObserved,
          microampReading: observation.microampReading,
          remarks: observation.remarks,
        ),
    ];
  }
}

class FurnaceAuditSubmission {
  const FurnaceAuditSubmission({
    required this.revision,
    required this.values,
    required this.observedFields,
    required this.installationBasis,
  });
  final int revision;
  final Map<String, Object?> values;
  final Set<String> observedFields;
  final Map<String, dynamic> installationBasis;
}

String _installationForField(Map<String, dynamic> basis, String field) {
  final parts = field.split('.');
  if (parts.length < 3) return '';
  final position = int.tryParse(parts[1]);
  final group = parts.first == 'uv' ? 'uv' : 'burner';
  final rows = basis[group] as List;
  for (final row in rows) {
    if (row is Map && row['position'] == position) {
      return '${row['eventId']}:${row['actionPerformedAt']}';
    }
  }
  return '';
}
