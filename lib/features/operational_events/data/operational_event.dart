import '../../../core/serialization/persisted_data_reader.dart';
import 'operational_event_interval_amendment.dart';

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

bool _scopeListsAreValid(
  OperationalEventScope scope,
  List<String> classIds,
  List<String> assetIds,
) => switch (scope) {
  OperationalEventScope.plantWide => classIds.isEmpty && assetIds.isEmpty,
  OperationalEventScope.assetClasses => classIds.isNotEmpty && assetIds.isEmpty,
  OperationalEventScope.assets => assetIds.isNotEmpty,
};

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
    'affectedAssetInstanceIds': affectedAssetInstanceIds.toSet().toList()
      ..sort(),
    'startedAt': canonicalOperationalEventCommandTimestamp(startedAt),
  };
}

String canonicalOperationalEventCommandTimestamp(DateTime value) {
  final utc = value.toUtc();
  return utc
      .subtract(Duration(microseconds: utc.microsecond))
      .toIso8601String();
}

class OperationalEventInterval {
  const OperationalEventInterval({
    this.occurrenceIndex,
    required this.eventType,
    required this.title,
    required this.description,
    required this.severity,
    required this.startedAt,
    required this.resolvedAt,
    required this.scope,
    required this.affectedAssetClassIds,
    required this.affectedAssetInstanceIds,
    this.issueLinkIds = const <String>[],
    this.linkedIssueIds = const <String>[],
    required this.resolvedByUid,
    required this.resolvedByName,
    required this.resolutionNote,
  });

  final OperationalEventType eventType;
  final String title;
  final String description;
  final OperationalEventSeverity severity;
  final DateTime startedAt;
  final DateTime resolvedAt;
  final OperationalEventScope scope;
  final List<String> affectedAssetClassIds;
  final List<String> affectedAssetInstanceIds;
  final List<String> issueLinkIds;
  final List<String> linkedIssueIds;
  final String? resolvedByUid;
  final String? resolvedByName;
  final String? resolutionNote;

  final int? occurrenceIndex;

  OperationalEventInterval withEffectiveEnd({DateTime? end, int? index}) =>
      OperationalEventInterval(
        occurrenceIndex: index ?? occurrenceIndex,
        eventType: eventType,
        title: title,
        description: description,
        severity: severity,
        startedAt: startedAt,
        resolvedAt: end ?? resolvedAt,
        scope: scope,
        affectedAssetClassIds: affectedAssetClassIds,
        affectedAssetInstanceIds: affectedAssetInstanceIds,
        issueLinkIds: issueLinkIds,
        linkedIssueIds: linkedIssueIds,
        resolvedByUid: resolvedByUid,
        resolvedByName: resolvedByName,
        resolutionNote: resolutionNote,
      );

  bool overlaps(DateTime startInclusive, DateTime endExclusive) =>
      startedAt.isBefore(endExclusive) && resolvedAt.isAfter(startInclusive);

