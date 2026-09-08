import 'morning_review_models.dart';

enum MorningReviewAgendaFilter {
  all,
  down,
  unavailable,
  unfit,
  stuckUp,
  open,
  resolved,
  settled,
}

class MorningReviewAgenda {
  const MorningReviewAgenda({required this.subjects});

  final List<MorningReviewAgendaSubject> subjects;

  List<MorningReviewAgendaSubject> subjectsFor(
    MorningReviewAgendaFilter filter,
  ) => filter == MorningReviewAgendaFilter.all
      ? subjects
      : subjects
            .where((subject) => subject.categories.contains(filter))
            .toList(growable: false);

  int countFor(MorningReviewAgendaFilter filter) => subjectsFor(filter).length;

  bool get isEmpty => subjects.isEmpty;
}

class MorningReviewAgendaSubject {
  const MorningReviewAgendaSubject({
    required this.key,
    required this.section,
    required this.assetClassId,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetNumber,
    required this.label,
    required this.matters,
    required this.isShared,
  });

  final String key;
  final MorningReviewSection section;
  final String? assetClassId;
  final String? assetClassName;
  final String? assetInstanceId;
  final String? assetNumber;
  final String label;
  final List<MorningReviewAgendaMatter> matters;
  final bool isShared;

  bool get isGovernedAsset => assetClassId != null && assetInstanceId != null;

  Set<MorningReviewAgendaFilter> get categories => {
    for (final matter in matters) ...matter.categories,
  };
}

class MorningReviewAgendaMatter {
  const MorningReviewAgendaMatter({
    required this.key,
    required this.title,
    required this.summary,
    required this.status,
    required this.sourceFacts,
    required this.entries,
    required this.categories,
  });

  final String key;
  final String title;
  final String summary;
  final String status;
  final List<MorningReviewSourceFact> sourceFacts;
  final List<MorningReviewEntry> entries;
  final Set<MorningReviewAgendaFilter> categories;

  MorningReviewSourceFact? get primaryFact =>
      sourceFacts.isEmpty ? null : sourceFacts.first;

  bool get hasUnverifiedCompletionStatement => sourceFacts.any(
    (fact) =>
        fact.sourceType == 'carriedAction' &&
        _normalized(fact.status) != 'completed' &&
        !_hasCarriedActionCompletionEntry(fact, entries) &&
        entries.any(
          (entry) =>
              entry.kind == MorningReviewEntryKind.currentCompliance &&
              entry.sourceReferences.contains(fact.factId) &&
              entry.text.trimLeft().startsWith(
                'Action ${fact.sourceDocumentId} completed:',
              ),
        ),
  );

  List<String> get linkedAssetLabels => sourceFacts
      .map(
        (fact) => _assetLabel(
          section: fact.section,
          assetClassName: fact.assetClassName,
          assetNumber: fact.assetNumber,
        ),
      )
      .toSet()
      .toList(growable: false);

  List<MorningReviewEntry> get currentCompliance => entries
      .where((entry) => _currentComplianceKinds.contains(entry.kind))
      .toList(growable: false);

  List<MorningReviewEntry> get remainingCompliance => entries
      .where((entry) => _remainingComplianceKinds.contains(entry.kind))
      .toList(growable: false);

  List<MorningReviewEntry> get discussion => entries
      .where(
        (entry) =>
            !_currentComplianceKinds.contains(entry.kind) &&
            !_remainingComplianceKinds.contains(entry.kind),
      )
      .toList(growable: false);
}

