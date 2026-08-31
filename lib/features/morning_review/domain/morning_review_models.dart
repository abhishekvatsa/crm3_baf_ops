import '../../../core/serialization/persisted_data_reader.dart';

enum MorningReviewStatus { open, finalized, notHeld }

enum MorningReviewSourceCaptureState { complete, bounded, notApplicable }

enum MorningReviewSection {
  safety,
  furnace,
  base,
  forcedCooler,
  otherAsset,
  plantWide,
}

enum MorningReviewEntryKind {
  update,
  observation,
  plan,
  blocker,
  decision,
  idea,
  currentCompliance,
  remainingCompliance,
  maintenanceUpdate,
  conclusion,
  safetyConcern,
  standingConcernCheck,
  addendum,
}

enum MorningReviewActionStatus { open, accepted, completed }

enum MorningReviewConcernCriticality { standing, safety }

enum MorningReviewConcernStatus { active, resolved }

enum MorningReviewConcernCheckState { complied, exception }

const _morningReviewRoleKeys = <String>{
  'admin',
  'si',
  'contractSupervisor',
  'shiftSupervisor',
  'seniorElectrical',
  'seniorMechanical',
  'seniorInstrumentation',
  'seniorRefractory',
  'refractory',
  'operations',
};

class MorningReviewSourceFact {
  const MorningReviewSourceFact({
    required this.factId,
    required this.section,
    required this.sourceType,
    required this.sourceCollection,
    required this.sourceDocumentId,
    required this.title,
    required this.summary,
    required this.status,
    required this.assetClassId,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetNumber,
    required this.observedAt,
  });

  final String factId;
  final MorningReviewSection section;
  final String sourceType;
  final String sourceCollection;
  final String sourceDocumentId;
  final String title;
  final String summary;
  final String status;
  final String? assetClassId;
  final String? assetClassName;
  final String? assetInstanceId;
  final String? assetNumber;
  final DateTime? observedAt;

  factory MorningReviewSourceFact.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    _requireExactFields(map, const {
      'factId',
      'section',
      'sourceType',
      'sourceCollection',
      'sourceDocumentId',
      'title',
      'summary',
      'status',
      'assetClassId',
      'assetClassName',
      'assetInstanceId',
      'assetNumber',
      'observedAtIso',
    }, source);
    final assetClassId = _optionalBoundedText(
      map['assetClassId'],
      field: 'assetClassId',
      source: source,
      maximum: 180,
    );
    final assetClassName = _optionalBoundedText(
      map['assetClassName'],
      field: 'assetClassName',
      source: source,
      maximum: 120,
    );
    final assetInstanceId = _optionalBoundedText(
      map['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
      maximum: 180,
    );
    final assetNumber = _optionalBoundedText(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      maximum: 40,
    );
    if ((assetClassId != null && assetClassName == null) ||
        (assetNumber != null && assetClassName == null) ||
        (assetInstanceId != null &&
            (assetNumber == null || assetClassId == null))) {
      throw PersistedDataFormatException(
        field: 'assetIdentity',
        source: source,
        detail: 'retained source identity is internally inconsistent',
      );
    }
    final factId = _boundedText(
      map['factId'],
      field: 'factId',
      source: source,
      maximum: 300,
    );
    final sourceCollection = _boundedText(
      map['sourceCollection'],
      field: 'sourceCollection',
      source: source,
      maximum: 120,
    );
    final sourceDocumentId = _boundedText(
      map['sourceDocumentId'],
      field: 'sourceDocumentId',
      source: source,
      maximum: 240,
    );
    if (factId != '$sourceCollection/$sourceDocumentId') {
      throw PersistedDataFormatException(
        field: 'factId',
        source: source,
        detail: 'must identify the retained source document path',
      );
    }
    return MorningReviewSourceFact(
      factId: factId,
      section: readRequiredPersistedEnum(
        MorningReviewSection.values,
        map['section'],
        field: 'section',
        source: source,
      ),
      sourceType: _boundedText(
        map['sourceType'],
        field: 'sourceType',
        source: source,
        maximum: 80,
      ),
      sourceCollection: sourceCollection,
      sourceDocumentId: sourceDocumentId,
      title: _boundedText(
        map['title'],
        field: 'title',
        source: source,
        maximum: 180,
      ),
      summary: _boundedText(
        map['summary'],
        field: 'summary',
        source: source,
        maximum: 500,
      ),
      status: _boundedText(
        map['status'],
        field: 'status',
        source: source,
        maximum: 80,
      ),
      assetClassId: assetClassId,
      assetClassName: assetClassName,
      assetInstanceId: assetInstanceId,
      assetNumber: assetNumber,
      observedAt: readOptionalPersistedDateTime(
        map['observedAtIso'],
        field: 'observedAtIso',
        source: source,
      ),
    );
  }
}

class MorningReviewFacilitatorTransition {
  const MorningReviewFacilitatorTransition({
    required this.previousFacilitatorUid,
    required this.previousFacilitatorName,
    required this.takenOverAt,
    required this.takenOverByUid,
    required this.takenOverByName,
    required this.reason,
  });

  final String previousFacilitatorUid;
  final String previousFacilitatorName;
  final DateTime takenOverAt;
  final String takenOverByUid;
  final String takenOverByName;
  final String reason;

  factory MorningReviewFacilitatorTransition.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    _requireExactFields(map, const {
      'previousFacilitatorUid',
      'previousFacilitatorName',
      'takenOverAt',
      'takenOverByUid',
      'takenOverByName',
      'reason',
    }, source);
    return MorningReviewFacilitatorTransition(
      previousFacilitatorUid: _boundedText(
        map['previousFacilitatorUid'],
        field: 'previousFacilitatorUid',
        source: source,
        maximum: 256,
      ),
      previousFacilitatorName: _boundedText(
        map['previousFacilitatorName'],
        field: 'previousFacilitatorName',
        source: source,
        maximum: 256,
      ),
      takenOverAt: readRequiredPersistedDateTime(
        map['takenOverAt'],
        field: 'takenOverAt',
        source: source,
      ),
      takenOverByUid: _boundedText(
        map['takenOverByUid'],
        field: 'takenOverByUid',
        source: source,
        maximum: 256,
      ),
      takenOverByName: _boundedText(
        map['takenOverByName'],
        field: 'takenOverByName',
        source: source,
        maximum: 256,
      ),
      reason: _boundedText(
        map['reason'],
        field: 'reason',
        source: source,
        maximum: 1600,
      ),
    );
  }
}

class MorningReviewSession {
  MorningReviewSession({
    required this.sessionId,
    required this.plantDay,
    required this.status,
    required this.version,
    required this.openedAt,
    required this.openedByUid,
    required this.openedByName,
    required this.facilitatorUid,
    required this.facilitatorName,
    required this.facilitatorRoleKeys,
    required this.facilitatorHistory,
    required this.sourceCapturedAt,
    required this.sourceFacts,
    required this.sourceFactDigest,
    required this.sourceCaptureState,
    required this.sourceCollectionsAtLimit,
    required this.finalizedAt,
    required this.finalizedByUid,
    required this.finalizedByName,
    required this.finalSummary,
    required this.documentDigest,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
    required this.expiresAt,
    required this.lastMutationId,
  });

