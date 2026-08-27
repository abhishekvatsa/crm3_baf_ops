import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const burnerConditionRoundSchemaVersion = 2;
const burnerConditionRoundOperation = 'RECORD_BURNER_CONDITION_ROUND';
const maximumBurnerMicroampReading = 1000000.0;

enum BurnerRoundFlameObservation { seen, notSeen, notOperating, notChecked }

enum BurnerUvCondition { serviceable, melted, missing, hanging }

enum BurnerDirectiveComplianceDisposition {
  restoredInService,
  uvMelted,
  uvMissing,
  uvHungRemoved,
}

extension BurnerDirectiveComplianceDispositionLabel
    on BurnerDirectiveComplianceDisposition {
  String get label => switch (this) {
    BurnerDirectiveComplianceDisposition.restoredInService =>
      'Block corrected; UV in service',
    BurnerDirectiveComplianceDisposition.uvMelted => 'UV melted',
    BurnerDirectiveComplianceDisposition.uvMissing => 'UV missing',
    BurnerDirectiveComplianceDisposition.uvHungRemoved => 'UV hung / removed',
  };

  BurnerUvCondition get uvCondition => switch (this) {
    BurnerDirectiveComplianceDisposition.restoredInService =>
      BurnerUvCondition.serviceable,
    BurnerDirectiveComplianceDisposition.uvMelted => BurnerUvCondition.melted,
    BurnerDirectiveComplianceDisposition.uvMissing => BurnerUvCondition.missing,
    BurnerDirectiveComplianceDisposition.uvHungRemoved =>
      BurnerUvCondition.hanging,
  };
}

extension BurnerUvConditionLabel on BurnerUvCondition {
  String get label => switch (this) {
    BurnerUvCondition.serviceable => 'In service',
    BurnerUvCondition.melted => 'Melted',
    BurnerUvCondition.missing => 'Missing',
    BurnerUvCondition.hanging => 'Hung / removed',
  };
}

extension BurnerRoundFlameObservationLabel on BurnerRoundFlameObservation {
  String get label => switch (this) {
    BurnerRoundFlameObservation.seen => 'Flame seen',
    BurnerRoundFlameObservation.notSeen => 'Flame not seen',
    BurnerRoundFlameObservation.notOperating => 'Burner not operating',
    BurnerRoundFlameObservation.notChecked => 'Not checked',
  };
}

class BurnerConditionObservation {
  const BurnerConditionObservation({
    required this.position,
    required this.flameObservation,
    required this.redHotObserved,
    this.microampReading,
    this.remarks,
  });

  final int position;
  final BurnerRoundFlameObservation flameObservation;
  final bool redHotObserved;
  final double? microampReading;
  final String? remarks;

  Map<String, dynamic> toCommandMap() => <String, dynamic>{
    'position': position,
    'flameObservation': flameObservation.name,
    'redHotObserved': redHotObserved,
    'microampReading': microampReading,
    'remarks': _cleanOptionalText(remarks),
  };

  factory BurnerConditionObservation.fromMap(
    Map<String, dynamic> map, {
    required String source,
    required int expectedPosition,
  }) {
    _requireExactKeys(map, const <String>{
      'position',
      'flameObservation',
      'redHotObserved',
      'microampReading',
      'remarks',
    }, source);
    final position = readRequiredPersistedInt(
      map['position'],
      field: 'position',
      source: source,
      minimum: 1,
    );
    final flameObservation = readRequiredPersistedEnum(
      BurnerRoundFlameObservation.values,
      map['flameObservation'],
      field: 'flameObservation',
      source: source,
    );
    final redHotObserved = readRequiredPersistedBool(
      map['redHotObserved'],
      field: 'redHotObserved',
      source: source,
    );
    final microampReading = readOptionalPersistedDouble(
      map['microampReading'],
      field: 'microampReading',
      source: source,
    );
    final remarks = readOptionalPersistedString(
      map['remarks'],
      field: 'remarks',
      source: source,
    );
    if (position != expectedPosition || position > 8) {
      throw PersistedDataFormatException(
        field: 'position',
        source: source,
        detail: 'must contain each position from 1 to 8 in order',
      );
    }
    if (microampReading != null &&
        (microampReading < 0 ||
            microampReading > maximumBurnerMicroampReading)) {
      throw PersistedDataFormatException(
        field: 'microampReading',
        source: source,
        detail: 'outside the structural range',
      );
    }
    if ((flameObservation == BurnerRoundFlameObservation.notChecked ||
            flameObservation == BurnerRoundFlameObservation.notOperating) &&
        microampReading != null) {
      throw PersistedDataFormatException(
        field: 'microampReading',
        source: source,
        detail: 'cannot accompany an unobserved flame signal',
      );
    }
    if (flameObservation == BurnerRoundFlameObservation.notChecked &&
        remarks == null) {
      throw PersistedDataFormatException(
        field: 'remarks',
        source: source,
        detail: 'must explain why the burner was not checked',
      );
    }
    return BurnerConditionObservation(
      position: position,
      flameObservation: flameObservation,
      redHotObserved: redHotObserved,
      microampReading: microampReading,
      remarks: remarks,
    );
  }
}

