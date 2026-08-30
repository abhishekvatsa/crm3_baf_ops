import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const issueLaneSynchronizedFieldNames = <String>{
  'issueLaneSchemaVersion',
  'issueLaneRevision',
  'issueAssignedLanes',
  'issueAcknowledgedLanes',
  'issueCompletedLanes',
};

const issueLaneCompletionEvidenceFieldName = 'issueLaneCompletionEvidence';

const issueRouteKeys = <String>{
  'operations',
  'electrical',
  'mechanical',
  'instrumentation',
  'refractory',
  'emd',
  'shiftInCharge',
  'others',
};

class IssueLaneCompletionEvidence {
  const IssueLaneCompletionEvidence({
    required this.completedAt,
    required this.completedByUid,
    required this.completedByName,
  });

  final DateTime completedAt;
  final String completedByUid;
  final String completedByName;

  factory IssueLaneCompletionEvidence.fromMap(
    dynamic value, {
    required String source,
    required String lane,
  }) {
    if (value is! Map) {
      throw PersistedDataFormatException(
        field: '$issueLaneCompletionEvidenceFieldName.$lane',
        source: source,
        detail: 'expected an object (${value.runtimeType})',
      );
    }
    final map = Map<String, dynamic>.from(value);
    if (map.keys.toSet().difference(const <String>{
          'completedAt',
          'completedByUid',
          'completedByName',
        }).isNotEmpty ||
        map.length != 3) {
      throw PersistedDataFormatException(
        field: '$issueLaneCompletionEvidenceFieldName.$lane',
        source: source,
        detail: 'completion evidence fields are not exact',
      );
    }
    final completedByUid = readRequiredPersistedString(
      map['completedByUid'],
      field: '$issueLaneCompletionEvidenceFieldName.$lane.completedByUid',
      source: source,
    );
    final completedByName = readRequiredPersistedString(
      map['completedByName'],
      field: '$issueLaneCompletionEvidenceFieldName.$lane.completedByName',
      source: source,
    );
    if (completedByUid.length > 160 || completedByName.length > 160) {
      throw PersistedDataFormatException(
        field: '$issueLaneCompletionEvidenceFieldName.$lane',
        source: source,
        detail: 'completion authority exceeds 160 characters',
      );
    }
    return IssueLaneCompletionEvidence(
      completedAt: readRequiredPersistedDateTime(
        map['completedAt'],
        field: '$issueLaneCompletionEvidenceFieldName.$lane.completedAt',
        source: source,
      ),
      completedByUid: completedByUid,
      completedByName: completedByName,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'completedAt': completedAt.toUtc().toIso8601String(),
    'completedByUid': completedByUid,
    'completedByName': completedByName,
  };
}

class IssueLanePlan {
  const IssueLanePlan._({
    required this.revision,
    required this.assignedLanes,
    required this.acknowledgedLanes,
    required this.completedLanes,
    required this.completionEvidence,
  });

  factory IssueLanePlan.initial(Iterable<String> lanes) => IssueLanePlan._read(
    revision: 1,
    assignedLanes: lanes.toList(growable: false),
    acknowledgedLanes: const <String>[],
    completedLanes: const <String>[],
    completionEvidence: const <String, IssueLaneCompletionEvidence>{},
    source: 'new maintenance issue',
  );

  factory IssueLanePlan.legacy({
    required String primaryLane,
    required String status,
  }) {
    final acknowledged =
        status == 'acknowledged' ||
        status == 'inProgress' ||
        status == 'resolved';
    final completed = status == 'resolved';
    return IssueLanePlan._read(
      revision: 1,
      assignedLanes: <String>[primaryLane],
      acknowledgedLanes: acknowledged ? <String>[primaryLane] : const [],
      completedLanes: completed ? <String>[primaryLane] : const [],
      completionEvidence: const <String, IssueLaneCompletionEvidence>{},
      source: 'legacy maintenance issue',
    );
  }

  final int revision;
  final List<String> assignedLanes;
  final List<String> acknowledgedLanes;
  final List<String> completedLanes;
  final Map<String, IssueLaneCompletionEvidence> completionEvidence;

  String get primaryLane => assignedLanes.first;
  bool get isMultiLane => assignedLanes.length > 1;
  bool get isFullyAcknowledged =>
      acknowledgedLanes.toSet().containsAll(assignedLanes);
  bool get isFullyCompleted =>
      completedLanes.toSet().containsAll(assignedLanes);

  List<String> get lanesAwaitingAcknowledgement => List<String>.unmodifiable(
    assignedLanes.where((lane) => !acknowledgedLanes.contains(lane)),
  );

  List<String> get lanesAwaitingCompletion => List<String>.unmodifiable(
    assignedLanes.where((lane) => !completedLanes.contains(lane)),
  );

  IssueLanePlan acknowledge(String lane) {
    _requireAssigned(lane);
    if (acknowledgedLanes.contains(lane)) return this;
    return IssueLanePlan._read(
      revision: revision,
      assignedLanes: assignedLanes,
      acknowledgedLanes: <String>[...acknowledgedLanes, lane],
      completedLanes: completedLanes,
      completionEvidence: completionEvidence,
      source: 'maintenance issue acknowledgement',
    );
  }