  final String sessionId;
  final String plantDay;
  final MorningReviewStatus status;
  final int version;
  final DateTime? openedAt;
  final String? openedByUid;
  final String? openedByName;
  final String facilitatorUid;
  final String facilitatorName;
  final List<String> facilitatorRoleKeys;
  final List<MorningReviewFacilitatorTransition> facilitatorHistory;
  final DateTime? sourceCapturedAt;
  final List<MorningReviewSourceFact> sourceFacts;
  final String? sourceFactDigest;
  final MorningReviewSourceCaptureState sourceCaptureState;
  final List<String> sourceCollectionsAtLimit;
  final DateTime? finalizedAt;
  final String? finalizedByUid;
  final String? finalizedByName;
  final String? finalSummary;
  final String? documentDigest;
  final DateTime updatedAt;
  final String updatedByUid;
  final String updatedByName;
  final DateTime expiresAt;
  final String lastMutationId;

  bool get isOpen => status == MorningReviewStatus.open;
  bool get isFinalized => status == MorningReviewStatus.finalized;

  factory MorningReviewSession.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'morning_review_sessions/$documentId';
    _requireExactFields(map, const {
      'schemaVersion',
      'sessionId',
      'plantDay',
      'status',
      'version',
      'openedAt',
      'openedByUid',
      'openedByName',
      'facilitatorUid',
      'facilitatorName',
      'facilitatorRoleKeys',
      'facilitatorHistory',
      'sourceCapturedAt',
      'sourceFacts',
      'sourceFactDigest',
      'sourceFactCount',
      'sourceCaptureState',
      'sourceCollectionsAtLimit',
      'finalizedAt',
      'finalizedByUid',
      'finalizedByName',
      'finalSummary',
      'documentDigest',
      'updatedAt',
      'updatedByUid',
      'updatedByName',
      'expiresAt',
      'lastMutationId',
    }, source);
    _schemaOne(map, source);
    final sessionId = _boundedText(
      map['sessionId'],
      field: 'sessionId',
      source: source,
      maximum: 10,
    );
    final plantDay = _boundedText(
      map['plantDay'],
      field: 'plantDay',
      source: source,
      maximum: 10,
    );
    if (sessionId != documentId || plantDay != documentId) {
      throw PersistedDataFormatException(
        field: 'sessionId',
        source: source,
        detail: 'session, plant day and document identities must match',
      );
    }
    final status = readRequiredPersistedEnum(
      MorningReviewStatus.values,
      map['status'],
      field: 'status',
      source: source,
    );
    final openedAt = readOptionalPersistedDateTime(
      map['openedAt'],
      field: 'openedAt',
      source: source,
    );
    final openedByUid = _optionalBoundedText(
      map['openedByUid'],
      field: 'openedByUid',
      source: source,
      maximum: 256,
    );
    final openedByName = _optionalBoundedText(
      map['openedByName'],
      field: 'openedByName',
      source: source,
      maximum: 256,
    );
    final finalizedAt = readOptionalPersistedDateTime(
      map['finalizedAt'],
      field: 'finalizedAt',
      source: source,
    );
    final finalizedByUid = _optionalBoundedText(
      map['finalizedByUid'],
      field: 'finalizedByUid',
      source: source,
      maximum: 256,
    );
    final finalizedByName = _optionalBoundedText(
      map['finalizedByName'],
      field: 'finalizedByName',
      source: source,
      maximum: 256,
    );
    final finalSummary = _optionalBoundedText(
      map['finalSummary'],
      field: 'finalSummary',
      source: source,
      maximum: 2000,
    );
    final openEvidenceComplete =
        openedAt != null && openedByUid != null && openedByName != null;
    final finalEvidenceComplete =
        finalizedAt != null &&
        finalizedByUid != null &&
        finalizedByName != null &&
        finalSummary != null;
    if ((status == MorningReviewStatus.open &&
            (!openEvidenceComplete || finalEvidenceComplete)) ||
        (status == MorningReviewStatus.finalized &&
            (!openEvidenceComplete || !finalEvidenceComplete)) ||
        (status == MorningReviewStatus.notHeld &&
            (openEvidenceComplete || !finalEvidenceComplete))) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'lifecycle evidence does not match the session status',
      );
    }
    final sourceFacts = _objectList(
          map['sourceFacts'],
          field: 'sourceFacts',
          source: source,
          maximum: 220,
        )
        .asMap()
        .entries
        .map(
          (entry) => MorningReviewSourceFact.fromMap(
            entry.value,
            source: '$source/sourceFacts[${entry.key}]',
          ),
        )
        .toList(growable: false);
    final sourceFactCount = readRequiredPersistedInt(
      map['sourceFactCount'],
      field: 'sourceFactCount',
      source: source,
      minimum: 0,
    );
    if (sourceFactCount != sourceFacts.length) {
      throw PersistedDataFormatException(
        field: 'sourceFactCount',
        source: source,
        detail: 'does not match the retained source-fact population',
      );
    }
    final history = _objectList(
      map['facilitatorHistory'],
      field: 'facilitatorHistory',
      source: source,
      maximum: 20,
    );
    final sourceCapturedAt = readOptionalPersistedDateTime(
      map['sourceCapturedAt'],
      field: 'sourceCapturedAt',
      source: source,
    );
    final sourceFactDigest = _optionalBoundedText(
      map['sourceFactDigest'],
      field: 'sourceFactDigest',
      source: source,
      maximum: 100,
    );
    final sourceCaptureState = readRequiredPersistedEnum(
      MorningReviewSourceCaptureState.values,
      map['sourceCaptureState'],
      field: 'sourceCaptureState',
      source: source,
    );
    final sourceCollectionsAtLimit = _boundedStringList(
      map['sourceCollectionsAtLimit'],
      field: 'sourceCollectionsAtLimit',
      source: source,
      maximumItems: 10,
      maximumLength: 120,
    );
    final documentDigest = _optionalBoundedText(
      map['documentDigest'],
      field: 'documentDigest',
      source: source,
      maximum: 100,
    );
    final updatedAt = readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    final expiresAt = readRequiredPersistedDateTime(
      map['expiresAt'],
      field: 'expiresAt',
      source: source,
    );
    final sourceIds = sourceFacts.map((fact) => fact.factId).toSet();
    final sourceDigestValid =
        sourceFactDigest != null &&
        RegExp(
          r'^morningreviewsource1-sha256:[0-9a-f]{64}$',
        ).hasMatch(sourceFactDigest);
    final completeCapture =
        sourceCapturedAt != null &&
        sourceDigestValid &&
        sourceCaptureState != MorningReviewSourceCaptureState.notApplicable &&
        ((sourceCaptureState == MorningReviewSourceCaptureState.complete &&
                sourceCollectionsAtLimit.isEmpty) ||
            (sourceCaptureState == MorningReviewSourceCaptureState.bounded &&
                sourceCollectionsAtLimit.isNotEmpty));
    final notApplicableCapture =
        sourceCapturedAt == null &&
        sourceFactDigest == null &&
        sourceCaptureState == MorningReviewSourceCaptureState.notApplicable &&
        sourceCollectionsAtLimit.isEmpty &&
        sourceFacts.isEmpty;
    final documentDigestValid =
        documentDigest != null &&
        RegExp(
          r'^morningreviewdocument1-sha256:[0-9a-f]{64}$',
        ).hasMatch(documentDigest);
    final chronologyValid =
        expiresAt.isAfter(updatedAt) &&
        (openedAt == null || !updatedAt.isBefore(openedAt)) &&
        (sourceCapturedAt == null || !updatedAt.isBefore(sourceCapturedAt)) &&
        (finalizedAt == null || !updatedAt.isBefore(finalizedAt));
    if (sourceIds.length != sourceFacts.length ||
        !chronologyValid ||
        (status == MorningReviewStatus.open &&
            (!completeCapture || documentDigest != null)) ||
        (status == MorningReviewStatus.finalized &&
            (!completeCapture || !documentDigestValid)) ||
        (status == MorningReviewStatus.notHeld &&
            (!notApplicableCapture || documentDigest != null))) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'source, document, or retention evidence is inconsistent',
      );
    }
    return MorningReviewSession(
      sessionId: sessionId,
      plantDay: plantDay,
      status: status,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      openedAt: openedAt,
      openedByUid: openedByUid,
      openedByName: openedByName,
      facilitatorUid: _boundedText(
        map['facilitatorUid'],
        field: 'facilitatorUid',
        source: source,
        maximum: 256,
      ),
      facilitatorName: _boundedText(
        map['facilitatorName'],
        field: 'facilitatorName',
        source: source,
        maximum: 256,
      ),
      facilitatorRoleKeys: _boundedStringList(
        map['facilitatorRoleKeys'],
        field: 'facilitatorRoleKeys',
        source: source,
        maximumItems: 20,
        maximumLength: 80,
      ),
      facilitatorHistory: List.unmodifiable(
        history.asMap().entries.map(
          (entry) => MorningReviewFacilitatorTransition.fromMap(
            entry.value,
            source: '$source/facilitatorHistory[${entry.key}]',
          ),
        ),
      ),
      sourceCapturedAt: sourceCapturedAt,
      sourceFacts: List.unmodifiable(sourceFacts),
      sourceFactDigest: sourceFactDigest,
      sourceCaptureState: sourceCaptureState,
      sourceCollectionsAtLimit: sourceCollectionsAtLimit,
      finalizedAt: finalizedAt,
      finalizedByUid: finalizedByUid,
      finalizedByName: finalizedByName,
      finalSummary: finalSummary,
      documentDigest: documentDigest,
      updatedAt: updatedAt,
      updatedByUid: _boundedText(
        map['updatedByUid'],
        field: 'updatedByUid',
        source: source,
        maximum: 256,
      ),
      updatedByName: _boundedText(
        map['updatedByName'],
        field: 'updatedByName',
        source: source,
        maximum: 256,
      ),
      expiresAt: expiresAt,
      lastMutationId: _boundedText(
        map['lastMutationId'],
        field: 'lastMutationId',
        source: source,
        maximum: 80,
      ),
    );
  }
}

