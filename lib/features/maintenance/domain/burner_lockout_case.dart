import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../planned_maintenance/models/component_action_model.dart';

const burnerLockoutClassification = 'furnaceBurnerLockout';
const burnerLockoutSchemaVersion = 1;
const burnerMicroampStructuralMaximum = 1000000.0;

const burnerLockoutSynchronizedFieldNames = <String>{
  'burnerLockoutSchemaVersion',
  'burnerPositions',
  'burnerCommonMode',
  'burnerCycleStage',
  'burnerHmiAlarm',
  'burnerFlameObservation',
  'burnerSparkObservation',
  'burnerRelightAttempts',
  'burnerRemainsLockedOut',
  'burnerRedHotPositions',
  'burnerAttendedPositions',
  'burnerResolutionEvidence',
};

enum BurnerCycleStage { notRecorded, purge, ignition, firing, unknown }

enum BurnerObservation { seen, notSeen, notChecked }

enum BurnerResolutionOutcome {
  returnedToService,
  remainsLockedOut,
  isolatedForFollowUp,
}

enum BurnerActionCode {
  feedbackReset,
  airLineCleaning,
  uvDetectorCleaning,
  poking,
  flameAdjustment,
  igniterRodHolderCleaning,
  burnerControllerReset,
  burnerControllerPowerOn,
  safetyShutoffValveRelayWork,
  relay6A6BWork,
  igniterRodReplacement,
  uvDetectorReplacement,
  safetyShutoffValveSolenoidWork,
  other,
}

extension BurnerActionCodeLabel on BurnerActionCode {
  String get label => switch (this) {
    BurnerActionCode.feedbackReset => 'Feedback reset',
    BurnerActionCode.airLineCleaning => 'Air-line cleaning',
    BurnerActionCode.uvDetectorCleaning => 'UV detector cleaning',
    BurnerActionCode.poking => 'Poking / passage clearing',
    BurnerActionCode.flameAdjustment => 'Flame adjustment',
    BurnerActionCode.igniterRodHolderCleaning =>
      'Igniter rod / holder cleaning',
    BurnerActionCode.burnerControllerReset => 'Burner controller reset',
    BurnerActionCode.burnerControllerPowerOn => 'Burner controller switched on',
    BurnerActionCode.safetyShutoffValveRelayWork =>
      'Safety shutoff-valve relay work',
    BurnerActionCode.relay6A6BWork => '6A / 6B relay work (site term)',
    BurnerActionCode.igniterRodReplacement => 'Igniter rod replacement',
    BurnerActionCode.uvDetectorReplacement => 'UV detector replacement',
    BurnerActionCode.safetyShutoffValveSolenoidWork =>
      'Safety shutoff-valve solenoid work',
    BurnerActionCode.other => 'Other recorded work',
  };

  bool get isResetOnly => switch (this) {
    BurnerActionCode.feedbackReset ||
    BurnerActionCode.burnerControllerReset ||
    BurnerActionCode.burnerControllerPowerOn => true,
    _ => false,
  };

  ActionType get actionType => switch (this) {
    BurnerActionCode.igniterRodReplacement ||
    BurnerActionCode.uvDetectorReplacement => ActionType.replacement,
    _ => ActionType.repair,
  };
}

class BurnerLockoutCaseReadResult {
  const BurnerLockoutCaseReadResult({required this.value, this.error});

  final BurnerLockoutCase? value;
  final FormatException? error;

  bool get isValid => error == null;
}

class BurnerLockoutResolution {
  BurnerLockoutResolution({
    required Map<int, BurnerResolutionOutcome> outcomes,
    Map<int, double> microampReadings = const <int, double>{},
  }) : outcomes = Map<int, BurnerResolutionOutcome>.unmodifiable(outcomes),
       microampReadings = Map<int, double>.unmodifiable(microampReadings) {
    if (!_isSubset(microampReadings.keys, outcomes.keys)) {
      throw const FormatException(
        'Microamp readings must belong to attended burner positions.',
      );
    }
    for (final entry in microampReadings.entries) {
      _validateMicroampReading(entry.value, position: entry.key);
    }
  }