class BurnerUvObservation {
  const BurnerUvObservation({
    required this.position,
    required this.condition,
    this.remarks,
  });

  final int position;
  final BurnerUvCondition condition;
  final String? remarks;

  Map<String, dynamic> toCommandMap() => <String, dynamic>{
    'position': position,
    'condition': condition.name,
    'remarks': _cleanOptionalText(remarks),
  };

  factory BurnerUvObservation.fromMap(
    Map<String, dynamic> map, {
    required String source,
    required int expectedPosition,
  }) {
    _requireExactKeys(map, const <String>{
      'position',
      'condition',
      'remarks',
    }, source);
    final position = readRequiredPersistedInt(
      map['position'],
      field: 'position',
      source: source,
      minimum: 1,
    );
    if (position != expectedPosition || position > 8) {
      throw PersistedDataFormatException(
        field: 'position',
        source: source,
        detail: 'must contain each UV position from 1 to 8 in order',
      );
    }
    return BurnerUvObservation(
      position: position,
      condition: readRequiredPersistedEnum(
        BurnerUvCondition.values,
        map['condition'],
        field: 'condition',
        source: source,
      ),
      remarks: readOptionalPersistedString(
        map['remarks'],
        field: 'remarks',
        source: source,
      ),
    );
  }
}

class BurnerRedHotDirectiveBinding {
  const BurnerRedHotDirectiveBinding({
    required this.sourceRoundId,
    required this.burnerPositions,
  });

  final String sourceRoundId;
  final List<int> burnerPositions;

  static BurnerRedHotDirectiveBinding? tryDecode(String? metadataJson) {
    final cleaned = metadataJson?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    if (map['trigger'] != 'burnerConditionRoundRedHot') return null;
    const expectedKeys = <String>{
      'schemaVersion',
      'trigger',
      'sourceRoundId',
      'burnerPositions',
      'automaticPlantActuation',
    };
    if (map.keys.toSet().length != expectedKeys.length ||
        !map.keys.toSet().containsAll(expectedKeys) ||
        map['schemaVersion'] != 1 ||
        map['automaticPlantActuation'] != false) {
      throw const FormatException(
        'The burner directive source binding is malformed.',
      );
    }
    final sourceRoundId = map['sourceRoundId'];
    final rawPositions = map['burnerPositions'];
    if (sourceRoundId is! String ||
        sourceRoundId.trim().isEmpty ||
        rawPositions is! List ||
        rawPositions.isEmpty) {
      throw const FormatException(
        'The burner directive source binding is incomplete.',
      );
    }
    final positions = <int>[];
    for (final value in rawPositions) {
      if (value is! int ||
          value < 1 ||
          value > 8 ||
          positions.contains(value)) {
        throw const FormatException(
          'The burner directive positions are invalid.',
        );
      }
      positions.add(value);
    }
    final sorted = positions.toList()..sort();
    if (!_sameInts(positions, sorted)) {
      throw const FormatException(
        'The burner directive positions are not canonical.',
      );
    }
    return BurnerRedHotDirectiveBinding(
      sourceRoundId: sourceRoundId.trim(),
      burnerPositions: List<int>.unmodifiable(positions),
    );
  }
}

class BurnerDirectiveComplianceProjection {
  const BurnerDirectiveComplianceProjection({
    required this.observations,
    required this.uvObservations,
    required this.changed,
  });

  final List<BurnerConditionObservation> observations;
  final List<BurnerUvObservation> uvObservations;
  final bool changed;
}

