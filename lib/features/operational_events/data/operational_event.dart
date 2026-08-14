import '../../../core/serialization/persisted_data_reader.dart';

enum OperationalEventType {
  water,
  nitrogen,
  mixedGas,
  hydrogen,
  powerTrip,
  crane,
  transferCar,
  other;

  String get label => switch (this) {
    water => 'Water',
    nitrogen => 'N2',
    mixedGas => 'Mixed gas',
    hydrogen => 'H2',
    powerTrip => 'Power trip',
    crane => 'Crane',
    transferCar => 'Transfer car',
    other => 'Other',
  };
}

enum OperationalEventSeverity {
  advisory,
  significant,
  critical;

  String get label => switch (this) {
    advisory => 'Advisory',
    significant => 'Significant',
    critical => 'Critical',
  };
}

enum OperationalEventScope {
  plantWide,
  assetClasses,
  assets;

  String get label => switch (this) {
    plantWide => 'Whole plant',
    assetClasses => 'Asset classes',
    assets => 'Selected assets',
  };
}

enum OperationalEventStatus {
  open,
  resolved;

  String get label => switch (this) {
    open => 'Open',
    resolved => 'Resolved',
  };
}

class OperationalEventDraft {
  const OperationalEventDraft({
    required this.eventType,
    required this.title,
    required this.description,
    required this.severity,
    required this.scope,
    required this.affectedAssetClassIds,
    required this.affectedAssetInstanceIds,
    required this.startedAt,
  });

  final OperationalEventType eventType;
  final String title;
  final String description;
  final OperationalEventSeverity severity;
  final OperationalEventScope scope;
  final List<String> affectedAssetClassIds;
  final List<String> affectedAssetInstanceIds;
  final DateTime startedAt;

  Map<String, dynamic> toCommandMap() => <String, dynamic>{
    'eventType': eventType.name,
    'title': title.trim(),
    'description': description.trim(),
    'severity': severity.name,
    'scope': scope.name,
    'affectedAssetClassIds': affectedAssetClassIds.toSet().toList()..sort(),
    'affectedAssetInstanceIds':
        affectedAssetInstanceIds.toSet().toList()..sort(),
    'startedAt': startedAt.toUtc().toIso8601String(),
  };
}

class OperationalEvent {
  const OperationalEvent({
    required this.eventId,
    required this.eventType,
    required this.title,
    required this.description,
    required this.severity,
    required this.scope,
    required this.affectedAssetClassIds,
    required this.affectedAssetInstanceIds,
    required this.startedAt,
    required this.status,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByName,
    required this.resolvedAt,
    required this.resolvedByUid,
    required this.resolvedByName,
    required this.resolutionNote,
    required this.version,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
    required this.lastMutationId,
  });

  final String eventId;
  final OperationalEventType eventType;
  final String title;
  final String description;
  final OperationalEventSeverity severity;
  final OperationalEventScope scope;
  final List<String> affectedAssetClassIds;
  final List<String> affectedAssetInstanceIds;
  final DateTime startedAt;
  final OperationalEventStatus status;
  final DateTime createdAt;
  final String createdByUid;
  final String createdByName;
  final DateTime? resolvedAt;
  final String? resolvedByUid;
  final String? resolvedByName;
  final String? resolutionNote;
  final int version;
  final DateTime updatedAt;
  final String updatedByUid;
  final String updatedByName;
  final String lastMutationId;

  bool get isOpen => status == OperationalEventStatus.open;

  Duration durationUntil(DateTime end) {
    final effectiveEnd = resolvedAt ?? end;
    return effectiveEnd.isBefore(startedAt)
        ? Duration.zero
        : effectiveEnd.difference(startedAt);
  }

  Duration durationWithin(
    DateTime startInclusive,
    DateTime endExclusive,
    DateTime asOf,
  ) {
    final clippedStart =
        startedAt.isAfter(startInclusive) ? startedAt : startInclusive;
    final naturalEnd = resolvedAt ?? asOf;
    final clippedEnd =
        naturalEnd.isBefore(endExclusive) ? naturalEnd : endExclusive;
    if (!clippedEnd.isAfter(clippedStart)) return Duration.zero;
    return clippedEnd.difference(clippedStart);
  }

  OperationalEventDraft get draft => OperationalEventDraft(
    eventType: eventType,
    title: title,
    description: description,
    severity: severity,
    scope: scope,
    affectedAssetClassIds: affectedAssetClassIds,
    affectedAssetInstanceIds: affectedAssetInstanceIds,
    startedAt: startedAt,
  );

