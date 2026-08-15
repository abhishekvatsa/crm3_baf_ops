import '../../../core/serialization/persisted_data_reader.dart';

const burnerConditionRoundSchemaVersion = 1;
const burnerConditionRoundOperation = 'RECORD_BURNER_CONDITION_ROUND';
const maximumBurnerMicroampReading = 1000000.0;

enum BurnerRoundFlameObservation { seen, notSeen, notOperating, notChecked }

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
    _requireExactKeys(map, const <String>{
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
    }, source);
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
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
    if (schemaVersion != burnerConditionRoundSchemaVersion ||
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
    if (!_sameInts(redHotPositions, derivedRedHot) ||
        !_sameInts(microampPositions, derivedReadings) ||
        (redHotPositions.isEmpty != (directiveId == null)) ||
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
    if (!fingerprint.startsWith('burnerround1-sha256:') ||
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