  IssueLanePlan complete(String lane, {IssueLaneCompletionEvidence? evidence}) {
    _requireAssigned(lane);
    if (!acknowledgedLanes.contains(lane)) {
      throw StateError(
        'The $lane lane must be acknowledged before completion.',
      );
    }
    if (completedLanes.contains(lane)) return this;
    return IssueLanePlan._read(
      revision: revision,
      assignedLanes: assignedLanes,
      acknowledgedLanes: acknowledgedLanes,
      completedLanes: <String>[...completedLanes, lane],
      completionEvidence: <String, IssueLaneCompletionEvidence>{
        ...completionEvidence,
        if (evidence != null) lane: evidence,
      },
      source: 'maintenance issue lane completion',
    );
  }

  IssueLanePlan completeAll({
    DateTime? completedAt,
    String? completedByUid,
    String? completedByName,
  }) {
    final supplied =
        <Object?>[
          completedAt,
          completedByUid,
          completedByName,
        ].where((value) => value != null).length;
    if (supplied != 0 && supplied != 3) {
      throw StateError(
        'Lane completion time, UID and name must be supplied together.',
      );
    }
    final nextEvidence = <String, IssueLaneCompletionEvidence>{
      ...completionEvidence,
    };
    if (supplied == 3) {
      final evidence = IssueLaneCompletionEvidence(
        completedAt: completedAt!,
        completedByUid: completedByUid!,
        completedByName: completedByName!,
      );
      for (final lane in assignedLanes) {
        if (!completedLanes.contains(lane)) {
          nextEvidence.putIfAbsent(lane, () => evidence);
        }
      }
    }
    return IssueLanePlan._read(
      revision: revision,
      assignedLanes: assignedLanes,
      acknowledgedLanes: assignedLanes,
      completedLanes: assignedLanes,
      completionEvidence: nextEvidence,
      source: 'maintenance issue final closure',
    );
  }

  IssueLanePlan reopen() => IssueLanePlan._read(
    revision: revision,
    assignedLanes: assignedLanes,
    acknowledgedLanes: const <String>[],
    completedLanes: const <String>[],
    completionEvidence: const <String, IssueLaneCompletionEvidence>{},
    source: 'reopened maintenance issue',
  );

  IssueLanePlan reconfigure(Iterable<String> lanes) {
    final next = lanes.toList(growable: false);
    final nextSet = next.toSet();
    return IssueLanePlan._read(
      revision: revision + 1,
      assignedLanes: next,
      acknowledgedLanes: acknowledgedLanes
          .where(nextSet.contains)
          .toList(growable: false),
      completedLanes: completedLanes
          .where(nextSet.contains)
          .toList(growable: false),
      completionEvidence: <String, IssueLaneCompletionEvidence>{
        for (final entry in completionEvidence.entries)
          if (nextSet.contains(entry.key) && completedLanes.contains(entry.key))
            entry.key: entry.value,
      },
      source: 'maintenance issue lane reconfiguration',
    );
  }

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'issueLaneSchemaVersion': 1,
    'issueLaneRevision': revision,
    'issueAssignedLanes': assignedLanes,
    'issueAcknowledgedLanes': acknowledgedLanes,
    'issueCompletedLanes': completedLanes,
    issueLaneCompletionEvidenceFieldName: <String, dynamic>{
      for (final entry in completionEvidence.entries)
        entry.key: entry.value.toMap(),
    },
  };