BurnerDirectiveComplianceProjection projectBurnerDirectiveCompliance({
  required BurnerConditionRound current,
  required BurnerRedHotDirectiveBinding binding,
  required Map<int, BurnerDirectiveComplianceDisposition> dispositions,
}) {
  if (dispositions.keys.toSet().length != binding.burnerPositions.length ||
      !dispositions.keys.toSet().containsAll(binding.burnerPositions)) {
    throw const FormatException(
      'Record one compliance outcome for every directed burner position.',
    );
  }
  final currentUv = <int, BurnerUvCondition>{
    for (var position = 1; position <= 8; position++)
      position: BurnerUvCondition.serviceable,
    for (final observation in current.uvObservations)
      observation.position: observation.condition,
  };
  var changed = false;
  final observations = <BurnerConditionObservation>[];
  final uvObservations = <BurnerUvObservation>[];
  for (var position = 1; position <= 8; position++) {
    final before = current.observations[position - 1];
    final disposition = dispositions[position];
    final uvCondition = disposition?.uvCondition ?? currentUv[position]!;
    final restored =
        disposition == BurnerDirectiveComplianceDisposition.restoredInService;
    final abnormalUv = disposition != null && !restored;
    final redHotObserved = restored ? false : before.redHotObserved;
    final flameObservation =
        abnormalUv
            ? BurnerRoundFlameObservation.notOperating
            : before.flameObservation;
    final microampReading = abnormalUv ? null : before.microampReading;
    final remarks =
        disposition == null
            ? before.remarks
            : 'Directive compliance: ${disposition.label}.';
    if (redHotObserved != before.redHotObserved ||
        flameObservation != before.flameObservation ||
        microampReading != before.microampReading ||
        uvCondition != currentUv[position]) {
      changed = true;
    }
    observations.add(
      BurnerConditionObservation(
        position: position,
        flameObservation: flameObservation,
        redHotObserved: redHotObserved,
        microampReading: microampReading,
        remarks: remarks,
      ),
    );
    uvObservations.add(
      BurnerUvObservation(position: position, condition: uvCondition),
    );
  }
  return BurnerDirectiveComplianceProjection(
    observations: List<BurnerConditionObservation>.unmodifiable(observations),
    uvObservations: List<BurnerUvObservation>.unmodifiable(uvObservations),
    changed: changed,
  );
}

class BurnerConditionCurrentPointer {
  const BurnerConditionCurrentPointer({
    required this.assetInstanceId,
    required this.roundId,
    required this.observedAt,
    required this.updatedAt,
  });

  final String assetInstanceId;
  final String roundId;
  final DateTime observedAt;
  final DateTime updatedAt;

  factory BurnerConditionCurrentPointer.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'burner_condition_current/$documentId';
    _requireExactKeys(map, const <String>{
      'schemaVersion',
      'assetInstanceId',
      'roundId',
      'observedAt',
      'updatedAt',
    }, source);
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    final assetInstanceId = readRequiredPersistedString(
      map['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
    );
    final observedAt = readRequiredPersistedDateTime(
      map['observedAt'],
      field: 'observedAt',
      source: source,
    );
    final updatedAt = readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    if (schemaVersion != 1 ||
        assetInstanceId != documentId ||
        updatedAt.isBefore(observedAt)) {
      throw PersistedDataFormatException(
        field: 'assetInstanceId',
        source: source,
        detail: 'schema, identity, or timestamp ordering mismatch',
      );
    }
    return BurnerConditionCurrentPointer(
      assetInstanceId: assetInstanceId,
      roundId: readRequiredPersistedString(
        map['roundId'],
        field: 'roundId',
        source: source,
      ),
      observedAt: observedAt,
      updatedAt: updatedAt,
    );
  }

  BurnerConditionRound requireMatchingRound(BurnerConditionRound round) {
    if (round.roundId != roundId ||
        round.assetInstanceId != assetInstanceId ||
        !round.observedAt.isAtSameMomentAs(observedAt)) {
      throw PersistedDataFormatException(
        field: 'roundId',
        source: 'burner_condition_current/$assetInstanceId',
        detail: 'referenced round identity or observation time mismatch',
      );
    }
    return round;
  }
}

class BurnerConditionRound {
  const BurnerConditionRound({
    required this.roundId,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetInstanceVersion,
    required this.assetNumber,
    required this.assetName,
    required this.observations,
    required this.redHotPositions,
    required this.microampPositions,
    this.draftSealRedHotObserved = false,
    this.hotAirAtDraftSealObserved = false,
    this.uvObservations = const <BurnerUvObservation>[],
    this.directivePositions = const <int>[],
    required this.observedAt,
    required this.recordedByUid,
    required this.recordedByName,
    required this.fingerprint,
    this.roundNote,
    this.directiveId,
  });