class MorningReviewParticipant {
  const MorningReviewParticipant({
    required this.participantId,
    required this.sessionId,
    required this.userUid,
    required this.userName,
    required this.roleKeys,
    required this.joinedAt,
  });

  final String participantId;
  final String sessionId;
  final String userUid;
  final String userName;
  final List<String> roleKeys;
  final DateTime joinedAt;

  factory MorningReviewParticipant.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    bool embedded = false,
  }) {
    final normalized = _withoutEmbeddedDocumentId(map, documentId, embedded);
    final source = 'morning_review_participants/$documentId';
    _requireExactFields(normalized, const {
      'schemaVersion',
      'participantId',
      'sessionId',
      'userUid',
      'userName',
      'roleKeys',
      'state',
      'joinedAt',
      'joinedByRequestId',
      'expiresAt',
    }, source);
    _schemaOne(normalized, source);
    final id = _boundedText(
      normalized['participantId'],
      field: 'participantId',
      source: source,
      maximum: 300,
    );
    final sessionId = _boundedText(
      normalized['sessionId'],
      field: 'sessionId',
      source: source,
      maximum: 10,
    );
    final userUid = _boundedText(
      normalized['userUid'],
      field: 'userUid',
      source: source,
      maximum: 256,
    );
    _boundedText(
      normalized['joinedByRequestId'],
      field: 'joinedByRequestId',
      source: source,
      maximum: 80,
    );
    if (id != documentId ||
        id != '${sessionId}_$userUid' ||
        normalized['state'] != 'joined') {
      throw PersistedDataFormatException(
        field: 'participantId',
        source: source,
        detail: 'identity or joined state mismatch',
      );
    }
    readRequiredPersistedDateTime(
      normalized['expiresAt'],
      field: 'expiresAt',
      source: source,
    );
    return MorningReviewParticipant(
      participantId: id,
      sessionId: sessionId,
      userUid: userUid,
      userName: _boundedText(
        normalized['userName'],
        field: 'userName',
        source: source,
        maximum: 256,
      ),
      roleKeys: _boundedStringList(
        normalized['roleKeys'],
        field: 'roleKeys',
        source: source,
        maximumItems: 20,
        maximumLength: 80,
      ),
      joinedAt: readRequiredPersistedDateTime(
        normalized['joinedAt'],
        field: 'joinedAt',
        source: source,
      ),
    );
  }
}

class MorningReviewEntry {
  const MorningReviewEntry({
    required this.entryId,
    required this.sessionId,
    required this.section,
    required this.kind,
    required this.text,
    required this.assetClassId,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetNumber,
    required this.sourceReferences,
    required this.authorUid,
    required this.authorName,
    required this.authorRoleKeys,
    required this.createdAt,
    required this.addendumReason,
  });

  final String entryId;
  final String sessionId;
  final MorningReviewSection section;
  final MorningReviewEntryKind kind;
  final String text;
  final String? assetClassId;
  final String? assetClassName;
  final String? assetInstanceId;
  final String? assetNumber;
  final List<String> sourceReferences;
  final String authorUid;
  final String authorName;
  final List<String> authorRoleKeys;
  final DateTime createdAt;
  final String? addendumReason;