  final Map<int, BurnerResolutionOutcome> outcomes;
  final Map<int, double> microampReadings;

  List<int> get attendedPositions => outcomes.keys.toList()..sort();
}

class BurnerLockoutCase {
  BurnerLockoutCase({
    required List<int> positions,
    required this.commonMode,
    required this.cycleStage,
    this.hmiAlarm,
    required this.flameObservation,
    required this.sparkObservation,
    required this.relightAttempts,
    required this.remainsLockedOut,
    List<int> redHotPositions = const <int>[],
    List<int> attendedPositions = const <int>[],
    Map<int, BurnerResolutionOutcome> resolutionOutcomes =
        const <int, BurnerResolutionOutcome>{},
    Map<int, List<BurnerActionCode>> resolutionActionCodes =
        const <int, List<BurnerActionCode>>{},
    Map<int, double> resolutionMicroampReadings = const <int, double>{},
  }) : positions = _validatedPositions(positions, field: 'burnerPositions'),
       redHotPositions = _validatedPositions(
         redHotPositions,
         field: 'burnerRedHotPositions',
         allowEmpty: true,
       ),
       attendedPositions = _validatedPositions(
         attendedPositions,
         field: 'burnerAttendedPositions',
         allowEmpty: true,
       ),
       resolutionOutcomes = Map<int, BurnerResolutionOutcome>.unmodifiable(
         resolutionOutcomes,
       ),
       resolutionActionCodes = Map<int, List<BurnerActionCode>>.unmodifiable(
         <int, List<BurnerActionCode>>{
           for (final entry in resolutionActionCodes.entries)
             entry.key: List<BurnerActionCode>.unmodifiable(entry.value),
         },
       ),
       resolutionMicroampReadings = Map<int, double>.unmodifiable(
         resolutionMicroampReadings,
       ) {
    _validateRelationships();
  }

  final List<int> positions;
  final bool commonMode;
  final BurnerCycleStage cycleStage;
  final String? hmiAlarm;
  final BurnerObservation flameObservation;
  final BurnerObservation sparkObservation;
  final int relightAttempts;
  final bool remainsLockedOut;
  final List<int> redHotPositions;
  final List<int> attendedPositions;
  final Map<int, BurnerResolutionOutcome> resolutionOutcomes;
  final Map<int, List<BurnerActionCode>> resolutionActionCodes;
  final Map<int, double> resolutionMicroampReadings;

  bool get hasRedHotObservation => redHotPositions.isNotEmpty;

  String reportDescription({String? notes}) {
    final entered = notes?.trim();
    if (entered != null && entered.isNotEmpty) return entered;
    final noun = positions.length == 1 ? 'burner' : 'burners';
    return 'Burner lockout reported on $noun ${positions.join(', ')}.';
  }