MorningReviewAgenda compileMorningReviewAgenda({
  required List<MorningReviewSourceFact> sourceFacts,
  required List<MorningReviewEntry> entries,
}) {
  final factsById = <String, MorningReviewSourceFact>{
    for (final fact in sourceFacts) fact.factId: fact,
  };
  final subjectBuilders = <String, _SubjectBuilder>{};
  final matterByFactId = <String, _MatterBuilder>{};
  final consumedBySharedMatter = <String>{};
  final sharedEntryIds = <String>{};

  for (final entry in entries) {
    final referenced = entry.sourceReferences
        .map((reference) => factsById[reference])
        .whereType<MorningReviewSourceFact>()
        .toList(growable: false);
    final subjectKeys = referenced.map(_factSubjectKey).toSet();
    if (referenced.length < 2 || subjectKeys.length < 2) continue;
    consumedBySharedMatter.addAll(referenced.map((fact) => fact.factId));
    sharedEntryIds.add(entry.entryId);
    final subject = subjectBuilders.putIfAbsent(
      'shared:${entry.entryId}',
      () => _SubjectBuilder.shared(entry.section, entry.entryId),
    );
    final matter = _MatterBuilder(
      key: 'shared:${entry.entryId}',
      sourceFacts: referenced,
      entries: [entry],
      sharedTitle: 'Shared plant constraint',
    );
    subject.matters.add(matter);
    for (final fact in referenced) {
      matterByFactId[fact.factId] = matter;
    }
  }

  for (final fact in sourceFacts) {
    if (consumedBySharedMatter.contains(fact.factId)) continue;
    final subjectKey = _factSubjectKey(fact);
    final subject = subjectBuilders.putIfAbsent(
      subjectKey,
      () => _SubjectBuilder.fromFact(subjectKey, fact),
    );
    final matter = _MatterBuilder(
      key: fact.factId,
      sourceFacts: [fact],
      entries: [],
    );
    subject.matters.add(matter);
    matterByFactId[fact.factId] = matter;
  }

  for (final entry in entries) {
    if (sharedEntryIds.contains(entry.entryId)) continue;
    final referencedMatter = entry.sourceReferences
        .map((reference) => matterByFactId[reference])
        .whereType<_MatterBuilder>()
        .firstOrNull;
    if (referencedMatter != null) {
      referencedMatter.entries.add(entry);
      continue;
    }
    final subjectKey = _entrySubjectKey(entry);
    final subject = subjectBuilders.putIfAbsent(
      subjectKey,
      () => _SubjectBuilder.fromEntry(subjectKey, entry),
    );
    subject.matters.add(
      _MatterBuilder(
        key: 'entry:${entry.entryId}',
        sourceFacts: const [],
        entries: [entry],
      ),
    );
  }

  final subjects =
      subjectBuilders.values
          .map((builder) => builder.build())
          .where((subject) => subject.matters.isNotEmpty)
          .toList(growable: false)
        ..sort(_compareSubjects);
  return MorningReviewAgenda(subjects: List.unmodifiable(subjects));
}

const _currentComplianceKinds = <MorningReviewEntryKind>{
  MorningReviewEntryKind.update,
  MorningReviewEntryKind.observation,
  MorningReviewEntryKind.currentCompliance,
  MorningReviewEntryKind.maintenanceUpdate,
  MorningReviewEntryKind.conclusion,
  MorningReviewEntryKind.standingConcernCheck,
};

const _remainingComplianceKinds = <MorningReviewEntryKind>{
  MorningReviewEntryKind.plan,
  MorningReviewEntryKind.blocker,
  MorningReviewEntryKind.decision,
  MorningReviewEntryKind.idea,
  MorningReviewEntryKind.remainingCompliance,
  MorningReviewEntryKind.safetyConcern,
};

class _SubjectBuilder {
  _SubjectBuilder({
    required this.key,
    required this.section,
    required this.assetClassId,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetNumber,
    required this.label,
    required this.isShared,
  });

  factory _SubjectBuilder.fromFact(String key, MorningReviewSourceFact fact) =>
      _SubjectBuilder(
        key: key,
        section: fact.section,
        assetClassId: fact.assetClassId,
        assetClassName: fact.assetClassName,
        assetInstanceId: fact.assetInstanceId,
        assetNumber: fact.assetNumber,
        label: _assetLabel(
          section: fact.section,
          assetClassName: fact.assetClassName,
          assetNumber: fact.assetNumber,
        ),
        isShared: false,
      );

  factory _SubjectBuilder.fromEntry(String key, MorningReviewEntry entry) =>
      _SubjectBuilder(
        key: key,
        section: entry.section,
        assetClassId: entry.assetClassId,
        assetClassName: entry.assetClassName,
        assetInstanceId: entry.assetInstanceId,
        assetNumber: entry.assetNumber,
        label: _assetLabel(
          section: entry.section,
          assetClassName: entry.assetClassName,
          assetNumber: entry.assetNumber,
        ),
        isShared: false,
      );

  factory _SubjectBuilder.shared(MorningReviewSection _, String key) =>
      _SubjectBuilder(
        key: 'shared:$key',
        section: MorningReviewSection.plantWide,
        assetClassId: null,
        assetClassName: null,
        assetInstanceId: null,
        assetNumber: null,
        label: 'Shared plant topic',
        isShared: true,
      );

  final String key;
  final MorningReviewSection section;
  final String? assetClassId;
  final String? assetClassName;
  final String? assetInstanceId;
  final String? assetNumber;
  final String label;
  final bool isShared;
  final List<_MatterBuilder> matters = [];

  MorningReviewAgendaSubject build() {
    final builtMatters = matters.map((matter) => matter.build()).toList()
      ..sort(_compareMatters);
    return MorningReviewAgendaSubject(
      key: key,
      section: section,
      assetClassId: assetClassId,
      assetClassName: assetClassName,
      assetInstanceId: assetInstanceId,
      assetNumber: assetNumber,
      label: label,
      matters: List.unmodifiable(builtMatters),
      isShared: isShared,
    );
  }
}