  factory MorningReviewEntry.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    bool embedded = false,
  }) {
    final normalized = _withoutEmbeddedDocumentId(map, documentId, embedded);
    final source = 'morning_review_entries/$documentId';
    _requireExactFields(normalized, const {
      'schemaVersion',
      'entryId',
      'sessionId',
      'plantDay',
      'section',
      'kind',
      'text',
      'assetClassId',
      'assetClassName',
      'assetInstanceId',
      'assetNumber',
      'sourceReferences',
      'authorUid',
      'authorName',
      'authorRoleKeys',
      'createdAt',
      'addendumReason',
      'expiresAt',
    }, source);
    _schemaOne(normalized, source);
    final id = _boundedText(
      normalized['entryId'],
      field: 'entryId',
      source: source,
      maximum: 80,
    );
    if (id != documentId || normalized['plantDay'] != normalized['sessionId']) {
      throw PersistedDataFormatException(
        field: 'entryId',
        source: source,
        detail: 'entry identity or plant day mismatch',
      );
    }
    readRequiredPersistedDateTime(
      normalized['expiresAt'],
      field: 'expiresAt',
      source: source,
    );
    final sessionId = _boundedText(
      normalized['sessionId'],
      field: 'sessionId',
      source: source,
      maximum: 10,
    );
    final kind = readRequiredPersistedEnum(
      MorningReviewEntryKind.values,
      normalized['kind'],
      field: 'kind',
      source: source,
    );
    final assetClassId = _optionalBoundedText(
      normalized['assetClassId'],
      field: 'assetClassId',
      source: source,
      maximum: 180,
    );
    final assetClassName = _optionalBoundedText(
      normalized['assetClassName'],
      field: 'assetClassName',
      source: source,
      maximum: 120,
    );
    final assetInstanceId = _optionalBoundedText(
      normalized['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
      maximum: 180,
    );
    final assetNumber = _optionalBoundedText(
      normalized['assetNumber'],
      field: 'assetNumber',
      source: source,
      maximum: 40,
    );
    final addendumReason = _optionalBoundedText(
      normalized['addendumReason'],
      field: 'addendumReason',
      source: source,
      maximum: 1600,
    );
    if ((assetClassId == null) != (assetClassName == null) ||
        (assetInstanceId == null) != (assetNumber == null) ||
        (assetInstanceId != null && assetClassId == null)) {
      throw PersistedDataFormatException(
        field: 'assetIdentity',
        source: source,
        detail: 'class and instance identity pairs must be complete',
      );
    }
    if ((kind == MorningReviewEntryKind.addendum) != (addendumReason != null)) {
      throw PersistedDataFormatException(
        field: 'addendumReason',
        source: source,
        detail: 'must be present only for an addendum',
      );
    }
    return MorningReviewEntry(
      entryId: id,
      sessionId: sessionId,
      section: readRequiredPersistedEnum(
        MorningReviewSection.values,
        normalized['section'],
        field: 'section',
        source: source,
      ),
      kind: kind,
      text: _boundedText(
        normalized['text'],
        field: 'text',
        source: source,
        maximum: 2000,
      ),
      assetClassId: assetClassId,
      assetClassName: assetClassName,
      assetInstanceId: assetInstanceId,
      assetNumber: assetNumber,
      sourceReferences: _boundedStringList(
        normalized['sourceReferences'],
        field: 'sourceReferences',
        source: source,
        maximumItems: 12,
        maximumLength: 240,
      ),
      authorUid: _boundedText(
        normalized['authorUid'],
        field: 'authorUid',
        source: source,
        maximum: 256,
      ),
      authorName: _boundedText(
        normalized['authorName'],
        field: 'authorName',
        source: source,
        maximum: 256,
      ),
      authorRoleKeys: _boundedStringList(
        normalized['authorRoleKeys'],
        field: 'authorRoleKeys',
        source: source,
        maximumItems: 20,
        maximumLength: 80,
      ),
      createdAt: readRequiredPersistedDateTime(
        normalized['createdAt'],
        field: 'createdAt',
        source: source,
      ),
      addendumReason: addendumReason,
    );
  }
}

class MorningReviewAction {
  const MorningReviewAction({
    required this.actionId,
    required this.sessionId,
    required this.section,
    required this.text,
    required this.assetClassName,
    required this.assetNumber,
    required this.assigneeUid,
    required this.assigneeName,
    required this.assigneeRole,
    required this.dueAt,
    required this.status,
    required this.version,
    required this.acceptedAt,
    required this.acceptedByName,
    required this.completedAt,
    required this.completedByName,
    required this.completionNote,
    required this.createdAt,
    required this.createdByName,
  });

  final String actionId;
  final String sessionId;
  final MorningReviewSection section;
  final String text;
  final String? assetClassName;
  final String? assetNumber;
  final String? assigneeUid;
  final String? assigneeName;
  final String? assigneeRole;
  final DateTime? dueAt;
  final MorningReviewActionStatus status;
  final int version;
  final DateTime? acceptedAt;
  final String? acceptedByName;
  final DateTime? completedAt;
  final String? completedByName;
  final String? completionNote;
  final DateTime createdAt;
  final String createdByName;