  bool get isResolutionComplete =>
      _samePositions(attendedPositions, positions) &&
      _samePositions(resolutionOutcomes.keys, positions) &&
      _samePositions(resolutionActionCodes.keys, positions);

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'burnerLockoutSchemaVersion': burnerLockoutSchemaVersion,
    'burnerPositions': positions,
    'burnerCommonMode': commonMode,
    'burnerCycleStage': cycleStage.name,
    'burnerHmiAlarm': hmiAlarm,
    'burnerFlameObservation': flameObservation.name,
    'burnerSparkObservation': sparkObservation.name,
    'burnerRelightAttempts': relightAttempts,
    'burnerRemainsLockedOut': remainsLockedOut,
    'burnerRedHotPositions': redHotPositions,
    'burnerAttendedPositions': attendedPositions,
    'burnerResolutionEvidence': _resolutionEvidenceMap(),
  };

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'schemaVersion': burnerLockoutSchemaVersion,
    'positions': positions,
    'commonMode': commonMode,
    'cycleStage': cycleStage.name,
    'hmiAlarm': hmiAlarm,
    'flameObservation': flameObservation.name,
    'sparkObservation': sparkObservation.name,
    'relightAttempts': relightAttempts,
    'remainsLockedOut': remainsLockedOut,
    'redHotPositions': redHotPositions,
    'attendedPositions': attendedPositions,
    'resolutionEvidence': _resolutionEvidenceMap(),
  };

  Map<String, dynamic> _resolutionEvidenceMap() => <String, dynamic>{
    for (final position in attendedPositions)
      '$position': <String, dynamic>{
        'outcome': resolutionOutcomes[position]!.name,
        'actionCodes': <String>[
          for (final code in resolutionActionCodes[position]!) code.name,
        ],
        if (resolutionMicroampReadings[position] case final reading?)
          'microampReading': reading,
      },
  };

  BurnerLockoutCase withResolution(
    BurnerLockoutResolution resolution, {
    required Iterable<ComponentAction> actions,
  }) {
    validateBurnerResolutionEvidence(
      lockout: this,
      resolution: resolution,
      actions: actions,
    );
    final evidence = _burnerActionEvidenceForResolution(
      lockout: this,
      resolution: resolution,
      actions: actions,
    );
    return BurnerLockoutCase(
      positions: positions,
      commonMode: commonMode,
      cycleStage: cycleStage,
      hmiAlarm: hmiAlarm,
      flameObservation: flameObservation,
      sparkObservation: sparkObservation,
      relightAttempts: relightAttempts,
      remainsLockedOut: remainsLockedOut,
      redHotPositions: redHotPositions,
      attendedPositions: resolution.attendedPositions,
      resolutionOutcomes: resolution.outcomes,
      resolutionActionCodes: evidence.actionCodes,
      resolutionMicroampReadings: evidence.microampReadings,
    );
  }

  BurnerLockoutCase withResolutionFromActions(
    Iterable<ComponentAction> actions,
  ) {
    final resolution = burnerResolutionFromActions(
      lockout: this,
      actions: actions,
    );
    return withResolution(resolution, actions: actions);
  }

  BurnerLockoutCase clearResolution() => BurnerLockoutCase(
    positions: positions,
    commonMode: commonMode,
    cycleStage: cycleStage,
    hmiAlarm: hmiAlarm,
    flameObservation: flameObservation,
    sparkObservation: sparkObservation,
    relightAttempts: relightAttempts,
    remainsLockedOut: remainsLockedOut,
    redHotPositions: redHotPositions,
  );

  factory BurnerLockoutCase.fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        burnerLockoutSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.length != burnerLockoutSynchronizedFieldNames.length) {
      throw PersistedDataFormatException(
        field: 'burnerPositions',
        source: source,
        detail: 'burner-lockout fields must be present together',
      );
    }
    final version = readRequiredPersistedInt(
      map['burnerLockoutSchemaVersion'],
      field: 'burnerLockoutSchemaVersion',
      source: source,
    );
    if (version != burnerLockoutSchemaVersion) {
      throw PersistedDataFormatException(
        field: 'burnerLockoutSchemaVersion',
        source: source,
        detail: 'unsupported schema version $version',
      );
    }
    final attendedPositions = _readPositions(
      map['burnerAttendedPositions'],
      field: 'burnerAttendedPositions',
      source: source,
      allowEmpty: true,
    );
    final resolutionEvidence = _readResolutionEvidence(
      map['burnerResolutionEvidence'],
      source: source,
    );
    return BurnerLockoutCase(
      positions: _readPositions(
        map['burnerPositions'],
        field: 'burnerPositions',
        source: source,
      ),
      commonMode: readRequiredPersistedBool(
        map['burnerCommonMode'],
        field: 'burnerCommonMode',
        source: source,
      ),
      cycleStage: readRequiredPersistedEnum(
        BurnerCycleStage.values,
        map['burnerCycleStage'],
        field: 'burnerCycleStage',
        source: source,
      ),
      hmiAlarm: readOptionalPersistedString(
        map['burnerHmiAlarm'],
        field: 'burnerHmiAlarm',
        source: source,
      ),
      flameObservation: readRequiredPersistedEnum(
        BurnerObservation.values,
        map['burnerFlameObservation'],
        field: 'burnerFlameObservation',
        source: source,
      ),
      sparkObservation: readRequiredPersistedEnum(
        BurnerObservation.values,
        map['burnerSparkObservation'],
        field: 'burnerSparkObservation',
        source: source,
      ),
      relightAttempts: readRequiredPersistedInt(
        map['burnerRelightAttempts'],
        field: 'burnerRelightAttempts',
        source: source,
        minimum: 0,
      ),
      remainsLockedOut: readRequiredPersistedBool(
        map['burnerRemainsLockedOut'],
        field: 'burnerRemainsLockedOut',
        source: source,
      ),
      redHotPositions: _readPositions(
        map['burnerRedHotPositions'],
        field: 'burnerRedHotPositions',
        source: source,
        allowEmpty: true,
      ),
      attendedPositions: attendedPositions,
      resolutionOutcomes: resolutionEvidence.outcomes,
      resolutionActionCodes: resolutionEvidence.actionCodes,
      resolutionMicroampReadings: resolutionEvidence.microampReadings,
    );
  }

  static BurnerLockoutCase? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        burnerLockoutSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.isEmpty) return null;
    return BurnerLockoutCase.fromSynchronizedFields(map, source: source);
  }

  static BurnerLockoutCase? tryDecodeLocal(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final root = Map<String, dynamic>.from(decoded);
    final raw = root['burnerLockout'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'burnerLockout',
        source: 'local maintenance metadata',
        detail: 'expected an object',
      );
    }
    final local = Map<String, dynamic>.from(raw);
    return BurnerLockoutCase.fromSynchronizedFields(<String, dynamic>{
      'burnerLockoutSchemaVersion': local['schemaVersion'],
      'burnerPositions': local['positions'],
      'burnerCommonMode': local['commonMode'],
      'burnerCycleStage': local['cycleStage'],
      'burnerHmiAlarm': local['hmiAlarm'],
      'burnerFlameObservation': local['flameObservation'],
      'burnerSparkObservation': local['sparkObservation'],
      'burnerRelightAttempts': local['relightAttempts'],
      'burnerRemainsLockedOut': local['remainsLockedOut'],
      'burnerRedHotPositions': local['redHotPositions'],
      'burnerAttendedPositions': local['attendedPositions'],
      'burnerResolutionEvidence': local['resolutionEvidence'],
    }, source: 'local maintenance metadata');
  }

  void _validateRelationships() {
    if (positions.length == 1 && commonMode) {
      throw const FormatException(
        'A one-burner lockout cannot be classified as common mode.',
      );
    }
    if (!_isSubset(redHotPositions, positions)) {
      throw const FormatException(
        'Red-hot burner positions must be selected lockout positions.',
      );
    }
    if (!_isSubset(attendedPositions, positions) ||
        !_isSubset(resolutionOutcomes.keys, positions) ||
        !_isSubset(resolutionActionCodes.keys, positions) ||
        !_isSubset(resolutionMicroampReadings.keys, attendedPositions)) {
      throw const FormatException(
        'Attendance and outcomes must belong to selected burner positions.',
      );
    }
    if (!_samePositions(attendedPositions, resolutionOutcomes.keys) ||
        !_samePositions(attendedPositions, resolutionActionCodes.keys)) {
      throw const FormatException(
        'Every attended burner must have one terminal outcome and action evidence.',
      );
    }
    for (final position in attendedPositions) {
      final codes = resolutionActionCodes[position] ?? const [];
      if (codes.isEmpty || codes.toSet().length != codes.length) {
        throw const FormatException(
          'Every attended burner must have unique action evidence.',
        );
      }
      if (resolutionOutcomes[position] ==
              BurnerResolutionOutcome.returnedToService &&
          codes.every((code) => code.isResetOnly)) {
        throw FormatException(
          'Burner $position cannot be returned to service on reset-only evidence.',
        );
      }
      final reading = resolutionMicroampReadings[position];
      if (reading != null) {
        _validateMicroampReading(reading, position: position);
      }
    }
    if (relightAttempts > 20) {
      throw const FormatException('Relight attempts cannot exceed 20.');
    }
    final alarmLength = hmiAlarm?.trim().length ?? 0;
    if (alarmLength > 300) {
      throw const FormatException(
        'HMI alarm text cannot exceed 300 characters.',
      );
    }
  }
}

