import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../planned_maintenance/models/component_action_model.dart';

const burnerLockoutClassification = 'furnaceBurnerLockout';
const burnerLockoutSchemaVersion = 1;

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
  'burnerResolutionOutcomes',
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
  BurnerLockoutResolution({required Map<int, BurnerResolutionOutcome> outcomes})
    : outcomes = Map<int, BurnerResolutionOutcome>.unmodifiable(outcomes);

  final Map<int, BurnerResolutionOutcome> outcomes;

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

  bool get hasRedHotObservation => redHotPositions.isNotEmpty;

  bool get isResolutionComplete =>
      _samePositions(attendedPositions, positions) &&
      _samePositions(resolutionOutcomes.keys, positions);

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
    'burnerResolutionOutcomes': <String>[
      for (final position in attendedPositions)
        resolutionOutcomes[position]!.name,
    ],
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
    'resolutionOutcomes': <String>[
      for (final position in attendedPositions)
        resolutionOutcomes[position]!.name,
    ],
  };

  BurnerLockoutCase withResolution(BurnerLockoutResolution resolution) =>
      BurnerLockoutCase(
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
      );

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
      resolutionOutcomes: _readOutcomes(
        map['burnerResolutionOutcomes'],
        positions: attendedPositions,
        source: source,
      ),
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
      'burnerResolutionOutcomes': local['resolutionOutcomes'],
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
        !_isSubset(resolutionOutcomes.keys, positions)) {
      throw const FormatException(
        'Attendance and outcomes must belong to selected burner positions.',
      );
    }
    if (!_samePositions(attendedPositions, resolutionOutcomes.keys)) {
      throw const FormatException(
        'Every attended burner must have one terminal outcome.',
      );
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
  String? remarks,
}) => ComponentAction(
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
  extensions: <String, dynamic>{
    'attendanceSessionId': burnerActionSessionId(ticketId, burnerPosition),
    'burnerPosition': burnerPosition,
    'burnerActionCode': code.name,
    'burnerOutcome': outcome.name,
  },
);

void validateBurnerResolutionEvidence({
  required BurnerLockoutCase lockout,
  required BurnerLockoutResolution resolution,
  required Iterable<ComponentAction> actions,
}) {
  if (!_samePositions(resolution.outcomes.keys, lockout.positions)) {
    throw StateError('Record one terminal outcome for every affected burner.');
  }
  for (final position in lockout.positions) {
    final burnerActions = actions.where(
      (action) => action.extensions['burnerPosition'] == position,
    );
    if (burnerActions.isEmpty) {
      throw StateError(
        'Record work or inspection evidence for Burner $position.',
      );
    }
    final outcome = resolution.outcomes[position];
    if (outcome == BurnerResolutionOutcome.returnedToService) {
      final codes = burnerActions
          .map((action) => action.extensions['burnerActionCode'])
          .whereType<String>()
          .map(
            (name) =>
                BurnerActionCode.values.where((item) => item.name == name),
          )
          .where((matches) => matches.isNotEmpty)
          .map((matches) => matches.first)
          .toList(growable: false);
      if (codes.isEmpty || codes.every((code) => code.isResetOnly)) {
        throw StateError(
          'Burner $position cannot be returned to service on reset-only evidence.',
        );
      }
    }
  }
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

Map<int, BurnerResolutionOutcome> _readOutcomes(
  dynamic value, {
  required List<int> positions,
  required String source,
}) {
  if (value is! List) {
    throw PersistedDataFormatException(
      field: 'burnerResolutionOutcomes',
      source: source,
      detail: 'expected an outcome array (${value.runtimeType})',
    );
  }
  if (value.length != positions.length) {
    throw PersistedDataFormatException(
      field: 'burnerResolutionOutcomes',
      source: source,
      detail: 'outcomes must align with attended burner positions',
    );
  }
  final outcomes = <int, BurnerResolutionOutcome>{};
  for (var index = 0; index < value.length; index++) {
    outcomes[positions[index]] = readRequiredPersistedEnum(
      BurnerResolutionOutcome.values,
      value[index],
      field: 'burnerResolutionOutcomes[$index]',
      source: source,
    );
  }
  return outcomes;
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