  factory MorningReviewAction.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    bool embedded = false,
  }) {
    final normalized = _withoutEmbeddedDocumentId(map, documentId, embedded);
    final source = 'morning_review_actions/$documentId';
    _requireExactFields(normalized, const {
      'schemaVersion',
      'actionId',
      'sessionId',
      'originPlantDay',
      'section',
      'text',
      'assetClassId',
      'assetClassName',
      'assetInstanceId',
      'assetNumber',
      'assigneeUid',
      'assigneeName',
      'assigneeRole',
      'dueAt',
      'status',
      'version',
      'acceptedAt',
      'acceptedByUid',
      'acceptedByName',
      'completedAt',
      'completedByUid',
      'completedByName',
      'completionNote',
      'createdAt',
      'createdByUid',
      'createdByName',
      'updatedAt',
      'updatedByUid',
      'updatedByName',
      'expiresAt',
      'lastMutationId',
    }, source);
    _schemaOne(normalized, source);
    final id = _boundedText(
      normalized['actionId'],
      field: 'actionId',
      source: source,
      maximum: 80,
    );
    if (id != documentId ||
        normalized['originPlantDay'] != normalized['sessionId']) {
      throw PersistedDataFormatException(
        field: 'actionId',
        source: source,
        detail: 'action identity or origin day mismatch',
      );
    }
    final sessionId = _boundedText(
      normalized['sessionId'],
      field: 'sessionId',
      source: source,
      maximum: 10,
    );
    final assetClassId = _optionalBoundedText(
      normalized['assetClassId'],
      field: 'assetClassId',
      source: source,
      maximum: 180,
    );
    final assetClassName = _optionalBoundedText(
      normalized['assetClassName'],
      field: 'assetClassName',
      source: source,
      maximum: 120,
    );
    final assetInstanceId = _optionalBoundedText(
      normalized['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
      maximum: 180,
    );
    final assetNumber = _optionalBoundedText(
      normalized['assetNumber'],
      field: 'assetNumber',
      source: source,
      maximum: 40,
    );
    if ((assetClassId == null) != (assetClassName == null) ||
        (assetInstanceId == null) != (assetNumber == null) ||
        (assetInstanceId != null && assetClassId == null)) {
      throw PersistedDataFormatException(
        field: 'assetIdentity',
        source: source,
        detail: 'class and instance identity pairs must be complete',
      );
    }
    final assigneeUid = _optionalBoundedText(
      normalized['assigneeUid'],
      field: 'assigneeUid',
      source: source,
      maximum: 256,
    );
    final assigneeRole = _optionalBoundedText(
      normalized['assigneeRole'],
      field: 'assigneeRole',
      source: source,
      maximum: 80,
    );
    final assigneeName = _optionalBoundedText(
      normalized['assigneeName'],
      field: 'assigneeName',
      source: source,
      maximum: 256,
    );
    if ((assigneeUid == null) == (assigneeRole == null)) {
      throw PersistedDataFormatException(
        field: 'assigneeUid',
        source: source,
        detail: 'exactly one user or role assignee is required',
      );
    }
    if ((assigneeUid == null) != (assigneeName == null) ||
        (assigneeRole != null && assigneeName != null)) {
      throw PersistedDataFormatException(
        field: 'assigneeName',
        source: source,
        detail: 'must identify only a user assignee',
      );
    }
    if (assigneeRole != null &&
        !_morningReviewRoleKeys.contains(assigneeRole)) {
      throw PersistedDataFormatException(
        field: 'assigneeRole',
        source: source,
        detail: 'must be a canonical application role',
      );
    }
    final status = readRequiredPersistedEnum(
      MorningReviewActionStatus.values,
      normalized['status'],
      field: 'status',
      source: source,
    );
    final acceptedAt = readOptionalPersistedDateTime(
      normalized['acceptedAt'],
      field: 'acceptedAt',
      source: source,
    );
    final acceptedByName = _optionalBoundedText(
      normalized['acceptedByName'],
      field: 'acceptedByName',
      source: source,
      maximum: 256,
    );
    final acceptedByUid = _optionalBoundedText(
      normalized['acceptedByUid'],
      field: 'acceptedByUid',
      source: source,
      maximum: 256,
    );
    final completedAt = readOptionalPersistedDateTime(
      normalized['completedAt'],
      field: 'completedAt',
      source: source,
    );
    final completedByName = _optionalBoundedText(
      normalized['completedByName'],
      field: 'completedByName',
      source: source,
      maximum: 256,
    );
    final completedByUid = _optionalBoundedText(
      normalized['completedByUid'],
      field: 'completedByUid',
      source: source,
      maximum: 256,
    );
    final completionNote = _optionalBoundedText(
      normalized['completionNote'],
      field: 'completionNote',
      source: source,
      maximum: 1600,
    );
    final acceptedEvidence =
        acceptedAt != null && acceptedByUid != null && acceptedByName != null;
    final anyAcceptedEvidence =
        acceptedAt != null || acceptedByUid != null || acceptedByName != null;
    final completedEvidence =
        completedAt != null &&
        completedByUid != null &&
        completedByName != null &&
        completionNote != null;
    final anyCompletedEvidence =
        completedAt != null ||
        completedByUid != null ||
        completedByName != null ||
        completionNote != null;
    final expiresAt = readOptionalPersistedDateTime(
      normalized['expiresAt'],
      field: 'expiresAt',
      source: source,
    );
    readRequiredPersistedDateTime(
      normalized['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    _boundedText(
      normalized['createdByUid'],
      field: 'createdByUid',
      source: source,
      maximum: 256,
    );
    _boundedText(
      normalized['updatedByUid'],
      field: 'updatedByUid',
      source: source,
      maximum: 256,
    );
    _boundedText(
      normalized['updatedByName'],
      field: 'updatedByName',
      source: source,
      maximum: 256,
    );
    _boundedText(
      normalized['lastMutationId'],
      field: 'lastMutationId',
      source: source,
      maximum: 80,
    );
    if (anyAcceptedEvidence != acceptedEvidence ||
        anyCompletedEvidence != completedEvidence ||
        (status == MorningReviewActionStatus.open &&
            (anyAcceptedEvidence ||
                anyCompletedEvidence ||
                expiresAt != null)) ||
        (status == MorningReviewActionStatus.accepted &&
            (!acceptedEvidence || anyCompletedEvidence || expiresAt != null)) ||
        (status == MorningReviewActionStatus.completed &&
            (!completedEvidence || expiresAt == null))) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'action lifecycle evidence is inconsistent',
      );
    }
    return MorningReviewAction(
      actionId: id,
      sessionId: sessionId,
      section: readRequiredPersistedEnum(
        MorningReviewSection.values,
        normalized['section'],
        field: 'section',
        source: source,
      ),
      text: _boundedText(
        normalized['text'],
        field: 'text',
        source: source,
        maximum: 1200,
      ),
      assetClassName: assetClassName,
      assetNumber: assetNumber,
      assigneeUid: assigneeUid,
      assigneeName: assigneeName,
      assigneeRole: assigneeRole,
      dueAt: readOptionalPersistedDateTime(
        normalized['dueAt'],
        field: 'dueAt',
        source: source,
      ),
      status: status,
      version: readRequiredPersistedInt(
        normalized['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      acceptedAt: acceptedAt,
      acceptedByName: acceptedByName,
      completedAt: completedAt,
      completedByName: completedByName,
      completionNote: completionNote,
      createdAt: readRequiredPersistedDateTime(
        normalized['createdAt'],
        field: 'createdAt',
        source: source,
      ),
      createdByName: _boundedText(
        normalized['createdByName'],
        field: 'createdByName',
        source: source,
        maximum: 256,
      ),
    );
  }
}

class MorningReviewStandingConcern {
  const MorningReviewStandingConcern({
    required this.concernId,
    required this.title,
    required this.detail,
    required this.criticality,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.createdByName,
    required this.resolvedAt,
    required this.resolvedByName,
    required this.resolutionReason,
  });

  final String concernId;
  final String title;
  final String detail;
  final MorningReviewConcernCriticality criticality;
  final MorningReviewConcernStatus status;
  final int version;
  final DateTime createdAt;
  final String createdByName;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String? resolutionReason;

  factory MorningReviewStandingConcern.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    bool embedded = false,
  }) {
    final normalized = _withoutEmbeddedDocumentId(map, documentId, embedded);
    final source = 'morning_review_standing_concerns/$documentId';
    _requireExactFields(normalized, const {
      'schemaVersion',
      'concernId',
      'originSessionId',
      'title',
      'detail',
      'criticality',
      'status',
      'version',
      'createdAt',
      'createdByUid',
      'createdByName',
      'resolvedAt',
      'resolvedByUid',
      'resolvedByName',
      'resolutionReason',
      'updatedAt',
      'updatedByUid',
      'updatedByName',
      'expiresAt',
      'lastMutationId',
    }, source);
    _schemaOne(normalized, source);
    final id = _boundedText(
      normalized['concernId'],
      field: 'concernId',
      source: source,
      maximum: 80,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'concernId',
        source: source,
        detail: 'must match the document identity',
      );
    }
    _boundedText(
      normalized['originSessionId'],
      field: 'originSessionId',
      source: source,
      maximum: 10,
    );
    final status = readRequiredPersistedEnum(
      MorningReviewConcernStatus.values,
      normalized['status'],
      field: 'status',
      source: source,
    );
    final resolvedAt = readOptionalPersistedDateTime(
      normalized['resolvedAt'],
      field: 'resolvedAt',
      source: source,
    );
    final resolvedByUid = _optionalBoundedText(
      normalized['resolvedByUid'],
      field: 'resolvedByUid',
      source: source,
      maximum: 256,
    );
    final resolvedByName = _optionalBoundedText(
      normalized['resolvedByName'],
      field: 'resolvedByName',
      source: source,
      maximum: 256,
    );
    final resolutionReason = _optionalBoundedText(
      normalized['resolutionReason'],
      field: 'resolutionReason',
      source: source,
      maximum: 1600,
    );
    final expiresAt = readOptionalPersistedDateTime(
      normalized['expiresAt'],
      field: 'expiresAt',
      source: source,
    );
    final resolvedEvidence =
        resolvedAt != null &&
        resolvedByUid != null &&
        resolvedByName != null &&
        resolutionReason != null;
    final anyResolvedEvidence =
        resolvedAt != null ||
        resolvedByUid != null ||
        resolvedByName != null ||
        resolutionReason != null;
    if ((status == MorningReviewConcernStatus.active &&
            (anyResolvedEvidence || expiresAt != null)) ||
        (status == MorningReviewConcernStatus.resolved &&
            (!resolvedEvidence || expiresAt == null))) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'concern lifecycle evidence is inconsistent',
      );
    }
    _boundedText(
      normalized['createdByUid'],
      field: 'createdByUid',
      source: source,
      maximum: 256,
    );
    readRequiredPersistedDateTime(
      normalized['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    _boundedText(
      normalized['updatedByUid'],
      field: 'updatedByUid',
      source: source,
      maximum: 256,
    );
    _boundedText(
      normalized['updatedByName'],
      field: 'updatedByName',
      source: source,
      maximum: 256,
    );
    _boundedText(
      normalized['lastMutationId'],
      field: 'lastMutationId',
      source: source,
      maximum: 80,
    );
    return MorningReviewStandingConcern(
      concernId: id,
      title: _boundedText(
        normalized['title'],
        field: 'title',
        source: source,
        maximum: 160,
      ),
      detail: _boundedText(
        normalized['detail'],
        field: 'detail',
        source: source,
        maximum: 1600,
      ),
      criticality: readRequiredPersistedEnum(
        MorningReviewConcernCriticality.values,
        normalized['criticality'],
        field: 'criticality',
        source: source,
      ),
      status: status,
      version: readRequiredPersistedInt(
        normalized['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      createdAt: readRequiredPersistedDateTime(
        normalized['createdAt'],
        field: 'createdAt',
        source: source,
      ),
      createdByName: _boundedText(
        normalized['createdByName'],
        field: 'createdByName',
        source: source,
        maximum: 256,
      ),
      resolvedAt: resolvedAt,
      resolvedByName: resolvedByName,
      resolutionReason: resolutionReason,
    );
  }
}