String mergeBurnerLockoutIntoMaintenanceMetadata(
  String? existing,
  BurnerLockoutCase? value,
) {
  final root = _readMetadataRoot(existing);
  if (value == null) {
    root.remove('burnerLockout');
  } else {
    root['burnerLockout'] = value.toLocalMap();
  }
  return jsonEncode(root);
}

String mergeQualityIntentIntoMaintenanceMetadata(
  String? existing,
  Map<String, dynamic>? value,
) {
  final root = _readMetadataRoot(existing);
  if (value == null) {
    root.remove('qualityIntent');
  } else {
    root['qualityIntent'] = value;
  }
  return jsonEncode(root);
}

String mergeMaintenanceMetadataEnvelopes({
  String? existing,
  Map<String, dynamic>? qualityIntent,
  BurnerLockoutCase? burnerLockout,
}) {
  final root = _readMetadataRoot(existing);
  if (qualityIntent != null) root['qualityIntent'] = qualityIntent;
  if (burnerLockout != null) root['burnerLockout'] = burnerLockout.toLocalMap();
  return jsonEncode(root);
}

String burnerTag(int furnaceNumber, int burnerPosition) =>
    'FR-${furnaceNumber.toString().padLeft(2, '0')}-B${burnerPosition.toString().padLeft(2, '0')}';