class _MatterBuilder {
  _MatterBuilder({
    required this.key,
    required this.sourceFacts,
    required this.entries,
    this.sharedTitle,
  });

  final String key;
  final List<MorningReviewSourceFact> sourceFacts;
  final List<MorningReviewEntry> entries;
  final String? sharedTitle;

  MorningReviewAgendaMatter build() {
    final orderedEntries = [...entries]
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final statuses = sourceFacts
        .map((fact) => fact.status.trim())
        .where((status) => status.isNotEmpty)
        .toSet();
    final categories = <MorningReviewAgendaFilter>{};
    for (final fact in sourceFacts) {
      categories.addAll(_categoriesForFact(fact, orderedEntries));
    }
    if (sourceFacts.isEmpty &&
        orderedEntries.any(
          (entry) => _remainingComplianceKinds.contains(entry.kind),
        )) {
      categories.add(MorningReviewAgendaFilter.open);
    }
    return MorningReviewAgendaMatter(
      key: key,
      title: _matterTitle(sourceFacts, orderedEntries, sharedTitle),
      summary: _matterSummary(sourceFacts),
      status: statuses.isEmpty ? 'Meeting contribution' : statuses.join(' / '),
      sourceFacts: List.unmodifiable(sourceFacts),
      entries: List.unmodifiable(orderedEntries),
      categories: Set.unmodifiable(categories),
    );
  }
}

Set<MorningReviewAgendaFilter> _categoriesForFact(
  MorningReviewSourceFact fact,
  List<MorningReviewEntry> entries,
) {
  final normalized = _normalized(fact.status);
  final categories = <MorningReviewAgendaFilter>{};
  final condition = fact.plantConditionEffect;
  if (condition == 'unfit') categories.add(MorningReviewAgendaFilter.unfit);
  if (condition == 'unavailable') {
    categories.add(MorningReviewAgendaFilter.unavailable);
  }
  if (condition == 'stuckUp') categories.add(MorningReviewAgendaFilter.stuckUp);
  if (normalized == 'down') categories.add(MorningReviewAgendaFilter.down);
  if (normalized == 'unavailable') {
    categories.add(MorningReviewAgendaFilter.unavailable);
  }
  if (normalized == 'unfit') categories.add(MorningReviewAgendaFilter.unfit);
  if (normalized == 'stuckup' || normalized == 'temporarilyblocked') {
    categories.add(MorningReviewAgendaFilter.stuckUp);
  }
  final carriedActionCompletedToday = _hasCarriedActionCompletionEntry(
    fact,
    entries,
  );
  if (!carriedActionCompletedToday &&
      (_activeStatuses.contains(normalized) ||
          (fact.sourceType == 'carriedAction' && normalized != 'completed'))) {
    categories.add(MorningReviewAgendaFilter.open);
  }
  if (carriedActionCompletedToday ||
      _resolvedStatuses.contains(normalized) ||
      (fact.sourceType == 'carriedAction' && normalized == 'completed')) {
    categories.add(MorningReviewAgendaFilter.resolved);
  }
  if (_settledStatuses.contains(normalized)) {
    categories.add(MorningReviewAgendaFilter.settled);
  }
  return categories;
}

bool _hasCarriedActionCompletionEntry(
  MorningReviewSourceFact fact,
  List<MorningReviewEntry> entries,
) {
  if (fact.sourceType != 'carriedAction' ||
      fact.sourceCollection != 'morning_review_actions' ||
      fact.factId != 'morning_review_actions/${fact.sourceDocumentId}') {
    return false;
  }
  return entries.any(
    (entry) =>
        entry.actionCompletion?.actionId == fact.sourceDocumentId &&
        (fact.observedAt == null ||
            !entry.createdAt.isBefore(fact.observedAt!)),
  );
}

const _activeStatuses = <String>{
  'open',
  'raised',
  'supportconfirmed',
  'acknowledged',
  'accepted',
  'inprogress',
  'active',
  'deferred',
  'actionable',
  'awaitingconfirmation',
  'down',
  'unfit',
  'unavailable',
  'stuckup',
  'temporarilyblocked',
  'due',
  'overdue',
  'closurerequested',
  'correctiveactionlinked',
  'awaitingverification',
  'closedwithoutresolution',
  'closedwithoutresolutionstillrelevant',
};

const _resolvedStatuses = <String>{
  'resolved',
  'closed',
  'completed',
  'restored',
  'available',
  'verifiedresolved',
};

const _settledStatuses = <String>{
  'cancelled',
  'withdrawn',
  'withdrawninerror',
  'acceptedcondition',
  'invalidated',
  'closedwithoutresolutionrelevanceended',
};