class MorningReviewConcernCheck {
  const MorningReviewConcernCheck({
    required this.checkId,
    required this.sessionId,
    required this.concernId,
    required this.concernTitle,
    required this.state,
    required this.note,
    required this.checkedAt,
    required this.checkedByName,
  });

  final String checkId;
  final String sessionId;
  final String concernId;
  final String concernTitle;
  final MorningReviewConcernCheckState state;
  final String note;
  final DateTime checkedAt;
  final String checkedByName;

  factory MorningReviewConcernCheck.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    bool embedded = false,
  }) {
    final normalized = _withoutEmbeddedDocumentId(map, documentId, embedded);
    final source = 'morning_review_concern_checks/$documentId';
    _requireExactFields(normalized, const {
      'schemaVersion',
      'checkId',
      'sessionId',
      'concernId',
      'concernTitle',
      'state',
      'note',
      'checkedAt',
      'checkedByUid',
      'checkedByName',
      'expiresAt',
    }, source);
    _schemaOne(normalized, source);
    final id = _boundedText(
      normalized['checkId'],
      field: 'checkId',
      source: source,
      maximum: 300,
    );
    final sessionId = _boundedText(
      normalized['sessionId'],
      field: 'sessionId',
      source: source,
      maximum: 10,
    );
    final concernId = _boundedText(
      normalized['concernId'],
      field: 'concernId',
      source: source,
      maximum: 80,
    );
    if (id != documentId || id != '${sessionId}_$concernId') {
      throw PersistedDataFormatException(
        field: 'checkId',
        source: source,
        detail: 'must match the document identity',
      );
    }
    readRequiredPersistedDateTime(
      normalized['expiresAt'],
      field: 'expiresAt',
      source: source,
    );
    _boundedText(
      normalized['checkedByUid'],
      field: 'checkedByUid',
      source: source,
      maximum: 256,
    );
    return MorningReviewConcernCheck(
      checkId: id,
      sessionId: sessionId,
      concernId: concernId,
      concernTitle: _boundedText(
        normalized['concernTitle'],
        field: 'concernTitle',
        source: source,
        maximum: 160,
      ),
      state: readRequiredPersistedEnum(
        MorningReviewConcernCheckState.values,
        normalized['state'],
        field: 'state',
        source: source,
      ),
      note: _boundedText(
        normalized['note'],
        field: 'note',
        source: source,
        maximum: 1600,
      ),
      checkedAt: readRequiredPersistedDateTime(
        normalized['checkedAt'],
        field: 'checkedAt',
        source: source,
      ),
      checkedByName: _boundedText(
        normalized['checkedByName'],
        field: 'checkedByName',
        source: source,
        maximum: 256,
      ),
    );
  }
}

class MorningReviewDocument {
  MorningReviewDocument({
    required this.sessionId,
    required this.plantDay,
    required this.status,
    required this.title,
    required this.facilitatorName,
    required this.facilitatorHistory,
    required this.sourceCapturedAt,
    required this.sourceCaptureState,
    required this.sourceCollectionsAtLimit,
    required this.sourceFactDigest,
    required this.documentDigest,
    required this.sourceFacts,
    required this.entries,
    required this.actions,
    required this.participants,
    required this.standingConcerns,
    required this.standingConcernChecks,
    required this.finalSummary,
    required this.finalizedAt,
    required this.finalizedByName,
    required this.expiresAt,
  });