String burnerActionSessionId(String ticketId, int burnerPosition) =>
    'burner_${ticketId}_$burnerPosition';

ComponentAction buildBurnerComponentAction({
  required String ticketId,
  required int furnaceNumber,
  required int burnerPosition,
  required BurnerActionCode code,
  required BurnerResolutionOutcome outcome,
  required String performedBy,
  required DateTime performedAt,
  double? microampReading,
  String? remarks,
}) {
  if (microampReading != null) {
    _validateMicroampReading(microampReading, position: burnerPosition);
  }
  return ComponentAction(
    id: '${burnerActionSessionId(ticketId, burnerPosition)}_${code.name}',
    asset: 'Furnace $furnaceNumber',
    component: 'Burner $burnerPosition',
    system: 'Combustion system',
    subsystem: 'Burner system',
    subComponent: code.label,
    tag: burnerTag(furnaceNumber, burnerPosition),
    instance: '$burnerPosition',
    actionType: code.actionType,
    replacement:
        code.actionType == ActionType.replacement
            ? ReplacementType.newPart
            : null,
    resolution: code.label,
    remarks: remarks,
    status: ActionStatus.resolved,
    createdAt: performedAt,
    severity: ActionSeverity.high,
    performedBy: performedBy,
    updatedAt: performedAt,
    attendanceSessionId: burnerActionSessionId(ticketId, burnerPosition),
    burnerPosition: burnerPosition,
    burnerActionCode: code.name,
    burnerOutcome: outcome.name,
    burnerMicroampReading: microampReading,
  );
}

void validateBurnerResolutionEvidence({
  required BurnerLockoutCase lockout,
  required BurnerLockoutResolution resolution,
  required Iterable<ComponentAction> actions,
}) {
  if (!_samePositions(resolution.outcomes.keys, lockout.positions)) {
    throw StateError('Record one terminal outcome for every affected burner.');
  }
  _burnerActionEvidenceForResolution(
    lockout: lockout,
    resolution: resolution,
    actions: actions,
  );
}

