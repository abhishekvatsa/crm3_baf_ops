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
    'startedAt': _canonicalCommandTimestamp(startedAt),
  };
}

String _canonicalCommandTimestamp(DateTime value) {
  final utc = value.toUtc();
  return utc
      .subtract(Duration(microseconds: utc.microsecond))
      .toIso8601String();
}

class OperationalEventInterval {
  const OperationalEventInterval({
    required this.startedAt,
    required this.resolvedAt,
  });

  final DateTime startedAt;
  final DateTime resolvedAt;

  bool overlaps(DateTime startInclusive, DateTime endExclusive) =>
      startedAt.isBefore(endExclusive) && resolvedAt.isAfter(startInclusive);

  Duration durationWithin(DateTime startInclusive, DateTime endExclusive) {
    final clippedStart =
        startedAt.isAfter(startInclusive) ? startedAt : startInclusive;
    final clippedEnd =
        resolvedAt.isBefore(endExclusive) ? resolvedAt : endExclusive;
    return clippedEnd.isAfter(clippedStart)
        ? clippedEnd.difference(clippedStart)
        : Duration.zero;
  }
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
    this.completedIntervals = const [],
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
  final List<OperationalEventInterval> completedIntervals;
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

  Iterable<OperationalEventInterval> _intervalsUntil(DateTime asOf) sync* {
    yield* completedIntervals;
    yield OperationalEventInterval(
      startedAt: startedAt,
      resolvedAt: resolvedAt ?? asOf,
    );
  }

  Duration durationUntil(DateTime end) => _intervalsUntil(end).fold(
    Duration.zero,
    (total, interval) =>
        total +
        (interval.resolvedAt.isBefore(interval.startedAt)
            ? Duration.zero
            : interval.resolvedAt.difference(interval.startedAt)),
  );

  bool overlapsWithin(
    DateTime startInclusive,
    DateTime endExclusive,
    DateTime asOf,
  ) => _intervalsUntil(
    asOf,
  ).any((interval) => interval.overlaps(startInclusive, endExclusive));

  int occurrenceCountWithin(
    DateTime startInclusive,
    DateTime endExclusive,
    DateTime asOf,
  ) =>
      _intervalsUntil(asOf)
          .where((interval) => interval.overlaps(startInclusive, endExclusive))
          .length;

  Duration durationWithin(
    DateTime startInclusive,
    DateTime endExclusive,
    DateTime asOf,
  ) {
    return _intervalsUntil(asOf).fold(
      Duration.zero,
      (total, interval) =>
          total + interval.durationWithin(startInclusive, endExclusive),
    );
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
    if (map['affectedAssetClassIds'] is! List ||
        map['affectedAssetInstanceIds'] is! List) {
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
    final startedAt = readRequiredPersistedDateTime(
      map['startedAt'],
      field: 'startedAt',
      source: source,
    );
    final completedRaw = map['completedIntervals'];
    if (completedRaw is! List || completedRaw.length > 100) {
      throw PersistedDataFormatException(
        field: 'completedIntervals',
        source: source,
        detail: 'must be an array of at most 100 completed intervals',
      );
    }
    final completedIntervals = <OperationalEventInterval>[];
    DateTime? previousResolvedAt;
    for (var index = 0; index < completedRaw.length; index++) {
      final raw = completedRaw[index];
      if (raw is! Map<String, dynamic> ||
          raw.length != 2 ||
          !raw.containsKey('startedAt') ||
          !raw.containsKey('resolvedAt')) {
        throw PersistedDataFormatException(
          field: 'completedIntervals[$index]',
          source: source,
          detail: 'must contain only startedAt and resolvedAt',
        );
      }
      final intervalStart = readRequiredPersistedDateTime(
        raw['startedAt'],
        field: 'completedIntervals[$index].startedAt',
        source: source,
      );
      final intervalEnd = readRequiredPersistedDateTime(
        raw['resolvedAt'],
        field: 'completedIntervals[$index].resolvedAt',
        source: source,
      );
      if (intervalEnd.isBefore(intervalStart) ||
          (previousResolvedAt != null &&
              intervalStart.isBefore(previousResolvedAt))) {
        throw PersistedDataFormatException(
          field: 'completedIntervals[$index]',
          source: source,
          detail: 'must be chronological and non-overlapping',
        );
      }
      completedIntervals.add(
        OperationalEventInterval(
          startedAt: intervalStart,
          resolvedAt: intervalEnd,
        ),
      );
      previousResolvedAt = intervalEnd;
    }
    if (previousResolvedAt != null && startedAt.isBefore(previousResolvedAt)) {
      throw PersistedDataFormatException(
        field: 'startedAt',
        source: source,
        detail: 'must not overlap a completed interval',
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
    if (resolvedAt != null && resolvedAt.isBefore(startedAt)) {
      throw PersistedDataFormatException(
        field: 'resolvedAt',
        source: source,
        detail: 'must not precede startedAt',
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
      completedIntervals: List<OperationalEventInterval>.unmodifiable(
        completedIntervals,
      ),
      startedAt: startedAt,
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