  Map<String, dynamic> toClientWriteFields() {
    final fields = toSynchronizedFields();
    fields.remove(issueLaneCompletionEvidenceFieldName);
    return fields;
  }

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'schemaVersion': 1,
    'revision': revision,
    'assignedLanes': assignedLanes,
    'acknowledgedLanes': acknowledgedLanes,
    'completedLanes': completedLanes,
    'completionEvidence': <String, dynamic>{
      for (final entry in completionEvidence.entries)
        entry.key: entry.value.toMap(),
    },
  };

  static IssueLanePlan fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        issueLaneSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.length != issueLaneSynchronizedFieldNames.length) {
      throw PersistedDataFormatException(
        field: 'issueLaneSchemaVersion',
        source: source,
        detail: 'issue lane fields must be present together',
      );
    }
    if (map['issueLaneSchemaVersion'] != 1) {
      throw PersistedDataFormatException(
        field: 'issueLaneSchemaVersion',
        source: source,
        detail: 'unsupported schema version',
      );
    }
    return IssueLanePlan._read(
      revision: readRequiredPersistedInt(
        map['issueLaneRevision'],
        field: 'issueLaneRevision',
        source: source,
        minimum: 1,
      ),
      assignedLanes: _readLaneList(
        map['issueAssignedLanes'],
        field: 'issueAssignedLanes',
        source: source,
        allowEmpty: false,
      ),
      acknowledgedLanes: _readLaneList(
        map['issueAcknowledgedLanes'],
        field: 'issueAcknowledgedLanes',
        source: source,
      ),
      completedLanes: _readLaneList(
        map['issueCompletedLanes'],
        field: 'issueCompletedLanes',
        source: source,
      ),
      completionEvidence: _readCompletionEvidence(
        map[issueLaneCompletionEvidenceFieldName],
        source: source,
      ),
      source: source,
    );
  }

  static IssueLanePlan? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        issueLaneSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.isEmpty) {
      if (map.containsKey(issueLaneCompletionEvidenceFieldName)) {
        throw PersistedDataFormatException(
          field: issueLaneCompletionEvidenceFieldName,
          source: source,
          detail: 'completion evidence requires the issue lane field set',
        );
      }
      return null;
    }
    return fromSynchronizedFields(map, source: source);
  }

  static IssueLanePlan? tryDecodeLocal(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final raw = Map<String, dynamic>.from(decoded)['issueLanePlan'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'issueLanePlan',
        source: 'local maintenance metadata',
        detail: 'expected an object',
      );
    }
    final local = Map<String, dynamic>.from(raw);
    return fromSynchronizedFields(<String, dynamic>{
      'issueLaneSchemaVersion': local['schemaVersion'],
      'issueLaneRevision': local['revision'],
      'issueAssignedLanes': local['assignedLanes'],
      'issueAcknowledgedLanes': local['acknowledgedLanes'],
      'issueCompletedLanes': local['completedLanes'],
      issueLaneCompletionEvidenceFieldName: local['completionEvidence'],
    }, source: 'local maintenance metadata');
  }

  static IssueLanePlan _read({
    required int revision,
    required List<String> assignedLanes,
    required List<String> acknowledgedLanes,
    required List<String> completedLanes,
    required Map<String, IssueLaneCompletionEvidence> completionEvidence,
    required String source,
  }) {
    if (revision < 1 ||
        assignedLanes.isEmpty ||
        assignedLanes.length > issueRouteKeys.length ||
        assignedLanes.toSet().length != assignedLanes.length ||
        acknowledgedLanes.toSet().length != acknowledgedLanes.length ||
        completedLanes.toSet().length != completedLanes.length ||
        !assignedLanes.every(issueRouteKeys.contains) ||
        !assignedLanes.toSet().containsAll(acknowledgedLanes) ||
        !acknowledgedLanes.toSet().containsAll(completedLanes) ||
        !completedLanes.toSet().containsAll(completionEvidence.keys)) {
      throw PersistedDataFormatException(
        field: 'issueAssignedLanes',
        source: source,
        detail: 'lane membership, ordering, or lifecycle is invalid',
      );
    }
    return IssueLanePlan._(
      revision: revision,
      assignedLanes: List<String>.unmodifiable(assignedLanes),
      acknowledgedLanes: List<String>.unmodifiable(acknowledgedLanes),
      completedLanes: List<String>.unmodifiable(completedLanes),
      completionEvidence: Map<String, IssueLaneCompletionEvidence>.unmodifiable(
        completionEvidence,
      ),
    );
  }

  void _requireAssigned(String lane) {
    if (!assignedLanes.contains(lane)) {
      throw StateError('The $lane lane is not assigned to this issue.');
    }
  }
}

class IssueLanePlanReadResult {
  const IssueLanePlanReadResult({required this.value, this.error});

  final IssueLanePlan? value;
  final FormatException? error;

  bool get isValid => error == null;
}

String mergeIssueLanePlanIntoMaintenanceMetadata(
  String? existing,
  IssueLanePlan value,
) {
  final root = _readMetadataRoot(existing);
  root['issueLanePlan'] = value.toLocalMap();
  return jsonEncode(root);
}

Map<String, IssueLaneCompletionEvidence> _readCompletionEvidence(
  dynamic value, {
  required String source,
}) {
  if (value == null) return <String, IssueLaneCompletionEvidence>{};
  if (value is! Map) {
    throw PersistedDataFormatException(
      field: issueLaneCompletionEvidenceFieldName,
      source: source,
      detail: 'expected an object (${value.runtimeType})',
    );
  }
  final map = Map<String, dynamic>.from(value);
  if (map.length > issueRouteKeys.length ||
      map.keys.any((lane) => !issueRouteKeys.contains(lane))) {
    throw PersistedDataFormatException(
      field: issueLaneCompletionEvidenceFieldName,
      source: source,
      detail: 'contains an unsupported lane or too many entries',
    );
  }
  return <String, IssueLaneCompletionEvidence>{
    for (final entry in map.entries)
      entry.key: IssueLaneCompletionEvidence.fromMap(
        entry.value,
        source: source,
        lane: entry.key,
      ),
  };
}

List<String> _readLaneList(
  dynamic value, {
  required String field,
  required String source,
  bool allowEmpty = true,
}) {
  if (value == null) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an array (Null)',
    );
  }
  final lanes = readOptionalPersistedStringList(
    value,
    field: field,
    source: source,
  );
  if ((!allowEmpty && lanes.isEmpty) ||
      lanes.any((lane) => !issueRouteKeys.contains(lane))) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'contains no lane or an unsupported lane',
    );
  }
  return lanes;
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