  final String roundId;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final String assetInstanceId;
  final int assetInstanceVersion;
  final int assetNumber;
  final String assetName;
  final List<BurnerConditionObservation> observations;
  final List<int> redHotPositions;
  final List<int> microampPositions;
  final bool draftSealRedHotObserved;
  final bool hotAirAtDraftSealObserved;
  final List<BurnerUvObservation> uvObservations;
  final List<int> directivePositions;
  final String? roundNote;
  final DateTime observedAt;
  final String recordedByUid;
  final String recordedByName;
  final String? directiveId;
  final String fingerprint;

  factory BurnerConditionRound.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'burner_condition_rounds/$documentId';
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    final expectedKeys = <String>{
      'schemaVersion',
      'roundId',
      'operation',
      'assetClassId',
      'assetClassCode',
      'assetClassName',
      'assetInstanceId',
      'assetInstanceVersion',
      'assetNumber',
      'assetName',
      'observations',
      'redHotPositions',
      'microampPositions',
      'roundNote',
      'observedAt',
      'recordedByUid',
      'recordedByName',
      'directiveId',
      'fingerprint',
      if (schemaVersion == 2) ...<String>{
        'draftSealRedHotObserved',
        'hotAirAtDraftSealObserved',
        'uvObservations',
        'directivePositions',
      },
    };
    _requireExactKeys(map, expectedKeys, source);
    final roundId = readRequiredPersistedString(
      map['roundId'],
      field: 'roundId',
      source: source,
    );
    final operation = readRequiredPersistedString(
      map['operation'],
      field: 'operation',
      source: source,
    );
    if ((schemaVersion != 1 &&
            schemaVersion != burnerConditionRoundSchemaVersion) ||
        roundId != documentId ||
        operation != burnerConditionRoundOperation) {
      throw PersistedDataFormatException(
        field: 'roundId',
        source: source,
        detail: 'schema, identity, or operation mismatch',
      );
    }
    final rawObservations = map['observations'];
    if (rawObservations is! List || rawObservations.length != 8) {
      throw PersistedDataFormatException(
        field: 'observations',
        source: source,
        detail: 'must contain exactly eight entries',
      );
    }
    final observations = <BurnerConditionObservation>[];
    for (var index = 0; index < rawObservations.length; index++) {
      final raw = rawObservations[index];
      if (raw is! Map) {
        throw PersistedDataFormatException(
          field: 'observations[$index]',
          source: source,
          detail: 'must be an object',
        );
      }
      observations.add(
        BurnerConditionObservation.fromMap(
          Map<String, dynamic>.from(raw),
          source: '$source/observations[$index]',
          expectedPosition: index + 1,
        ),
      );
    }
    final redHotPositions = _requiredPositionList(
      map['redHotPositions'],
      field: 'redHotPositions',
      source: source,
    );
    final microampPositions = _requiredPositionList(
      map['microampPositions'],
      field: 'microampPositions',
      source: source,
    );
    final derivedRedHot = observations
        .where((item) => item.redHotObserved)
        .map((item) => item.position)
        .toList(growable: false);
    final derivedReadings = observations
        .where((item) => item.microampReading != null)
        .map((item) => item.position)
        .toList(growable: false);
    final directiveId = readOptionalPersistedString(
      map['directiveId'],
      field: 'directiveId',
      source: source,
    );
    final List<BurnerUvObservation> uvObservations;
    final bool draftSealRedHotObserved;
    final bool hotAirAtDraftSealObserved;
    final List<int> directivePositions;
    if (schemaVersion == 1) {
      uvObservations = const <BurnerUvObservation>[];
      draftSealRedHotObserved = false;
      hotAirAtDraftSealObserved = false;
      directivePositions = redHotPositions;
    } else {
      draftSealRedHotObserved = readRequiredPersistedBool(
        map['draftSealRedHotObserved'],
        field: 'draftSealRedHotObserved',
        source: source,
      );
      hotAirAtDraftSealObserved = readRequiredPersistedBool(
        map['hotAirAtDraftSealObserved'],
        field: 'hotAirAtDraftSealObserved',
        source: source,
      );
      final rawUv = map['uvObservations'];
      if (rawUv is! List || rawUv.length != 8) {
        throw PersistedDataFormatException(
          field: 'uvObservations',
          source: source,
          detail: 'must contain exactly eight UV conditions',
        );
      }
      uvObservations = <BurnerUvObservation>[
        for (var index = 0; index < rawUv.length; index++)
          if (rawUv[index] case final Map value)
            BurnerUvObservation.fromMap(
              Map<String, dynamic>.from(value),
              source: '$source/uvObservations[$index]',
              expectedPosition: index + 1,
            )
          else
            throw PersistedDataFormatException(
              field: 'uvObservations[$index]',
              source: source,
              detail: 'must be an object',
            ),
      ];
      directivePositions = _requiredPositionList(
        map['directivePositions'],
        field: 'directivePositions',
        source: source,
      );
      final derivedDirectivePositions = observations
          .where((item) => item.redHotObserved)
          .where(
            (item) =>
                uvObservations[item.position - 1].condition ==
                BurnerUvCondition.serviceable,
          )
          .map((item) => item.position)
          .toList(growable: false);
      if (!_sameInts(directivePositions, derivedDirectivePositions)) {
        throw PersistedDataFormatException(
          field: 'directivePositions',
          source: source,
          detail: 'must match red-hot blocks whose UV remains in service',
        );
      }
    }
    if (!_sameInts(redHotPositions, derivedRedHot) ||
        !_sameInts(microampPositions, derivedReadings) ||
        (directivePositions.isEmpty != (directiveId == null)) ||
        (directiveId != null &&
            directiveId != 'burner_round_red_hot_$roundId')) {
      throw PersistedDataFormatException(
        field: 'redHotPositions',
        source: source,
        detail: 'derived evidence or directive identity mismatch',
      );
    }
    final fingerprint = readRequiredPersistedString(
      map['fingerprint'],
      field: 'fingerprint',
      source: source,
    );
    if (!(fingerprint.startsWith('burnerround1-sha256:') ||
            fingerprint.startsWith('burnerround2-sha256:')) ||
        fingerprint.length != 84) {
      throw PersistedDataFormatException(
        field: 'fingerprint',
        source: source,
        detail: 'must be a versioned SHA-256 fingerprint',
      );
    }
    return BurnerConditionRound(
      roundId: roundId,
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetClassCode: readRequiredPersistedString(
        map['assetClassCode'],
        field: 'assetClassCode',
        source: source,
      ),
      assetClassName: readRequiredPersistedString(
        map['assetClassName'],
        field: 'assetClassName',
        source: source,
      ),
      assetInstanceId: readRequiredPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      assetInstanceVersion: readRequiredPersistedInt(
        map['assetInstanceVersion'],
        field: 'assetInstanceVersion',
        source: source,
        minimum: 1,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetName: readRequiredPersistedString(
        map['assetName'],
        field: 'assetName',
        source: source,
      ),
      observations: List<BurnerConditionObservation>.unmodifiable(observations),
      redHotPositions: List<int>.unmodifiable(redHotPositions),
      microampPositions: List<int>.unmodifiable(microampPositions),
      draftSealRedHotObserved: draftSealRedHotObserved,
      hotAirAtDraftSealObserved: hotAirAtDraftSealObserved,
      uvObservations: List<BurnerUvObservation>.unmodifiable(uvObservations),
      directivePositions: List<int>.unmodifiable(directivePositions),
      roundNote: readOptionalPersistedString(
        map['roundNote'],
        field: 'roundNote',
        source: source,
      ),
      observedAt: readRequiredPersistedDateTime(
        map['observedAt'],
        field: 'observedAt',
        source: source,
      ),
      recordedByUid: readRequiredPersistedString(
        map['recordedByUid'],
        field: 'recordedByUid',
        source: source,
      ),
      recordedByName: readRequiredPersistedString(
        map['recordedByName'],
        field: 'recordedByName',
        source: source,
      ),
      directiveId: directiveId,
      fingerprint: fingerprint,
    );
  }
}

List<int> _requiredPositionList(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be an array',
    );
  }
  final values = <int>[];
  for (var index = 0; index < value.length; index++) {
    final item = readRequiredPersistedInt(
      value[index],
      field: '$field[$index]',
      source: source,
      minimum: 1,
    );
    if (item > 8 || values.contains(item)) {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'must contain unique positions from 1 to 8',
      );
    }
    values.add(item);
  }
  final sorted = values.toList()..sort();
  if (!_sameInts(values, sorted)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be sorted',
    );
  }
  return values;
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _requireExactKeys(
  Map<String, dynamic> map,
  Set<String> expected,
  String source,
) {
  if (map.keys.toSet().length != expected.length ||
      !map.keys.toSet().containsAll(expected)) {
    throw PersistedDataFormatException(
      field: 'documentShape',
      source: source,
      detail: 'missing or unsupported fields',
    );
  }
}

String? _cleanOptionalText(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