  Duration durationWithin(DateTime startInclusive, DateTime endExclusive) {
    final clippedStart = startedAt.isAfter(startInclusive)
        ? startedAt
        : startInclusive;
    final clippedEnd = resolvedAt.isBefore(endExclusive)
        ? resolvedAt
        : endExclusive;
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
    this.issueLinkIds = const <String>[],
    this.linkedIssueIds = const <String>[],
    this.completedIntervals = const [],
    this.intervalEndAmendments = const {},
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
    this.isWithdrawn = false,
    this.withdrawalReason,
    this.withdrawnAt,
    this.withdrawnByUid,
    this.withdrawnByName,
  });

  final String eventId;
  final OperationalEventType eventType;
  final String title;
  final String description;
  final OperationalEventSeverity severity;
  final OperationalEventScope scope;
  final List<String> affectedAssetClassIds;
  final List<String> affectedAssetInstanceIds;
  final List<String> issueLinkIds;
  final List<String> linkedIssueIds;
  final List<OperationalEventInterval> completedIntervals;
  final Map<int, OperationalEventIntervalAmendment> intervalEndAmendments;
  int get currentOccurrenceIndex => completedIntervals.length;

  OperationalEventInterval? closedOccurrence(int index) {
    if (index < 0 || index > currentOccurrenceIndex) return null;
    if (index < currentOccurrenceIndex) {
      return completedIntervals[index].withEffectiveEnd(index: index);
    }
    return resolvedAt == null ? null : occurrencesUntil(resolvedAt!).last;
  }

  int? occurrenceIndexForLink(String linkId) {
    final matches = <int>[
      for (var index = 0; index < completedIntervals.length; index++)
        if (completedIntervals[index].issueLinkIds.contains(linkId)) index,
      if (issueLinkIds.contains(linkId)) currentOccurrenceIndex,
    ];
    return matches.length == 1 ? matches.single : null;
  }

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

  /// Whether this entry was withdrawn as recorded in error - the same
  /// disruption written down twice, or one that never happened. The interval
  /// stays exactly as it was recorded, because it is evidence of what somebody
  /// entered; what changes is that it no longer counts as a disruption.
  /// Absent on every record written before the withdrawal route existed.
  final bool isWithdrawn;
  final String? withdrawalReason;
  final DateTime? withdrawnAt;
  final String? withdrawnByUid;
  final String? withdrawnByName;

  bool get isEffective => !isWithdrawn;

  bool get isOpen => isEffective && status == OperationalEventStatus.open;

  Iterable<OperationalEventInterval> occurrencesUntil(DateTime asOf) sync* {
    for (var index = 0; index < completedIntervals.length; index++) {
      yield completedIntervals[index].withEffectiveEnd(index: index);
    }
    yield OperationalEventInterval(
      occurrenceIndex: currentOccurrenceIndex,
      eventType: eventType,
      title: title,
      description: description,
      severity: severity,
      startedAt: startedAt,
      resolvedAt: resolvedAt ?? asOf,
      scope: scope,
      affectedAssetClassIds: affectedAssetClassIds,
      affectedAssetInstanceIds: affectedAssetInstanceIds,
      issueLinkIds: issueLinkIds,
      linkedIssueIds: linkedIssueIds,
      resolvedByUid: resolvedByUid,
      resolvedByName: resolvedByName,
      resolutionNote: resolutionNote,
    );
  }

  /// Effective occurrences are used by worklists, counts and reports. The
  /// raw [occurrencesUntil] history remains available so a withdrawn entry is
  /// still auditable as the record somebody entered.
  Iterable<OperationalEventInterval> effectiveOccurrencesUntil(
    DateTime asOf,
  ) sync* {
    if (!isEffective) return;
    for (final interval in occurrencesUntil(asOf)) {
      yield interval.withEffectiveEnd(
        end: intervalEndAmendments[interval.occurrenceIndex]
            ?.correctedResolvedAt,
      );
    }
  }

  Duration durationUntil(DateTime end) => effectiveOccurrencesUntil(end).fold(
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
  ) => effectiveOccurrencesUntil(
    asOf,
  ).any((interval) => interval.overlaps(startInclusive, endExclusive));

  int occurrenceCountWithin(
    DateTime startInclusive,
    DateTime endExclusive,
    DateTime asOf,
  ) => effectiveOccurrencesUntil(
    asOf,
  ).where((interval) => interval.overlaps(startInclusive, endExclusive)).length;

  Duration durationWithin(
    DateTime startInclusive,
    DateTime endExclusive,
    DateTime asOf,
  ) {
    return effectiveOccurrencesUntil(asOf).fold(
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
    final issueLinkIds = readOptionalPersistedStringList(
      map['issueLinkIds'],
      field: 'issueLinkIds',
      source: source,
    );
    final linkedIssueIds = readOptionalPersistedStringList(
      map['linkedIssueIds'],
      field: 'linkedIssueIds',
      source: source,
    );
    if (classIds.length > 20 ||
        assetIds.length > 50 ||
        classIds.toSet().length != classIds.length ||
        assetIds.toSet().length != assetIds.length ||
        issueLinkIds.length > 100 ||
        issueLinkIds.toSet().length != issueLinkIds.length ||
        linkedIssueIds.length > 100 ||
        linkedIssueIds.toSet().length != linkedIssueIds.length ||
        issueLinkIds.length != linkedIssueIds.length) {
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
    final scopeValid = _scopeListsAreValid(scope, classIds, assetIds);
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
          (raw.length != 12 && raw.length != 14) ||
          !raw.containsKey('eventType') ||
          !raw.containsKey('title') ||
          !raw.containsKey('description') ||
          !raw.containsKey('severity') ||
          !raw.containsKey('startedAt') ||
          !raw.containsKey('resolvedAt') ||
          !raw.containsKey('scope') ||
          !raw.containsKey('affectedAssetClassIds') ||
          !raw.containsKey('affectedAssetInstanceIds') ||
          !raw.containsKey('resolvedByUid') ||
          !raw.containsKey('resolvedByName') ||
          !raw.containsKey('resolutionNote') ||
          (raw.length == 14 &&
              (!raw.containsKey('issueLinkIds') ||
                  !raw.containsKey('linkedIssueIds')))) {
        throw PersistedDataFormatException(
          field: 'completedIntervals[$index]',
          source: source,
          detail: 'must contain complete time and scope evidence',
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
      final intervalEventType = readRequiredPersistedEnum(
        OperationalEventType.values,
        raw['eventType'],
        field: 'completedIntervals[$index].eventType',
        source: source,
      );
      final intervalTitle = readRequiredPersistedString(
        raw['title'],
        field: 'completedIntervals[$index].title',
        source: source,
      );
      final intervalDescription = readRequiredPersistedString(
        raw['description'],
        field: 'completedIntervals[$index].description',
        source: source,
      );
      final intervalSeverity = readRequiredPersistedEnum(
        OperationalEventSeverity.values,
        raw['severity'],
        field: 'completedIntervals[$index].severity',
        source: source,
      );
      if (raw['affectedAssetClassIds'] is! List ||
          raw['affectedAssetInstanceIds'] is! List) {
        throw PersistedDataFormatException(
          field: 'completedIntervals[$index].affectedAssetClassIds',
          source: source,
          detail: 'complete scope arrays are required',
        );
      }
      final intervalClassIds = readOptionalPersistedStringList(
        raw['affectedAssetClassIds'],
        field: 'completedIntervals[$index].affectedAssetClassIds',
        source: source,
      );
      final intervalAssetIds = readOptionalPersistedStringList(
        raw['affectedAssetInstanceIds'],
        field: 'completedIntervals[$index].affectedAssetInstanceIds',
        source: source,
      );
      final intervalScope = readRequiredPersistedEnum(
        OperationalEventScope.values,
        raw['scope'],
        field: 'completedIntervals[$index].scope',
        source: source,
      );
      final intervalIssueLinkIds = readOptionalPersistedStringList(
        raw['issueLinkIds'],
        field: 'completedIntervals[$index].issueLinkIds',
        source: source,
      );
      final intervalLinkedIssueIds = readOptionalPersistedStringList(
        raw['linkedIssueIds'],
        field: 'completedIntervals[$index].linkedIssueIds',
        source: source,
      );
      final intervalResolvedByUid = readRequiredPersistedString(
        raw['resolvedByUid'],
        field: 'completedIntervals[$index].resolvedByUid',
        source: source,
      );
      final intervalResolvedByName = readRequiredPersistedString(
        raw['resolvedByName'],
        field: 'completedIntervals[$index].resolvedByName',
        source: source,
      );
      final intervalResolutionNote = readRequiredPersistedString(
        raw['resolutionNote'],
        field: 'completedIntervals[$index].resolutionNote',
        source: source,
      );
      if (intervalEnd.isBefore(intervalStart) ||
          (previousResolvedAt != null &&
              intervalStart.isBefore(previousResolvedAt)) ||
          intervalClassIds.length > 20 ||
          intervalAssetIds.length > 50 ||
          intervalClassIds.toSet().length != intervalClassIds.length ||
          intervalAssetIds.toSet().length != intervalAssetIds.length ||
          intervalIssueLinkIds.length > 100 ||
          intervalIssueLinkIds.toSet().length != intervalIssueLinkIds.length ||
          intervalLinkedIssueIds.length > 100 ||
          intervalLinkedIssueIds.toSet().length !=
              intervalLinkedIssueIds.length ||
          intervalIssueLinkIds.length != intervalLinkedIssueIds.length ||
          intervalTitle.length > 120 ||
          intervalDescription.length > 2000 ||
          !_scopeListsAreValid(
            intervalScope,
            intervalClassIds,
            intervalAssetIds,
          ) ||
          intervalResolvedByUid.length > 128 ||
          intervalResolvedByName.length > 200 ||
          intervalResolutionNote.isEmpty ||
          intervalResolutionNote.length > 1000) {
        throw PersistedDataFormatException(
          field: 'completedIntervals[$index]',
          source: source,
          detail: 'must be chronological with a valid occurrence scope',
        );
      }
      completedIntervals.add(
        OperationalEventInterval(
          eventType: intervalEventType,
          title: intervalTitle,
          description: intervalDescription,
          severity: intervalSeverity,
          startedAt: intervalStart,
          resolvedAt: intervalEnd,
          scope: intervalScope,
          affectedAssetClassIds: List<String>.unmodifiable(intervalClassIds),
          affectedAssetInstanceIds: List<String>.unmodifiable(intervalAssetIds),
          issueLinkIds: List<String>.unmodifiable(intervalIssueLinkIds),
          linkedIssueIds: List<String>.unmodifiable(intervalLinkedIssueIds),
          resolvedByUid: intervalResolvedByUid,
          resolvedByName: intervalResolvedByName,
          resolutionNote: intervalResolutionNote,
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
    if (resolutionNote != null && resolutionNote.isEmpty) {
      throw PersistedDataFormatException(
        field: 'resolutionNote',
        source: source,
        detail: 'must not be empty',
      );
    }
    if (resolvedAt != null && resolvedAt.isBefore(startedAt)) {
      throw PersistedDataFormatException(
        field: 'resolvedAt',
        source: source,
        detail: 'must not precede startedAt',
      );
    }
    final isWithdrawn = map.containsKey('isWithdrawn')
        ? readRequiredPersistedBool(
            map['isWithdrawn'],
            field: 'isWithdrawn',
            source: source,
          )
        : false;
    final withdrawalReason = readOptionalPersistedString(
      map['withdrawalReason'],
      field: 'withdrawalReason',
      source: source,
    );
    final withdrawnAt = readOptionalPersistedDateTime(
      map['withdrawnAt'],
      field: 'withdrawnAt',
      source: source,
    );
    final withdrawnByUid = readOptionalPersistedString(
      map['withdrawnByUid'],
      field: 'withdrawnByUid',
      source: source,
    );
    final withdrawnByName = readOptionalPersistedString(
      map['withdrawnByName'],
      field: 'withdrawnByName',
      source: source,
    );
    final withdrawalEvidence = <Object?>[
      withdrawalReason,
      withdrawnAt,
      withdrawnByUid,
      withdrawnByName,
    ];
    final withdrawalEvidenceValid = isWithdrawn
        ? withdrawalEvidence.every((value) => value != null) &&
              withdrawalReason!.isNotEmpty &&
              withdrawalReason.length <= 1000 &&
              withdrawnByUid!.isNotEmpty &&
              withdrawnByUid.length <= 128 &&
              withdrawnByName!.isNotEmpty &&
              withdrawnByName.length <= 200
        : withdrawalEvidence.every((value) => value == null);
    if (!withdrawalEvidenceValid) {
      throw PersistedDataFormatException(
        field: 'isWithdrawn',
        source: source,
        detail: 'withdrawal disposition requires complete accountable evidence',
      );
    }
    final event = OperationalEvent(
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
      issueLinkIds: List<String>.unmodifiable(issueLinkIds),
      linkedIssueIds: List<String>.unmodifiable(linkedIssueIds),
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
      // Absent on every record written before the withdrawal route existed,
      // which reads as what it means: this entry was not withdrawn. A value
      // that is present and not a boolean is a producer fault and fails closed.
      isWithdrawn: isWithdrawn,
      withdrawalReason: withdrawalReason,
      withdrawnAt: withdrawnAt,
      withdrawnByUid: withdrawnByUid,
      withdrawnByName: withdrawnByName,
      intervalEndAmendments: _readEndAmendments(
        map,
        source,
        completedIntervals,
        startedAt,
        resolvedAt,
        readRequiredPersistedDateTime(
          map['updatedAt'],
          field: 'updatedAt',
          source: source,
        ),
      ),
    );
    return event;
  }
}

Map<int, OperationalEventIntervalAmendment> _readEndAmendments(
  Map<String, dynamic> map,
  String source,
  List<OperationalEventInterval> completed,
  DateTime currentStart,
  DateTime? currentEnd,
  DateTime updatedAt,
) {
  if (!map.containsKey('intervalEndAmendments')) return const {};
  final raw = map['intervalEndAmendments'];
  if (raw is! Map<String, dynamic> || raw.length > 101) {
    throw PersistedDataFormatException(
      field: 'intervalEndAmendments',
      source: source,
      detail: 'requires a bounded occurrence map',
    );
  }
  final result = <int, OperationalEventIntervalAmendment>{};
  final identities = <String>{};
  for (final entry in raw.entries) {
    final index = int.tryParse(entry.key);
    if (index == null ||
        index < 0 ||
        index > 100 ||
        '$index' != entry.key ||
        index > completed.length ||
        (index == completed.length && currentEnd == null) ||
        entry.value is! Map<String, dynamic>) {
      throw PersistedDataFormatException(
        field: 'intervalEndAmendments.${entry.key}',
        source: source,
        detail: 'must name one recorded closed occurrence',
      );
    }
    final rawInterval = index < completed.length
        ? (map['completedIntervals'] as List)[index] as Map<String, dynamic>
        : map;
    for (final field in ['startedAt', 'resolvedAt']) {
      readOperationalAmendmentInstant(
        rawInterval[field],
        field: field,
        source: source,
      );
    }
    final amendment = OperationalEventIntervalAmendment.fromMap(
      entry.value as Map<String, dynamic>,
      '$source/intervalEndAmendments/${entry.key}',
    );
    final originalEnd = index < completed.length
        ? completed[index].resolvedAt
        : currentEnd!;
    final originalStart = index < completed.length
        ? completed[index].startedAt
        : currentStart;
    final nextStart = index + 1 < completed.length
        ? completed[index + 1].startedAt
        : index < completed.length
        ? currentStart
        : amendment.amendedAt;
    if (!amendment.originalResolvedAt.isAtSameMomentAs(originalEnd) ||
        amendment.correctedResolvedAt.isBefore(originalStart) ||
        amendment.correctedResolvedAt.isAfter(nextStart) ||
        amendment.amendedAt.isAfter(updatedAt) ||
        !identities.add(amendment.amendmentId)) {
      throw PersistedDataFormatException(
        field: 'intervalEndAmendments.${entry.key}',
        source: source,
        detail: 'contradicts recorded occurrence chronology or identity',
      );
    }
    result[index] = amendment;
  }
  return Map.unmodifiable(result);
}