  final String sessionId;
  final String plantDay;
  final MorningReviewStatus status;
  final String title;
  final String? facilitatorName;
  final List<MorningReviewFacilitatorTransition> facilitatorHistory;
  final DateTime? sourceCapturedAt;
  final MorningReviewSourceCaptureState sourceCaptureState;
  final List<String> sourceCollectionsAtLimit;
  final String? sourceFactDigest;
  final String? documentDigest;
  final List<MorningReviewSourceFact> sourceFacts;
  final List<MorningReviewEntry> entries;
  final List<MorningReviewAction> actions;
  final List<MorningReviewParticipant> participants;
  final List<MorningReviewStandingConcern> standingConcerns;
  final List<MorningReviewConcernCheck> standingConcernChecks;
  final String finalSummary;
  final DateTime finalizedAt;
  final String finalizedByName;
  final DateTime expiresAt;

  factory MorningReviewDocument.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'morning_review_documents/$documentId';
    _requireExactFields(map, const {
      'schemaVersion',
      'sessionId',
      'plantDay',
      'status',
      'title',
      'facilitatorUid',
      'facilitatorName',
      'facilitatorHistory',
      'sourceCapturedAt',
      'sourceCaptureState',
      'sourceCollectionsAtLimit',
      'sourceFactDigest',
      'documentDigest',
      'sourceFacts',
      'entries',
      'actions',
      'participants',
      'standingConcerns',
      'standingConcernChecks',
      'finalSummary',
      'finalizedAt',
      'finalizedByUid',
      'finalizedByName',
      'expiresAt',
    }, source);
    _schemaOne(map, source);
    _boundedText(
      map['facilitatorUid'],
      field: 'facilitatorUid',
      source: source,
      maximum: 256,
    );
    _boundedText(
      map['finalizedByUid'],
      field: 'finalizedByUid',
      source: source,
      maximum: 256,
    );
    final sessionId = _boundedText(
      map['sessionId'],
      field: 'sessionId',
      source: source,
      maximum: 10,
    );
    if (sessionId != documentId || map['plantDay'] != documentId) {
      throw PersistedDataFormatException(
        field: 'sessionId',
        source: source,
        detail: 'document, session and plant day identities must match',
      );
    }
    final status = readRequiredPersistedEnum(
      MorningReviewStatus.values,
      map['status'],
      field: 'status',
      source: source,
    );
    if (status == MorningReviewStatus.open) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'a frozen document cannot remain open',
      );
    }
    final sources = _objectList(
      map['sourceFacts'],
      field: 'sourceFacts',
      source: source,
      maximum: 220,
    );
    final entries = _objectList(
      map['entries'],
      field: 'entries',
      source: source,
      maximum: 180,
    );
    final actions = _objectList(
      map['actions'],
      field: 'actions',
      source: source,
      maximum: 100,
    );
    final participants = _objectList(
      map['participants'],
      field: 'participants',
      source: source,
      maximum: 100,
    );
    final concerns = _objectList(
      map['standingConcerns'],
      field: 'standingConcerns',
      source: source,
      maximum: 250,
    );
    final checks = _objectList(
      map['standingConcernChecks'],
      field: 'standingConcernChecks',
      source: source,
      maximum: 180,
    );
    final facilitatorHistory = _objectList(
      map['facilitatorHistory'],
      field: 'facilitatorHistory',
      source: source,
      maximum: 20,
    );
    final document = MorningReviewDocument(
      sessionId: sessionId,
      plantDay: documentId,
      status: status,
      title: _boundedText(
        map['title'],
        field: 'title',
        source: source,
        maximum: 160,
      ),
      facilitatorName: _optionalBoundedText(
        map['facilitatorName'],
        field: 'facilitatorName',
        source: source,
        maximum: 256,
      ),
      facilitatorHistory: List.unmodifiable(
        facilitatorHistory.asMap().entries.map(
          (entry) => MorningReviewFacilitatorTransition.fromMap(
            entry.value,
            source: '$source/facilitatorHistory[${entry.key}]',
          ),
        ),
      ),
      sourceCapturedAt: readOptionalPersistedDateTime(
        map['sourceCapturedAt'],
        field: 'sourceCapturedAt',
        source: source,
      ),
      sourceCaptureState: readRequiredPersistedEnum(
        MorningReviewSourceCaptureState.values,
        map['sourceCaptureState'],
        field: 'sourceCaptureState',
        source: source,
      ),
      sourceCollectionsAtLimit: _boundedStringList(
        map['sourceCollectionsAtLimit'],
        field: 'sourceCollectionsAtLimit',
        source: source,
        maximumItems: 10,
        maximumLength: 120,
      ),
      sourceFactDigest: _optionalBoundedText(
        map['sourceFactDigest'],
        field: 'sourceFactDigest',
        source: source,
        maximum: 100,
      ),
      documentDigest: _optionalBoundedText(
        map['documentDigest'],
        field: 'documentDigest',
        source: source,
        maximum: 100,
      ),
      sourceFacts: List.unmodifiable(
        sources.asMap().entries.map(
          (entry) => MorningReviewSourceFact.fromMap(
            entry.value,
            source: '$source/sourceFacts[${entry.key}]',
          ),
        ),
      ),
      entries: List.unmodifiable(
        entries.map(
          (entry) => MorningReviewEntry.fromMap(
            entry,
            _embeddedId(entry, 'entryId', source),
            embedded: true,
          ),
        ),
      ),
      actions: List.unmodifiable(
        actions.map(
          (entry) => MorningReviewAction.fromMap(
            entry,
            _embeddedId(entry, 'actionId', source),
            embedded: true,
          ),
        ),
      ),
      participants: List.unmodifiable(
        participants.map(
          (entry) => MorningReviewParticipant.fromMap(
            entry,
            _embeddedId(entry, 'participantId', source),
            embedded: true,
          ),
        ),
      ),
      standingConcerns: List.unmodifiable(
        concerns.map(
          (entry) => MorningReviewStandingConcern.fromMap(
            entry,
            _embeddedId(entry, 'concernId', source),
            embedded: true,
          ),
        ),
      ),
      standingConcernChecks: List.unmodifiable(
        checks.map(
          (entry) => MorningReviewConcernCheck.fromMap(
            entry,
            _embeddedId(entry, 'checkId', source),
            embedded: true,
          ),
        ),
      ),
      finalSummary: _boundedText(
        map['finalSummary'],
        field: 'finalSummary',
        source: source,
        maximum: 2000,
      ),
      finalizedAt: readRequiredPersistedDateTime(
        map['finalizedAt'],
        field: 'finalizedAt',
        source: source,
      ),
      finalizedByName: _boundedText(
        map['finalizedByName'],
        field: 'finalizedByName',
        source: source,
        maximum: 256,
      ),
      expiresAt: readRequiredPersistedDateTime(
        map['expiresAt'],
        field: 'expiresAt',
        source: source,
      ),
    );
    final sourceIds = document.sourceFacts.map((fact) => fact.factId).toSet();
    final concernIds =
        document.standingConcerns.map((concern) => concern.concernId).toSet();
    final populationsAreUnique =
        sourceIds.length == document.sourceFacts.length &&
        concernIds.length == document.standingConcerns.length &&
        document.entries.map((entry) => entry.entryId).toSet().length ==
            document.entries.length &&
        document.actions.map((action) => action.actionId).toSet().length ==
            document.actions.length &&
        document.participants
                .map((participant) => participant.participantId)
                .toSet()
                .length ==
            document.participants.length &&
        document.standingConcernChecks
                .map((check) => check.checkId)
                .toSet()
                .length ==
            document.standingConcernChecks.length;
    final embeddedIdentityMismatch =
        document.entries.any((entry) => entry.sessionId != sessionId) ||
        document.actions.any((action) => action.sessionId != sessionId) ||
        document.participants.any(
          (participant) => participant.sessionId != sessionId,
        ) ||
        document.standingConcernChecks.any(
          (check) => check.sessionId != sessionId,
        );
    final unknownSourceReference = document.entries.any(
      (entry) => entry.sourceReferences.any(
        (reference) => !sourceIds.contains(reference),
      ),
    );
    final unknownConcernCheck = document.standingConcernChecks.any(
      (check) => !concernIds.contains(check.concernId),
    );
    if (!populationsAreUnique ||
        embeddedIdentityMismatch ||
        unknownSourceReference ||
        unknownConcernCheck) {
      throw PersistedDataFormatException(
        field: 'entries',
        source: source,
        detail: 'embedded records do not belong to this frozen source set',
      );
    }
    final completeCapture =
        document.sourceCapturedAt != null &&
        document.sourceCaptureState !=
            MorningReviewSourceCaptureState.notApplicable &&
        document.sourceFactDigest != null &&
        RegExp(
          r'^morningreviewsource1-sha256:[0-9a-f]{64}$',
        ).hasMatch(document.sourceFactDigest!) &&
        document.documentDigest != null &&
        RegExp(
          r'^morningreviewdocument1-sha256:[0-9a-f]{64}$',
        ).hasMatch(document.documentDigest!) &&
        ((document.sourceCaptureState ==
                    MorningReviewSourceCaptureState.complete &&
                document.sourceCollectionsAtLimit.isEmpty) ||
            (document.sourceCaptureState ==
                    MorningReviewSourceCaptureState.bounded &&
                document.sourceCollectionsAtLimit.isNotEmpty));
    final notHeldCapture =
        document.sourceCapturedAt == null &&
        document.sourceCaptureState ==
            MorningReviewSourceCaptureState.notApplicable &&
        document.sourceCollectionsAtLimit.isEmpty &&
        document.sourceFactDigest == null &&
        document.documentDigest == null &&
        document.sourceFacts.isEmpty &&
        document.entries.isEmpty &&
        document.actions.isEmpty &&
        document.participants.isEmpty &&
        document.standingConcerns.isEmpty &&
        document.standingConcernChecks.isEmpty &&
        document.facilitatorHistory.isEmpty;
    if (!document.expiresAt.isAfter(document.finalizedAt) ||
        (status == MorningReviewStatus.finalized && !completeCapture) ||
        (status == MorningReviewStatus.notHeld && !notHeldCapture)) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'frozen lifecycle and retention evidence are inconsistent',
      );
    }
    return document;
  }
}