String _factSubjectKey(MorningReviewSourceFact fact) => _subjectKey(
  section: fact.section,
  assetClassId: fact.assetClassId,
  assetClassName: fact.assetClassName,
  assetInstanceId: fact.assetInstanceId,
  assetNumber: fact.assetNumber,
);

String _entrySubjectKey(MorningReviewEntry entry) => _subjectKey(
  section: entry.section,
  assetClassId: entry.assetClassId,
  assetClassName: entry.assetClassName,
  assetInstanceId: entry.assetInstanceId,
  assetNumber: entry.assetNumber,
);

String _subjectKey({
  required MorningReviewSection section,
  required String? assetClassId,
  required String? assetClassName,
  required String? assetInstanceId,
  required String? assetNumber,
}) {
  if (assetClassId != null && assetInstanceId != null) {
    return 'asset:$assetClassId:$assetInstanceId';
  }
  if (assetClassName != null && assetNumber != null) {
    return 'provisional:${_normalized(assetClassName)}:${_normalized(assetNumber)}';
  }
  if (assetClassName != null) {
    return 'class:${_normalized(assetClassName)}';
  }
  return 'general:${section.name}';
}

String _matterTitle(
  List<MorningReviewSourceFact> facts,
  List<MorningReviewEntry> entries,
  String? sharedTitle,
) {
  if (sharedTitle != null) return sharedTitle;
  if (facts.isNotEmpty) return facts.first.title;
  if (entries.isEmpty) return 'Meeting matter';
  return _entryKindLabel(entries.first.kind);
}

String _matterSummary(List<MorningReviewSourceFact> facts) {
  final summaries = facts
      .map((fact) => fact.summary.trim())
      .where((summary) => summary.isNotEmpty)
      .toSet();
  return summaries.join('\n');
}

String _assetLabel({
  required MorningReviewSection section,
  required String? assetClassName,
  required String? assetNumber,
}) {
  if (assetClassName != null && assetNumber != null) {
    return '$assetClassName $assetNumber';
  }
  if (assetClassName != null) return assetClassName;
  return switch (section) {
    MorningReviewSection.safety => 'Safety and standing concerns',
    MorningReviewSection.furnace => 'Furnaces',
    MorningReviewSection.base => 'Bases and Inner Covers',
    MorningReviewSection.forcedCooler => 'Forced Coolers',
    MorningReviewSection.otherAsset => 'Other assets',
    MorningReviewSection.plantWide => 'Plant-wide and general',
  };
}

String _entryKindLabel(MorningReviewEntryKind kind) => switch (kind) {
  MorningReviewEntryKind.update => 'Update',
  MorningReviewEntryKind.observation => 'Observation',
  MorningReviewEntryKind.plan => 'Plan',
  MorningReviewEntryKind.blocker => 'Blocker',
  MorningReviewEntryKind.decision => 'Decision',
  MorningReviewEntryKind.idea => 'Idea',
  MorningReviewEntryKind.currentCompliance => 'Current compliance',
  MorningReviewEntryKind.remainingCompliance => 'Remaining compliance',
  MorningReviewEntryKind.maintenanceUpdate => 'Maintenance update',
  MorningReviewEntryKind.conclusion => 'Conclusion',
  MorningReviewEntryKind.safetyConcern => 'Safety concern',
  MorningReviewEntryKind.standingConcernCheck => 'Standing concern check',
  MorningReviewEntryKind.addendum => 'Addendum',
};

int _compareSubjects(
  MorningReviewAgendaSubject left,
  MorningReviewAgendaSubject right,
) {
  final sectionOrder = left.section.index.compareTo(right.section.index);
  if (sectionOrder != 0) return sectionOrder;
  final leftNumber = int.tryParse(left.assetNumber ?? '');
  final rightNumber = int.tryParse(right.assetNumber ?? '');
  if (leftNumber != null && rightNumber != null) {
    final numberOrder = leftNumber.compareTo(rightNumber);
    if (numberOrder != 0) return numberOrder;
  } else if (leftNumber != null) {
    return -1;
  } else if (rightNumber != null) {
    return 1;
  }
  return left.label.toLowerCase().compareTo(right.label.toLowerCase());
}

int _compareMatters(
  MorningReviewAgendaMatter left,
  MorningReviewAgendaMatter right,
) {
  final leftAt = left.primaryFact?.observedAt;
  final rightAt = right.primaryFact?.observedAt;
  if (leftAt != null && rightAt != null) {
    final chronology = rightAt.compareTo(leftAt);
    if (chronology != 0) return chronology;
  }
  return left.title.toLowerCase().compareTo(right.title.toLowerCase());
}

String _normalized(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
