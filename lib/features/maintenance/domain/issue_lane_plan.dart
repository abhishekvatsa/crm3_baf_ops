import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const issueLaneSynchronizedFieldNames = <String>{
  'issueLaneSchemaVersion',
  'issueLaneRevision',
  'issueAssignedLanes',
  'issueAcknowledgedLanes',
  'issueCompletedLanes',
};

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

class IssueLanePlan {
  const IssueLanePlan._({
    required this.revision,
    required this.assignedLanes,
    required this.acknowledgedLanes,
    required this.completedLanes,
  });

  factory IssueLanePlan.initial(Iterable<String> lanes) => IssueLanePlan._read(
    revision: 1,
    assignedLanes: lanes.toList(growable: false),
    acknowledgedLanes: const <String>[],
    completedLanes: const <String>[],
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
      source: 'legacy maintenance issue',
    );
  }

  final int revision;
  final List<String> assignedLanes;
  final List<String> acknowledgedLanes;
  final List<String> completedLanes;

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
      source: 'maintenance issue acknowledgement',
    );
  }

  IssueLanePlan complete(String lane) {
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
      source: 'maintenance issue lane completion',
    );
  }

  IssueLanePlan completeAll() => IssueLanePlan._read(
    revision: revision,
    assignedLanes: assignedLanes,
    acknowledgedLanes: assignedLanes,
    completedLanes: assignedLanes,
    source: 'maintenance issue final closure',
  );

  IssueLanePlan reopen() => IssueLanePlan._read(
    revision: revision,
    assignedLanes: assignedLanes,
    acknowledgedLanes: const <String>[],
    completedLanes: const <String>[],
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
      source: 'maintenance issue lane reconfiguration',
    );
  }

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'issueLaneSchemaVersion': 1,
    'issueLaneRevision': revision,
    'issueAssignedLanes': assignedLanes,
    'issueAcknowledgedLanes': acknowledgedLanes,
    'issueCompletedLanes': completedLanes,
  };

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'schemaVersion': 1,
    'revision': revision,
    'assignedLanes': assignedLanes,
    'acknowledgedLanes': acknowledgedLanes,
    'completedLanes': completedLanes,
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
      source: source,
    );
  }

  static IssueLanePlan? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        issueLaneSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.isEmpty) return null;
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
    }, source: 'local maintenance metadata');
  }

  static IssueLanePlan _read({
    required int revision,
    required List<String> assignedLanes,
    required List<String> acknowledgedLanes,
    required List<String> completedLanes,
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
        !acknowledgedLanes.toSet().containsAll(completedLanes)) {
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
