import '../../../core/serialization/persisted_data_reader.dart';

enum MaintenanceClassStatus { active, retired }

enum MaintenancePlanStatus { proposed, scheduled, ready, released, cancelled }

class MaintenanceResetCounter {
  const MaintenanceResetCounter({
    required this.key,
    required this.label,
    required this.thresholdDays,
  });

  final String key;
  final String label;
  final int? thresholdDays;

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'thresholdDays': thresholdDays,
  };

  factory MaintenanceResetCounter.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final threshold = map['thresholdDays'];
    if (threshold != null &&
        (threshold is! int || threshold < 1 || threshold > 3650)) {
      throw PersistedDataFormatException(
        field: 'thresholdDays',
        source: source,
        detail: 'must be 1-3650 or null',
      );
    }
    return MaintenanceResetCounter(
      key: readRequiredPersistedString(
        map['key'],
        field: 'key',
        source: source,
      ),
      label: readRequiredPersistedString(
        map['label'],
        field: 'label',
        source: source,
      ),
      thresholdDays: threshold as int?,
    );
  }
}

class FrozenMaintenanceClass {
  const FrozenMaintenanceClass({
    required this.definitionId,
    required this.definitionVersion,
    required this.code,
    required this.title,
    required this.assetTypeKeys,
    required this.assetClassIds,
    required this.principalLaneKey,
    required this.resetCounters,
  });

  final String definitionId;
  final int definitionVersion;
  final String code;
  final String title;
  final List<String> assetTypeKeys;
  final List<String> assetClassIds;
  final String principalLaneKey;
  final List<MaintenanceResetCounter> resetCounters;

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'definitionId': definitionId,
    'definitionVersion': definitionVersion,
    'code': code,
    'title': title,
    'assetTypeKeys': assetTypeKeys,
    'assetClassIds': assetClassIds,
    'resetCounters': resetCounters.map((counter) => counter.toMap()).toList(),
    'principalLaneKey': principalLaneKey,
  };

  factory FrozenMaintenanceClass.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    if (readRequiredPersistedInt(
          map['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported maintenance-class snapshot',
      );
    }
    final rawCounters = map['resetCounters'];
    if (rawCounters is! List || rawCounters.isEmpty) {
      throw PersistedDataFormatException(
        field: 'resetCounters',
        source: source,
        detail: 'at least one reset counter is required',
      );
    }
    return FrozenMaintenanceClass(
      definitionId: readRequiredPersistedString(
        map['definitionId'],
        field: 'definitionId',
        source: source,
      ),
      definitionVersion: readRequiredPersistedInt(
        map['definitionVersion'],
        field: 'definitionVersion',
        source: source,
        minimum: 1,
      ),
      code: readRequiredPersistedString(
        map['code'],
        field: 'code',
        source: source,
      ),
      title: readRequiredPersistedString(
        map['title'],
        field: 'title',
        source: source,
      ),
      assetTypeKeys: List.unmodifiable(
        readOptionalPersistedStringList(
          map['assetTypeKeys'],
          field: 'assetTypeKeys',
          source: source,
        ),
      ),
      assetClassIds: List.unmodifiable(
        readOptionalPersistedStringList(
          map['assetClassIds'],
          field: 'assetClassIds',
          source: source,
        ),
      ),
      principalLaneKey: readRequiredPersistedString(
        map['principalLaneKey'],
        field: 'principalLaneKey',
        source: source,
      ),
      resetCounters: List.unmodifiable(
        rawCounters.indexed.map(
          (entry) => MaintenanceResetCounter.fromMap(
            Map<String, dynamic>.from(entry.$2 as Map),
            source: '$source/resetCounters/${entry.$1}',
          ),
        ),
      ),
    );
  }
}

class MaintenanceClassDefinition {
  const MaintenanceClassDefinition({
    required this.id,
    required this.version,
    required this.status,
    required this.code,
    required this.title,
    required this.description,
    required this.assetTypeKeys,
    required this.assetClassIds,
    required this.principalLaneKey,
    required this.resetCounters,
    required this.updatedAt,
  });

  final String id;
  final int version;
  final MaintenanceClassStatus status;
  final String code;
  final String title;
  final String description;
  final List<String> assetTypeKeys;
  final List<String> assetClassIds;
  final String principalLaneKey;
  final List<MaintenanceResetCounter> resetCounters;
  final DateTime updatedAt;

  bool get isActive => status == MaintenanceClassStatus.active;

  FrozenMaintenanceClass get frozen => FrozenMaintenanceClass(
    definitionId: id,
    definitionVersion: version,
    code: code,
    title: title,
    assetTypeKeys: assetTypeKeys,
    assetClassIds: assetClassIds,
    principalLaneKey: principalLaneKey,
    resetCounters: resetCounters,
  );

  bool appliesTo({required String assetTypeKey, String? assetClassId}) =>
      isActive &&
      (assetTypeKeys.contains(assetTypeKey) ||
          (assetClassId != null && assetClassIds.contains(assetClassId)));