BurnerLockoutResolution burnerResolutionFromActions({
  required BurnerLockoutCase lockout,
  required Iterable<ComponentAction> actions,
}) {
  final outcomes = <int, BurnerResolutionOutcome>{};
  final microampReadings = <int, double>{};
  for (final action in actions) {
    final rawPosition = action.burnerPosition;
    final rawCode = action.burnerActionCode;
    final rawOutcome = action.burnerOutcome;
    final rawMicroampReading = action.burnerMicroampReading;
    final hasBurnerEvidence =
        rawPosition != null ||
        rawCode != null ||
        rawOutcome != null ||
        rawMicroampReading != null;
    if (!hasBurnerEvidence) continue;
    if (rawPosition is! int ||
        rawCode is! String ||
        rawOutcome is! String ||
        !lockout.positions.contains(rawPosition)) {
      throw StateError(
        'Saved burner action evidence is incomplete or invalid.',
      );
    }
    final outcome = _enumByName(BurnerResolutionOutcome.values, rawOutcome);
    if (outcome == null) {
      throw StateError('Saved burner outcome evidence is invalid.');
    }
    final existing = outcomes[rawPosition];
    if (existing != null && existing != outcome) {
      throw StateError(
        'Saved burner actions disagree on the outcome for Burner $rawPosition.',
      );
    }
    outcomes[rawPosition] = outcome;
    if (rawMicroampReading != null) {
      final reading = _readActionMicroampReading(
        rawMicroampReading,
        position: rawPosition,
      );
      final existingReading = microampReadings[rawPosition];
      if (existingReading != null && existingReading != reading) {
        throw StateError(
          'Saved burner actions disagree on the microamp reading for Burner $rawPosition.',
        );
      }
      microampReadings[rawPosition] = reading;
    }
  }
  final resolution = BurnerLockoutResolution(
    outcomes: outcomes,
    microampReadings: microampReadings,
  );
  validateBurnerResolutionEvidence(
    lockout: lockout,
    resolution: resolution,
    actions: actions,
  );
  return resolution;
}

void validatePersistedBurnerResolutionEvidence({
  required BurnerLockoutCase lockout,
  required Iterable<ComponentAction> actions,
}) {
  try {
    final rebuilt = lockout.withResolutionFromActions(actions);
    if (!_sameOutcomes(
          rebuilt.resolutionOutcomes,
          lockout.resolutionOutcomes,
        ) ||
        !_sameActionCodes(
          rebuilt.resolutionActionCodes,
          lockout.resolutionActionCodes,
        ) ||
        !_sameMicroampReadings(
          rebuilt.resolutionMicroampReadings,
          lockout.resolutionMicroampReadings,
        )) {
      throw const FormatException(
        'Structured burner evidence does not match actionsJson.',
      );
    }
  } on StateError catch (error) {
    throw FormatException(error.message);
  }
}

_BurnerActionEvidence _burnerActionEvidenceForResolution({
  required BurnerLockoutCase lockout,
  required BurnerLockoutResolution resolution,
  required Iterable<ComponentAction> actions,
}) {
  final actionCodes = <int, List<BurnerActionCode>>{
    for (final position in lockout.positions) position: <BurnerActionCode>[],
  };
  final microampReadings = <int, double>{};
  for (final action in actions) {
    final rawPosition = action.burnerPosition;
    final rawCode = action.burnerActionCode;
    final rawOutcome = action.burnerOutcome;
    final rawMicroampReading = action.burnerMicroampReading;
    final hasBurnerEvidence =
        rawPosition != null ||
        rawCode != null ||
        rawOutcome != null ||
        rawMicroampReading != null;
    if (!hasBurnerEvidence) continue;
    if (rawPosition is! int ||
        rawCode is! String ||
        rawOutcome is! String ||
        !lockout.positions.contains(rawPosition)) {
      throw StateError(
        'Saved burner action evidence is incomplete or invalid.',
      );
    }
    final code = _enumByName(BurnerActionCode.values, rawCode);
    final outcome = _enumByName(BurnerResolutionOutcome.values, rawOutcome);
    if (code == null || outcome == null) {
      throw StateError('Saved burner action evidence is invalid.');
    }
    if (resolution.outcomes[rawPosition] != outcome) {
      throw StateError(
        'Saved burner action evidence disagrees with the terminal outcome for Burner $rawPosition.',
      );
    }
    if (!actionCodes[rawPosition]!.contains(code)) {
      actionCodes[rawPosition]!.add(code);
    }
    if (rawMicroampReading != null) {
      final reading = _readActionMicroampReading(
        rawMicroampReading,
        position: rawPosition,
      );
      final existingReading = microampReadings[rawPosition];
      if (existingReading != null && existingReading != reading) {
        throw StateError(
          'Saved burner actions disagree on the microamp reading for Burner $rawPosition.',
        );
      }
      microampReadings[rawPosition] = reading;
    }
  }
  if (!_sameMicroampReadings(microampReadings, resolution.microampReadings)) {
    throw StateError(
      'Saved burner actions disagree with the recorded microamp readings.',
    );
  }
  for (final position in lockout.positions) {
    final codes = actionCodes[position]!;
    if (codes.isEmpty) {
      throw StateError(
        'Record work or inspection evidence for Burner $position.',
      );
    }
    if (resolution.outcomes[position] ==
            BurnerResolutionOutcome.returnedToService &&
        codes.every((code) => code.isResetOnly)) {
      throw StateError(
        'Burner $position cannot be returned to service on reset-only evidence.',
      );
    }
    codes.sort((left, right) => left.index.compareTo(right.index));
  }
  return (
    outcomes: Map<int, BurnerResolutionOutcome>.from(resolution.outcomes),
    actionCodes: actionCodes,
    microampReadings: microampReadings,
  );
}