String currentIndiaPlantDay([DateTime? clock]) {
  final india = (clock ?? DateTime.now()).toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  String two(int value) => value.toString().padLeft(2, '0');
  return '${india.year}-${two(india.month)}-${two(india.day)}';
}

int currentIndiaMinuteOfDay([DateTime? clock]) {
  final india = (clock ?? DateTime.now()).toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  return india.hour * 60 + india.minute;
}

void _schemaOne(Map<String, dynamic> map, String source) {
  if (readRequiredPersistedInt(
        map['schemaVersion'],
        field: 'schemaVersion',
        source: source,
      ) !=
      1) {
    throw PersistedDataFormatException(
      field: 'schemaVersion',
      source: source,
      detail: 'unsupported Morning Review schema',
    );
  }
}

String _boundedText(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  final result = readRequiredPersistedString(
    value,
    field: field,
    source: source,
  );
  if (result.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'exceeds $maximum characters',
    );
  }
  return result;
}

String? _optionalBoundedText(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  final result = readOptionalPersistedString(
    value,
    field: field,
    source: source,
  );
  if (result != null && result.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'exceeds $maximum characters',
    );
  }
  return result;
}

List<String> _boundedStringList(
  dynamic value, {
  required String field,
  required String source,
  required int maximumItems,
  required int maximumLength,
}) {
  final result = readOptionalPersistedStringList(
    value,
    field: field,
    source: source,
  );
  if (result.length > maximumItems ||
      result.any((item) => item.length > maximumLength) ||
      result.toSet().length != result.length) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be a bounded unique string list',
    );
  }
  return List.unmodifiable(result);
}

List<Map<String, dynamic>> _objectList(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  if (value is! List || value.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be an object list with at most $maximum entries',
    );
  }
  return value
      .asMap()
      .entries
      .map((entry) {
        try {
          return Map<String, dynamic>.from(entry.value as Map);
        } catch (_) {
          throw PersistedDataFormatException(
            field: '$field[${entry.key}]',
            source: source,
            detail: 'must be an object with string keys',
          );
        }
      })
      .toList(growable: false);
}

Map<String, dynamic> _withoutEmbeddedDocumentId(
  Map<String, dynamic> map,
  String documentId,
  bool embedded,
) {
  if (!embedded) return map;
  if (map['documentId'] != documentId) {
    throw PersistedDataFormatException(
      field: 'documentId',
      detail: 'embedded document identity mismatch',
    );
  }
  return Map<String, dynamic>.from(map)..remove('documentId');
}

String _embeddedId(Map<String, dynamic> map, String field, String source) {
  final id = _boundedText(
    map[field],
    field: field,
    source: source,
    maximum: 300,
  );
  if (map['documentId'] != id) {
    throw PersistedDataFormatException(
      field: 'documentId',
      source: source,
      detail: 'must match $field',
    );
  }
  return id;
}

void _requireExactFields(
  Map<String, dynamic> map,
  Set<String> expected,
  String source,
) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    final missing = expected.difference(actual).toList()..sort();
    final extra = actual.difference(expected).toList()..sort();
    throw PersistedDataFormatException(
      field: 'recordShape',
      source: source,
      detail: 'missing=$missing extra=$extra',
    );
  }
}