  factory MaintenanceClassDefinition.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'maintenance_class_definitions/$documentId';
    final id = readRequiredPersistedString(
      map['definitionId'],
      field: 'definitionId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'definitionId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final frozen = FrozenMaintenanceClass.fromMap({
      'schemaVersion': map['schemaVersion'],
      'definitionId': id,
      'definitionVersion': map['version'],
      'code': map['code'],
      'title': map['title'],
      'assetTypeKeys': map['assetTypeKeys'],
      'assetClassIds': map['assetClassIds'],
      'principalLaneKey': map['principalLaneKey'],
      'resetCounters': map['resetCounters'],
    }, source: source);
    return MaintenanceClassDefinition(
      id: id,
      version: frozen.definitionVersion,
      status: readRequiredPersistedEnum(
        MaintenanceClassStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      code: frozen.code,
      title: frozen.title,
      description: readRequiredPersistedString(
        map['description'],
        field: 'description',
        source: source,
      ),
      assetTypeKeys: frozen.assetTypeKeys,
      assetClassIds: frozen.assetClassIds,
      principalLaneKey: frozen.principalLaneKey,
      resetCounters: frozen.resetCounters,
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
    );
  }
}

class MaintenanceDueState {
  const MaintenanceDueState({
    required this.id,
    required this.assetIdentityKey,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.assetClassId,
    required this.assetInstanceId,
    required this.counterKey,
    required this.counterLabel,
    required this.thresholdDays,
    required this.lastCompletionAt,
    required this.nextDueAt,
    required this.lastMaintenanceClassCode,
  });

  final String id;
  final String assetIdentityKey;
  final String assetTypeKey;
  final int assetNumber;
  final String? assetClassId;
  final String? assetInstanceId;
  final String counterKey;
  final String counterLabel;
  final int? thresholdDays;
  final DateTime? lastCompletionAt;
  final DateTime? nextDueAt;
  final String? lastMaintenanceClassCode;

  int? get daysSinceCompletion =>
      lastCompletionAt == null
          ? null
          : DateTime.now().difference(lastCompletionAt!).inDays;
  int? get daysUntilDue => nextDueAt?.difference(DateTime.now()).inDays;
  bool get isOverdue =>
      nextDueAt != null && nextDueAt!.isBefore(DateTime.now());
  bool get isDueSoon =>
      !isOverdue && daysUntilDue != null && daysUntilDue! <= 7;

  factory MaintenanceDueState.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'maintenance_due_states/$documentId';
    return MaintenanceDueState(
      id: documentId,
      assetIdentityKey: readRequiredPersistedString(
        map['assetIdentityKey'],
        field: 'assetIdentityKey',
        source: source,
      ),
      assetTypeKey: readRequiredPersistedString(
        map['assetTypeKey'],
        field: 'assetTypeKey',
        source: source,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetClassId: readOptionalPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetInstanceId: readOptionalPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      counterKey: readRequiredPersistedString(
        map['counterKey'],
        field: 'counterKey',
        source: source,
      ),
      counterLabel: readRequiredPersistedString(
        map['counterLabel'],
        field: 'counterLabel',
        source: source,
      ),
      thresholdDays: map['thresholdDays'] as int?,
      lastCompletionAt: readOptionalPersistedDateTime(
        map['lastCompletionAt'],
        field: 'lastCompletionAt',
        source: source,
      ),
      nextDueAt: readOptionalPersistedDateTime(
        map['nextDueAt'],
        field: 'nextDueAt',
        source: source,
      ),
      lastMaintenanceClassCode: readOptionalPersistedString(
        map['lastMaintenanceClassCode'],
        field: 'lastMaintenanceClassCode',
        source: source,
      ),
    );
  }
}

class MaintenancePlan {
  const MaintenancePlan({
    required this.id,
    required this.version,
    required this.status,
    required this.assetIdentityKey,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.assetClassId,
    required this.assetInstanceId,
    required this.maintenanceClass,
    required this.targetWindowStart,
    required this.targetWindowEnd,
    required this.planningNotes,
    required this.releasedExecutionId,
  });

  final String id;
  final int version;
  final MaintenancePlanStatus status;
  final String assetIdentityKey;
  final String assetTypeKey;
  final int assetNumber;
  final String? assetClassId;
  final String? assetInstanceId;
  final FrozenMaintenanceClass maintenanceClass;
  final DateTime targetWindowStart;
  final DateTime targetWindowEnd;
  final String? planningNotes;
  final String? releasedExecutionId;

  factory MaintenancePlan.fromMap(Map<String, dynamic> map, String documentId) {
    final source = 'maintenance_plans/$documentId';
    final rawClass = map['maintenanceClass'];
    if (rawClass is! Map) {
      throw PersistedDataFormatException(
        field: 'maintenanceClass',
        source: source,
        detail: 'frozen maintenance class is absent',
      );
    }
    return MaintenancePlan(
      id: documentId,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      status: readRequiredPersistedEnum(
        MaintenancePlanStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      assetIdentityKey: readRequiredPersistedString(
        map['assetIdentityKey'],
        field: 'assetIdentityKey',
        source: source,
      ),
      assetTypeKey: readRequiredPersistedString(
        map['assetTypeKey'],
        field: 'assetTypeKey',
        source: source,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetClassId: readOptionalPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetInstanceId: readOptionalPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      maintenanceClass: FrozenMaintenanceClass.fromMap(
        Map<String, dynamic>.from(rawClass),
        source: '$source/maintenanceClass',
      ),
      targetWindowStart: readRequiredPersistedDateTime(
        map['targetWindowStart'],
        field: 'targetWindowStart',
        source: source,
      ),
      targetWindowEnd: readRequiredPersistedDateTime(
        map['targetWindowEnd'],
        field: 'targetWindowEnd',
        source: source,
      ),
      planningNotes: readOptionalPersistedString(
        map['planningNotes'],
        field: 'planningNotes',
        source: source,
      ),
      releasedExecutionId: readOptionalPersistedString(
        map['releasedExecutionId'],
        field: 'releasedExecutionId',
        source: source,
      ),
    );
  }
}