  factory OperationalEvent.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'operational_events/$documentId';
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported operational-event schema $schemaVersion',
      );
    }
    final eventId = readRequiredPersistedString(
      map['eventId'],
      field: 'eventId',
      source: source,
    );
    if (eventId != documentId) {
      throw PersistedDataFormatException(
        field: 'eventId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    if (!map.containsKey('affectedAssetClassIds') ||
        !map.containsKey('affectedAssetInstanceIds')) {
      throw PersistedDataFormatException(
        field: 'affectedAssetClassIds',
        source: source,
        detail: 'complete scope arrays are required',
      );
    }
    final classIds = readOptionalPersistedStringList(
      map['affectedAssetClassIds'],
      field: 'affectedAssetClassIds',
      source: source,
    );
    final assetIds = readOptionalPersistedStringList(
      map['affectedAssetInstanceIds'],
      field: 'affectedAssetInstanceIds',
      source: source,
    );
    if (classIds.length > 20 ||
        assetIds.length > 50 ||
        classIds.toSet().length != classIds.length ||
        assetIds.toSet().length != assetIds.length) {
      throw PersistedDataFormatException(
        field: 'affectedAssetClassIds',
        source: source,
        detail: 'scope lists exceed their bounds or contain duplicates',
      );
    }
    final scope = readRequiredPersistedEnum(
      OperationalEventScope.values,
      map['scope'],
      field: 'scope',
      source: source,
    );
    final scopeValid = switch (scope) {
      OperationalEventScope.plantWide => classIds.isEmpty && assetIds.isEmpty,
      OperationalEventScope.assetClasses =>
        classIds.isNotEmpty && assetIds.isEmpty,
      OperationalEventScope.assets => assetIds.isNotEmpty,
    };
    if (!scopeValid) {
      throw PersistedDataFormatException(
        field: 'scope',
        source: source,
        detail: 'does not agree with the affected asset lists',
      );
    }
    final status = readRequiredPersistedEnum(
      OperationalEventStatus.values,
      map['status'],
      field: 'status',
      source: source,
    );
    final resolvedAt = readOptionalPersistedDateTime(
      map['resolvedAt'],
      field: 'resolvedAt',
      source: source,
    );
    final resolvedByUid = readOptionalPersistedString(
      map['resolvedByUid'],
      field: 'resolvedByUid',
      source: source,
    );
    final resolvedByName = readOptionalPersistedString(
      map['resolvedByName'],
      field: 'resolvedByName',
      source: source,
    );
    final resolutionNote = readOptionalPersistedString(
      map['resolutionNote'],
      field: 'resolutionNote',
      source: source,
    );
    final resolution = <Object?>[
      resolvedAt,
      resolvedByUid,
      resolvedByName,
      resolutionNote,
    ];
    if (status == OperationalEventStatus.open
        ? resolution.any((value) => value != null)
        : resolution.any((value) => value == null)) {
      throw PersistedDataFormatException(
        field: 'resolvedAt',
        source: source,
        detail:
            'resolution evidence must be absent while open and complete after closure',
      );
    }
    if (resolutionNote != null && resolutionNote.length < 8) {
      throw PersistedDataFormatException(
        field: 'resolutionNote',
        source: source,
        detail: 'must contain at least 8 characters',
      );
    }
    return OperationalEvent(
      eventId: eventId,
      eventType: readRequiredPersistedEnum(
        OperationalEventType.values,
        map['eventType'],
        field: 'eventType',
        source: source,
      ),
      title: readRequiredPersistedString(
        map['title'],
        field: 'title',
        source: source,
      ),
      description: readRequiredPersistedString(
        map['description'],
        field: 'description',
        source: source,
      ),
      severity: readRequiredPersistedEnum(
        OperationalEventSeverity.values,
        map['severity'],
        field: 'severity',
        source: source,
      ),
      scope: scope,
      affectedAssetClassIds: List<String>.unmodifiable(classIds),
      affectedAssetInstanceIds: List<String>.unmodifiable(assetIds),
      startedAt: readRequiredPersistedDateTime(
        map['startedAt'],
        field: 'startedAt',
        source: source,
      ),
      status: status,
      createdAt: readRequiredPersistedDateTime(
        map['createdAt'],
        field: 'createdAt',
        source: source,
      ),
      createdByUid: readRequiredPersistedString(
        map['createdByUid'],
        field: 'createdByUid',
        source: source,
      ),
      createdByName: readRequiredPersistedString(
        map['createdByName'],
        field: 'createdByName',
        source: source,
      ),
      resolvedAt: resolvedAt,
      resolvedByUid: resolvedByUid,
      resolvedByName: resolvedByName,
      resolutionNote: resolutionNote,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
      updatedByUid: readRequiredPersistedString(
        map['updatedByUid'],
        field: 'updatedByUid',
        source: source,
      ),
      updatedByName: readRequiredPersistedString(
        map['updatedByName'],
        field: 'updatedByName',
        source: source,
      ),
      lastMutationId: readRequiredPersistedString(
        map['lastMutationId'],
        field: 'lastMutationId',
        source: source,
      ),
    );
  }
}