Map<String, dynamic> _readMetadataRoot(String? existing) {
  if (existing == null || existing.trim().isEmpty) return <String, dynamic>{};
  dynamic decoded;
  try {
    decoded = jsonDecode(existing);
  } on FormatException {
    return <String, dynamic>{'legacyMetadata': existing};
  }
  if (decoded is! Map) return <String, dynamic>{'legacyMetadata': existing};
  return Map<String, dynamic>.from(decoded);
}

List<int> _readPositions(
  dynamic value, {
  required String field,
  required String source,
  bool allowEmpty = false,
}) {
  if (value is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an integer array (${value.runtimeType})',
    );
  }
  final positions = <int>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! int) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'expected an integer (${item.runtimeType})',
      );
    }
    positions.add(item);
  }
  try {
    return _validatedPositions(positions, field: field, allowEmpty: allowEmpty);
  } on FormatException catch (error) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: error.message,
    );
  }
}

_BurnerActionEvidence _readResolutionEvidence(
  dynamic value, {
  required String source,
}) {
  if (value is! Map) {
    throw PersistedDataFormatException(
      field: 'burnerResolutionEvidence',
      source: source,
      detail: 'expected an evidence object (${value.runtimeType})',
    );
  }
  final outcomes = <int, BurnerResolutionOutcome>{};
  final actionCodes = <int, List<BurnerActionCode>>{};
  final microampReadings = <int, double>{};
  for (final rawEntry in value.entries) {
    final key = rawEntry.key;
    if (key is! String || !RegExp(r'^[1-8]$').hasMatch(key)) {
      throw PersistedDataFormatException(
        field: 'burnerResolutionEvidence',
        source: source,
        detail: 'evidence keys must be burner positions 1 through 8',
      );
    }
    final position = int.parse(key);
    final rawEvidence = rawEntry.value;
    if (rawEvidence is! Map ||
        rawEvidence.keys.any((field) => field is! String) ||
        rawEvidence.keys.any(
          (field) =>
              field != 'outcome' &&
              field != 'actionCodes' &&
              field != 'microampReading',
        ) ||
        !rawEvidence.containsKey('outcome') ||
        !rawEvidence.containsKey('actionCodes')) {
      throw PersistedDataFormatException(
        field: 'burnerResolutionEvidence.$key',
        source: source,
        detail: 'expected outcome, actionCodes, and optional microampReading',
      );
    }
    final evidence = Map<String, dynamic>.from(rawEvidence);
    outcomes[position] = readRequiredPersistedEnum(
      BurnerResolutionOutcome.values,
      evidence['outcome'],
      field: 'burnerResolutionEvidence.$key.outcome',
      source: source,
    );
    final rawCodes = evidence['actionCodes'];
    if (rawCodes is! List || rawCodes.isEmpty) {
      throw PersistedDataFormatException(
        field: 'burnerResolutionEvidence.$key.actionCodes',
        source: source,
        detail: 'expected a non-empty action-code array',
      );
    }
    final codes = <BurnerActionCode>[];
    for (var index = 0; index < rawCodes.length; index++) {
      final code = readRequiredPersistedEnum(
        BurnerActionCode.values,
        rawCodes[index],
        field: 'burnerResolutionEvidence.$key.actionCodes[$index]',
        source: source,
      );
      if (codes.contains(code)) {
        throw PersistedDataFormatException(
          field: 'burnerResolutionEvidence.$key.actionCodes',
          source: source,
          detail: 'action codes must be unique',
        );
      }
      codes.add(code);
    }
    actionCodes[position] = codes;
    if (evidence.containsKey('microampReading')) {
      final rawReading = evidence['microampReading'];
      if (rawReading is! num) {
        throw PersistedDataFormatException(
          field: 'burnerResolutionEvidence.$key.microampReading',
          source: source,
          detail: 'expected a numeric microamp reading',
        );
      }
      final reading = rawReading.toDouble();
      try {
        _validateMicroampReading(reading, position: position);
      } on FormatException catch (error) {
        throw PersistedDataFormatException(
          field: 'burnerResolutionEvidence.$key.microampReading',
          source: source,
          detail: error.message,
        );
      }
      microampReadings[position] = reading;
    }
  }
  return (
    outcomes: outcomes,
    actionCodes: actionCodes,
    microampReadings: microampReadings,
  );
}

List<int> _validatedPositions(
  Iterable<int> values, {
  required String field,
  bool allowEmpty = false,
}) {
  final source = values.toList(growable: false);
  final result = source.toSet().toList()..sort();
  if ((!allowEmpty && result.isEmpty) ||
      source.length != result.length ||
      result.length > 8 ||
      result.any((value) => value < 1 || value > 8)) {
    throw FormatException('$field must contain unique positions 1 through 8.');
  }
  return List<int>.unmodifiable(result);
}

bool _isSubset(Iterable<int> candidate, Iterable<int> allowed) {
  final allowedSet = allowed.toSet();
  return candidate.every(allowedSet.contains);
}

bool _samePositions(Iterable<int> left, Iterable<int> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

T? _enumByName<T extends Enum>(Iterable<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

bool _sameOutcomes(
  Map<int, BurnerResolutionOutcome> left,
  Map<int, BurnerResolutionOutcome> right,
) {
  if (!_samePositions(left.keys, right.keys)) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

bool _sameActionCodes(
  Map<int, List<BurnerActionCode>> left,
  Map<int, List<BurnerActionCode>> right,
) {
  if (!_samePositions(left.keys, right.keys)) return false;
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null ||
        entry.value.length != other.length ||
        !entry.value.toSet().containsAll(other)) {
      return false;
    }
  }
  return true;
}

bool _sameMicroampReadings(Map<int, double> left, Map<int, double> right) {
  if (!_samePositions(left.keys, right.keys)) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

double _readActionMicroampReading(dynamic value, {required int position}) {
  if (value is! num) {
    throw StateError(
      'Saved microamp reading for Burner $position is not numeric.',
    );
  }
  final reading = value.toDouble();
  try {
    _validateMicroampReading(reading, position: position);
  } on FormatException catch (error) {
    throw StateError(error.message);
  }
  return reading;
}

void _validateMicroampReading(double value, {required int position}) {
  if (!value.isFinite || value < 0 || value > burnerMicroampStructuralMaximum) {
    throw FormatException(
      'Burner $position microamp reading must be between 0 and '
      '${burnerMicroampStructuralMaximum.toStringAsFixed(0)} uA.',
    );
  }
}

typedef _BurnerActionEvidence =
    ({
      Map<int, BurnerResolutionOutcome> outcomes,
      Map<int, List<BurnerActionCode>> actionCodes,
      Map<int, double> microampReadings,
    });
