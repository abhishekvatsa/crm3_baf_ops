part of 'template_governance_model.dart';

final RegExp _templateContentHashPattern = RegExp(
  r'^(?:tg2-sha256:[0-9a-f]{64}|tg1-fnv1a32:[0-9a-f]{8})$',
);

const List<String> _closureProjectionFields = <String>[
  'closureReviewConfirmed',
  'closureCriticalModuleCount',
  'closureReviewConfirmedByUid',
  'closureReviewConfirmedByName',
  'closureReviewConfirmedAt',
];

TemplatePackage readRemoteTemplatePackage(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'template_packages/$documentId';
  final firestoreId = _readGovernanceDocumentIdentity(
    map,
    documentId: documentId,
    source: source,
  );
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  final deletedAt = readOptionalPersistedDateTime(
    map['deletedAt'],
    field: 'deletedAt',
    source: source,
  );
  if (isDeleted) {
    requireRemoteTombstoneDeletedAt(
      deletedAt,
      entityLabel: 'template package',
      firestoreId: firestoreId,
    );
  }

  final lifecycleStatus = readRequiredPersistedEnum(
    TemplatePackageLifecycleStatus.values,
    map['lifecycleStatus'],
    field: 'lifecycleStatus',
    source: source,
  );
  final createdAt = readRequiredPersistedDateTime(
    map['createdAt'],
    field: 'createdAt',
    source: source,
  );
  final updatedAt = readRequiredPersistedDateTime(
    map['updatedAt'],
    field: 'updatedAt',
    source: source,
  );
  final retiredAt = readOptionalPersistedDateTime(
    map['retiredAt'],
    field: 'retiredAt',
    source: source,
  );
  final createdByUid = _readGovernanceRequiredText(
    map['createdByUid'],
    field: 'createdByUid',
    source: source,
    maximum: 512,
  );
  final createdByName = _readGovernanceOptionalText(
    map['createdByName'],
    field: 'createdByName',
    source: source,
    maximum: 500,
  );
  final updatedByUid = _readGovernanceRequiredText(
    map['updatedByUid'],
    field: 'updatedByUid',
    source: source,
    maximum: 512,
  );
  final updatedByName = _readGovernanceOptionalText(
    map['updatedByName'],
    field: 'updatedByName',
    source: source,
    maximum: 500,
  );
  final retiredByUid = _readGovernanceOptionalText(
    map['retiredByUid'],
    field: 'retiredByUid',
    source: source,
    maximum: 512,
  );
  final retiredByName = _readGovernanceOptionalText(
    map['retiredByName'],
    field: 'retiredByName',
    source: source,
    maximum: 500,
  );
  final retireReason = _readGovernanceOptionalText(
    map['retireReason'],
    field: 'retireReason',
    source: source,
    maximum: 2000,
  );
  final deletedByUid = _readGovernanceOptionalText(
    map['deletedByUid'],
    field: 'deletedByUid',
    source: source,
    maximum: 512,
  );
  final deletedByName = _readGovernanceOptionalText(
    map['deletedByName'],
    field: 'deletedByName',
    source: source,
    maximum: 500,
  );
  final deleteReason = _readGovernanceOptionalText(
    map['deleteReason'],
    field: 'deleteReason',
    source: source,
    maximum: 2000,
  );

  _requireGovernanceTimeline(
    createdAt: createdAt,
    updatedAt: updatedAt,
    optionalTimes: <String, DateTime?>{
      'retiredAt': retiredAt,
      'deletedAt': deletedAt,
    },
    source: source,
  );
  _requirePackageLifecycle(
    lifecycleStatus: lifecycleStatus,
    retiredAt: retiredAt,
    retiredByUid: retiredByUid,
    retiredByName: retiredByName,
    retireReason: retireReason,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
    deletedByUid: deletedByUid,
    deletedByName: deletedByName,
    deleteReason: deleteReason,
    source: source,
  );
  _requireGovernanceActorNamePair(
    uid: createdByUid,
    name: createdByName,
    uidField: 'createdByUid',
    nameField: 'createdByName',
    source: source,
  );
  _requireGovernanceActorNamePair(
    uid: updatedByUid,
    name: updatedByName,
    uidField: 'updatedByUid',
    nameField: 'updatedByName',
    source: source,
  );

  return TemplatePackage()
    ..firestoreId = firestoreId
    ..packageCode = _readGovernanceRequiredText(
      map['packageCode'],
      field: 'packageCode',
      source: source,
      maximum: 160,
    )
    ..title = _readGovernanceRequiredText(
      map['title'],
      field: 'title',
      source: source,
      maximum: 500,
    )
    ..description = _readGovernanceOptionalText(
      map['description'],
      field: 'description',
      source: source,
      maximum: 4000,
    )
    ..assetType = _readGovernanceOptionalText(
      map['assetType'],
      field: 'assetType',
      source: source,
      maximum: 200,
    )
    ..assetNumberScope = _readGovernanceOptionalText(
      map['assetNumberScope'],
      field: 'assetNumberScope',
      source: source,
      maximum: 500,
    )
    ..disciplineScope = _readGovernanceOptionalText(
      map['disciplineScope'],
      field: 'disciplineScope',
      source: source,
      maximum: 500,
    )
    ..lifecycleStatus = lifecycleStatus
    ..activeVersionFirestoreId = _readGovernanceOptionalText(
      map['activeVersionFirestoreId'],
      field: 'activeVersionFirestoreId',
      source: source,
      maximum: 512,
    )
    ..latestVersionNumber = readRequiredPersistedInt(
      map['latestVersionNumber'],
      field: 'latestVersionNumber',
      source: source,
      minimum: 0,
    )
    ..createdByUid = createdByUid
    ..createdByName = createdByName
    ..updatedByUid = updatedByUid
    ..updatedByName = updatedByName
    ..retiredByUid = retiredByUid
    ..retiredByName = retiredByName
    ..retiredAt = retiredAt
    ..retireReason = retireReason
    ..isDeleted = isDeleted
    ..deletedAt = deletedAt
    ..deletedByUid = deletedByUid
    ..deletedByName = deletedByName
    ..deleteReason = deleteReason
    ..version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    )
    ..schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    )
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..targetRefs = _readGovernanceStringList(
      map['targetRefs'],
      field: 'targetRefs',
      source: source,
    )
    ..deviceTagRefs = _readGovernanceStringList(
      map['deviceTagRefs'],
      field: 'deviceTagRefs',
      source: source,
    )
    ..safetyClass = _readGovernanceOptionalText(
      map['safetyClass'],
      field: 'safetyClass',
      source: source,
      maximum: 200,
    )
    ..safetyGatePolicyJson = _readOptionalGovernanceJsonObjectText(
      map['safetyGatePolicyJson'],
      field: 'safetyGatePolicyJson',
      source: source,
    )
    ..procedureRefs = _readGovernanceStringList(
      map['procedureRefs'],
      field: 'procedureRefs',
      source: source,
    )
    ..operationalStatePreconditions = _readGovernanceStringList(
      map['operationalStatePreconditions'],
      field: 'operationalStatePreconditions',
      source: source,
    )
    ..metadataJson = _readOptionalGovernanceJsonObjectText(
      map['metadataJson'],
      field: 'metadataJson',
      source: source,
    )
    ..isSynced = true;
}

TemplateVersion readRemoteTemplateVersion(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'template_versions/$documentId';
  final firestoreId = _readGovernanceDocumentIdentity(
    map,
    documentId: documentId,
    source: source,
  );
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  final deletedAt = readOptionalPersistedDateTime(
    map['deletedAt'],
    field: 'deletedAt',
    source: source,
  );
  if (isDeleted) {
    requireRemoteTombstoneDeletedAt(
      deletedAt,
      entityLabel: 'template version',
      firestoreId: firestoreId,
    );
  }

  final status = readRequiredPersistedEnum(
    TemplateVersionStatus.values,
    map['status'],
    field: 'status',
    source: source,
  );
  final jobTemplateSnapshotJson = _readRequiredGovernanceJsonObjectText(
    map['jobTemplateSnapshotJson'],
    field: 'jobTemplateSnapshotJson',
    source: source,
  );
  final moduleSnapshotsJson = _readRequiredGovernanceJsonObjectListText(
    map['moduleSnapshotsJson'],
    field: 'moduleSnapshotsJson',
    source: source,
  );
  final fieldDefinitionsJson = _readRequiredGovernanceJsonObjectListText(
    map['fieldDefinitionsJson'],
    field: 'fieldDefinitionsJson',
    source: source,
  );
  final checklistJson = _readRequiredGovernanceJsonObjectListText(
    map['checklistJson'],
    field: 'checklistJson',
    source: source,
  );
  final inferredClosureState = _readStrictClosureReviewState(
    jobTemplateSnapshotJson: jobTemplateSnapshotJson,
    moduleSnapshotsJson: moduleSnapshotsJson,
    source: source,
  );
  final closureState = _readClosureProjection(
    map,
    inferred: inferredClosureState,
    source: source,
  );
  final createdAt = readRequiredPersistedDateTime(
    map['createdAt'],
    field: 'createdAt',
    source: source,
  );
  final updatedAt = readRequiredPersistedDateTime(
    map['updatedAt'],
    field: 'updatedAt',
    source: source,
  );
  final publishedAt = readOptionalPersistedDateTime(
    map['publishedAt'],
    field: 'publishedAt',
    source: source,
  );
  final retiredAt = readOptionalPersistedDateTime(
    map['retiredAt'],
    field: 'retiredAt',
    source: source,
  );
  final createdByUid = _readGovernanceRequiredText(
    map['createdByUid'],
    field: 'createdByUid',
    source: source,
    maximum: 512,
  );
  final createdByName = _readGovernanceOptionalText(
    map['createdByName'],
    field: 'createdByName',
    source: source,
    maximum: 500,
  );
  final updatedByUid = _readGovernanceRequiredText(
    map['updatedByUid'],
    field: 'updatedByUid',
    source: source,
    maximum: 512,
  );
  final updatedByName = _readGovernanceOptionalText(
    map['updatedByName'],
    field: 'updatedByName',
    source: source,
    maximum: 500,
  );
  final publishedByUid = _readGovernanceOptionalText(
    map['publishedByUid'],
    field: 'publishedByUid',
    source: source,
    maximum: 512,
  );
  final publishedByName = _readGovernanceOptionalText(
    map['publishedByName'],
    field: 'publishedByName',
    source: source,
    maximum: 500,
  );
  final retiredByUid = _readGovernanceOptionalText(
    map['retiredByUid'],
    field: 'retiredByUid',
    source: source,
    maximum: 512,
  );
  final retiredByName = _readGovernanceOptionalText(
    map['retiredByName'],
    field: 'retiredByName',
    source: source,
    maximum: 500,
  );
  final retireReason = _readGovernanceOptionalText(
    map['retireReason'],
    field: 'retireReason',
    source: source,
    maximum: 2000,
  );
  final deletedByUid = _readGovernanceOptionalText(
    map['deletedByUid'],
    field: 'deletedByUid',
    source: source,
    maximum: 512,
  );
  final deletedByName = _readGovernanceOptionalText(
    map['deletedByName'],
    field: 'deletedByName',
    source: source,
    maximum: 500,
  );
  final deleteReason = _readGovernanceOptionalText(
    map['deleteReason'],
    field: 'deleteReason',
    source: source,
    maximum: 2000,
  );
  final contentHash = _readGovernanceOptionalText(
    map['contentHash'],
    field: 'contentHash',
    source: source,
    maximum: 128,
  );
  if (contentHash != null &&
      !_templateContentHashPattern.hasMatch(contentHash)) {
    throw PersistedDataFormatException(
      field: 'contentHash',
      source: source,
      detail: 'unsupported template content hash',
    );
  }
  if (status != TemplateVersionStatus.draft && contentHash == null) {
    throw PersistedDataFormatException(
      field: 'contentHash',
      source: source,
      detail: 'non-draft versions require a governed content hash',
    );
  }

  _requireGovernanceTimeline(
    createdAt: createdAt,
    updatedAt: updatedAt,
    optionalTimes: <String, DateTime?>{
      'closureReviewConfirmedAt': closureState.confirmedAt,
      'publishedAt': publishedAt,
      'retiredAt': retiredAt,
      'deletedAt': deletedAt,
    },
    source: source,
  );
  _requireVersionLifecycle(
    status: status,
    closureState: closureState,
    publishedAt: publishedAt,
    publishedByUid: publishedByUid,
    publishedByName: publishedByName,
    retiredAt: retiredAt,
    retiredByUid: retiredByUid,
    retiredByName: retiredByName,
    retireReason: retireReason,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
    deletedByUid: deletedByUid,
    deletedByName: deletedByName,
    deleteReason: deleteReason,
    source: source,
  );
  _requireGovernanceActorNamePair(
    uid: createdByUid,
    name: createdByName,
    uidField: 'createdByUid',
    nameField: 'createdByName',
    source: source,
  );
  _requireGovernanceActorNamePair(
    uid: updatedByUid,
    name: updatedByName,
    uidField: 'updatedByUid',
    nameField: 'updatedByName',
    source: source,
  );

  return TemplateVersion()
    ..firestoreId = firestoreId
    ..packageFirestoreId = _readGovernanceRequiredText(
      map['packageFirestoreId'],
      field: 'packageFirestoreId',
      source: source,
      maximum: 512,
    )
    ..versionNumber = readRequiredPersistedInt(
      map['versionNumber'],
      field: 'versionNumber',
      source: source,
      minimum: 1,
    )
    ..versionLabel = _readGovernanceOptionalText(
      map['versionLabel'],
      field: 'versionLabel',
      source: source,
      maximum: 500,
    )
    ..status = status
    ..sourceVersionFirestoreId = _readGovernanceOptionalText(
      map['sourceVersionFirestoreId'],
      field: 'sourceVersionFirestoreId',
      source: source,
      maximum: 512,
    )
    ..contentHash = contentHash
    ..jobTemplateSnapshotJson = jobTemplateSnapshotJson
    ..moduleSnapshotsJson = moduleSnapshotsJson
    ..fieldDefinitionsJson = fieldDefinitionsJson
    ..checklistJson = checklistJson
    ..releaseNotes = _readGovernanceOptionalText(
      map['releaseNotes'],
      field: 'releaseNotes',
      source: source,
      maximum: 8000,
    )
    ..changeSummary = _readGovernanceOptionalText(
      map['changeSummary'],
      field: 'changeSummary',
      source: source,
      maximum: 8000,
    )
    ..closureReviewConfirmed = closureState.confirmed
    ..closureCriticalModuleCount = closureState.criticalModuleCount
    ..closureReviewConfirmedByUid = closureState.confirmedByUid
    ..closureReviewConfirmedByName = closureState.confirmedByName
    ..closureReviewConfirmedAt = closureState.confirmedAt
    ..createdByUid = createdByUid
    ..createdByName = createdByName
    ..updatedByUid = updatedByUid
    ..updatedByName = updatedByName
    ..publishedByUid = publishedByUid
    ..publishedByName = publishedByName
    ..publishedAt = publishedAt
    ..retiredByUid = retiredByUid
    ..retiredByName = retiredByName
    ..retiredAt = retiredAt
    ..retireReason = retireReason
    ..minAppVersion = _readGovernanceOptionalText(
      map['minAppVersion'],
      field: 'minAppVersion',
      source: source,
      maximum: 100,
    )
    ..isDeleted = isDeleted
    ..deletedAt = deletedAt
    ..deletedByUid = deletedByUid
    ..deletedByName = deletedByName
    ..deleteReason = deleteReason
    ..version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    )
    ..schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    )
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..targetRefs = _readGovernanceStringList(
      map['targetRefs'],
      field: 'targetRefs',
      source: source,
    )
    ..deviceTagRefs = _readGovernanceStringList(
      map['deviceTagRefs'],
      field: 'deviceTagRefs',
      source: source,
    )
    ..safetyClass = _readGovernanceOptionalText(
      map['safetyClass'],
      field: 'safetyClass',
      source: source,
      maximum: 200,
    )
    ..safetyGatePolicyJson = _readOptionalGovernanceJsonObjectText(
      map['safetyGatePolicyJson'],
      field: 'safetyGatePolicyJson',
      source: source,
    )
    ..procedureRefs = _readGovernanceStringList(
      map['procedureRefs'],
      field: 'procedureRefs',
      source: source,
    )
    ..operationalStatePreconditions = _readGovernanceStringList(
      map['operationalStatePreconditions'],
      field: 'operationalStatePreconditions',
      source: source,
    )
    ..metadataJson = _readOptionalGovernanceJsonObjectText(
      map['metadataJson'],
      field: 'metadataJson',
      source: source,
    )
    ..isSynced = true;
}

TemplatePublishAudit readRemoteTemplatePublishAudit(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'template_publish_audits/$documentId';
  final firestoreId = _readGovernanceDocumentIdentity(
    map,
    documentId: documentId,
    source: source,
  );
  final action = readRequiredPersistedEnum(
    TemplatePublishAuditAction.values,
    map['action'],
    field: 'action',
    source: source,
  );
  final performedAt = readRequiredPersistedDateTime(
    map['performedAt'],
    field: 'performedAt',
    source: source,
  );
  final updatedAt = readRequiredPersistedDateTime(
    map['updatedAt'],
    field: 'updatedAt',
    source: source,
  );
  if (updatedAt.isBefore(performedAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede performedAt',
    );
  }
  final performedByUid = _readGovernanceRequiredText(
    map['performedByUid'],
    field: 'performedByUid',
    source: source,
    maximum: 512,
  );
  final performedByName = _readGovernanceOptionalText(
    map['performedByName'],
    field: 'performedByName',
    source: source,
    maximum: 500,
  );
  final reason = _readGovernanceOptionalText(
    map['reason'],
    field: 'reason',
    source: source,
    maximum: 2000,
  );
  final beforeHash = _readOptionalTemplateContentHash(
    map['beforeHash'],
    field: 'beforeHash',
    source: source,
  );
  final afterHash = _readOptionalTemplateContentHash(
    map['afterHash'],
    field: 'afterHash',
    source: source,
  );
  final payloadSnapshotJson = _readOptionalGovernanceJsonObjectText(
    map['payloadSnapshotJson'],
    field: 'payloadSnapshotJson',
    source: source,
  );
  final lifecycleAction =
      action == TemplatePublishAuditAction.published ||
      action == TemplatePublishAuditAction.retired ||
      action == TemplatePublishAuditAction.archived ||
      action == TemplatePublishAuditAction.restored;
  if (lifecycleAction && afterHash == null) {
    throw PersistedDataFormatException(
      field: 'afterHash',
      source: source,
      detail: 'lifecycle audits require the resulting content hash',
    );
  }
  if (lifecycleAction && payloadSnapshotJson == null) {
    throw PersistedDataFormatException(
      field: 'payloadSnapshotJson',
      source: source,
      detail: 'lifecycle audits require a payload snapshot',
    );
  }
  if ((action == TemplatePublishAuditAction.retired ||
          action == TemplatePublishAuditAction.archived ||
          action == TemplatePublishAuditAction.restored) &&
      reason == null) {
    throw PersistedDataFormatException(
      field: 'reason',
      source: source,
      detail: 'this lifecycle audit requires a reason',
    );
  }
  if ((action == TemplatePublishAuditAction.archived ||
          action == TemplatePublishAuditAction.restored) &&
      reason!.length < 10) {
    throw PersistedDataFormatException(
      field: 'reason',
      source: source,
      detail: 'archive and restore reasons require at least 10 characters',
    );
  }

  return TemplatePublishAudit()
    ..firestoreId = firestoreId
    ..packageFirestoreId = _readGovernanceRequiredText(
      map['packageFirestoreId'],
      field: 'packageFirestoreId',
      source: source,
      maximum: 512,
    )
    ..versionFirestoreId = _readGovernanceRequiredText(
      map['versionFirestoreId'],
      field: 'versionFirestoreId',
      source: source,
      maximum: 512,
    )
    ..action = action
    ..performedByUid = performedByUid
    ..performedByName = performedByName
    ..performedAt = performedAt
    ..updatedAt = updatedAt
    ..reason = reason
    ..beforeHash = beforeHash
    ..afterHash = afterHash
    ..payloadSnapshotJson = payloadSnapshotJson
    ..metadataJson = _readOptionalGovernanceJsonObjectText(
      map['metadataJson'],
      field: 'metadataJson',
      source: source,
    )
    ..version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    )
    ..schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    )
    ..isDeleted = readRequiredPersistedBool(
      map['isDeleted'],
      field: 'isDeleted',
      source: source,
    )
    ..isSynced = true;
}

String _readGovernanceDocumentIdentity(
  Map<String, dynamic> map, {
  required String documentId,
  required String source,
}) {
  final firestoreId = _readGovernanceRequiredText(
    map['firestoreId'],
    field: 'firestoreId',
    source: source,
    maximum: 512,
  );
  if (firestoreId != documentId) {
    throw PersistedDataFormatException(
      field: 'firestoreId',
      source: source,
      detail: 'must match the document ID',
    );
  }
  return firestoreId;
}

String _readGovernanceRequiredText(
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
      detail: 'must not exceed $maximum characters',
    );
  }
  return result;
}

String? _readGovernanceOptionalText(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  if (value == null) return null;
  final result =
      readOptionalPersistedString(
        value,
        field: field,
        source: source,
        emptyAsNull: false,
      )!;
  if (result.isEmpty || result.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain between 1 and $maximum characters when present',
    );
  }
  return result;
}

List<String> _readGovernanceStringList(
  dynamic value, {
  required String field,
  required String source,
}) {
  final result = readOptionalPersistedStringList(
    value,
    field: field,
    source: source,
  );
  if (result.length > 500) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most 500 entries',
    );
  }
  final seen = <String>{};
  for (var index = 0; index < result.length; index++) {
    final entry = result[index];
    if (entry.length > 512) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'must not exceed 512 characters',
      );
    }
    if (!seen.add(entry)) {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'must not contain duplicate entries',
      );
    }
  }
  return result;
}

String _readRequiredGovernanceJsonObjectText(
  dynamic value, {
  required String field,
  required String source,
}) {
  final raw = _readGovernanceRequiredText(
    value,
    field: field,
    source: source,
    maximum: 2000000,
  );
  readRequiredJsonObject(raw, field: field, source: source);
  return raw;
}

String _readRequiredGovernanceJsonObjectListText(
  dynamic value, {
  required String field,
  required String source,
}) {
  final raw = _readGovernanceRequiredText(
    value,
    field: field,
    source: source,
    maximum: 2000000,
  );
  readRequiredJsonObjectList(raw, field: field, source: source);
  return raw;
}

String? _readOptionalGovernanceJsonObjectText(
  dynamic value, {
  required String field,
  required String source,
}) {
  final raw = _readGovernanceOptionalText(
    value,
    field: field,
    source: source,
    maximum: 2000000,
  );
  if (raw == null) return null;
  readRequiredJsonObject(raw, field: field, source: source);
  return raw;
}

String? _readOptionalTemplateContentHash(
  dynamic value, {
  required String field,
  required String source,
}) {
  final hash = _readGovernanceOptionalText(
    value,
    field: field,
    source: source,
    maximum: 128,
  );
  if (hash != null && !_templateContentHashPattern.hasMatch(hash)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'unsupported template content hash',
    );
  }
  return hash;
}

_TemplateClosureReviewState _readStrictClosureReviewState({
  required String jobTemplateSnapshotJson,
  required String moduleSnapshotsJson,
  required String source,
}) {
  final jobSnapshot = readRequiredJsonObject(
    jobTemplateSnapshotJson,
    field: 'jobTemplateSnapshotJson',
    source: source,
  );
  final modules = readRequiredJsonObjectList(
    moduleSnapshotsJson,
    field: 'moduleSnapshotsJson',
    source: source,
  );
  final composer = _readGovernanceOptionalMap(
    jobSnapshot['composer'],
    field: 'jobTemplateSnapshotJson.composer',
    source: source,
  );
  final actualCriticalCount =
      <int>[
        for (var index = 0; index < modules.length; index++)
          if (_readAliasedClosureRequiredFlag(
            modules[index],
            index: index,
            source: source,
          ))
            index,
      ].length;
  final declaredCriticalCount =
      jobSnapshot.containsKey('closureCriticalCount')
          ? readRequiredPersistedInt(
            jobSnapshot['closureCriticalCount'],
            field: 'jobTemplateSnapshotJson.closureCriticalCount',
            source: source,
            minimum: 0,
          )
          : 0;
  final confirmed =
      composer.containsKey('closureReviewConfirmed')
          ? readRequiredPersistedBool(
            composer['closureReviewConfirmed'],
            field: 'jobTemplateSnapshotJson.composer.closureReviewConfirmed',
            source: source,
          )
          : false;
  final confirmedByUid = _readGovernanceOptionalText(
    composer['closureReviewConfirmedByUid'],
    field: 'jobTemplateSnapshotJson.composer.closureReviewConfirmedByUid',
    source: source,
    maximum: 512,
  );
  final confirmedByName = _readGovernanceOptionalText(
    composer['closureReviewConfirmedByName'],
    field: 'jobTemplateSnapshotJson.composer.closureReviewConfirmedByName',
    source: source,
    maximum: 500,
  );
  final confirmedAt = readOptionalPersistedDateTime(
    composer['closureReviewConfirmedAt'],
    field: 'closureReviewConfirmedAt',
    source: source,
  );
  _requireClosureReviewAuthority(
    confirmed: confirmed,
    confirmedByUid: confirmedByUid,
    confirmedByName: confirmedByName,
    confirmedAt: confirmedAt,
    source: source,
  );
  return _TemplateClosureReviewState(
    confirmed: confirmed,
    criticalModuleCount:
        actualCriticalCount > declaredCriticalCount
            ? actualCriticalCount
            : declaredCriticalCount,
    confirmedByUid: confirmedByUid,
    confirmedByName: confirmedByName,
    confirmedAt: confirmedAt,
  );
}

_TemplateClosureReviewState _readClosureProjection(
  Map<String, dynamic> map, {
  required _TemplateClosureReviewState inferred,
  required String source,
}) {
  final presentCount = _closureProjectionFields.where(map.containsKey).length;
  if (presentCount == 0) return inferred;
  if (presentCount != _closureProjectionFields.length) {
    throw PersistedDataFormatException(
      field: 'closureReviewConfirmed',
      source: source,
      detail: 'the five closure-review projection fields must exist together',
    );
  }
  final projected = _TemplateClosureReviewState(
    confirmed: readRequiredPersistedBool(
      map['closureReviewConfirmed'],
      field: 'closureReviewConfirmed',
      source: source,
    ),
    criticalModuleCount: readRequiredPersistedInt(
      map['closureCriticalModuleCount'],
      field: 'closureCriticalModuleCount',
      source: source,
      minimum: 0,
    ),
    confirmedByUid: _readGovernanceOptionalText(
      map['closureReviewConfirmedByUid'],
      field: 'closureReviewConfirmedByUid',
      source: source,
      maximum: 512,
    ),
    confirmedByName: _readGovernanceOptionalText(
      map['closureReviewConfirmedByName'],
      field: 'closureReviewConfirmedByName',
      source: source,
      maximum: 500,
    ),
    confirmedAt: readOptionalPersistedDateTime(
      map['closureReviewConfirmedAt'],
      field: 'closureReviewConfirmedAt',
      source: source,
    ),
  );
  _requireClosureReviewAuthority(
    confirmed: projected.confirmed,
    confirmedByUid: projected.confirmedByUid,
    confirmedByName: projected.confirmedByName,
    confirmedAt: projected.confirmedAt,
    source: source,
  );
  if (projected.confirmed != inferred.confirmed ||
      projected.criticalModuleCount != inferred.criticalModuleCount ||
      projected.confirmedByUid != inferred.confirmedByUid ||
      projected.confirmedByName != inferred.confirmedByName ||
      !_sameGovernanceInstant(projected.confirmedAt, inferred.confirmedAt)) {
    throw PersistedDataFormatException(
      field: 'closureReviewConfirmed',
      source: source,
      detail: 'top-level closure review must match the frozen snapshot',
    );
  }
  return projected;
}

Map<String, dynamic> _readGovernanceOptionalMap(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value == null) return const <String, dynamic>{};
  if (value is! Map) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an object (${value.runtimeType})',
    );
  }
  try {
    return Map<String, dynamic>.from(value);
  } on TypeError {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'object keys must be strings',
    );
  }
}

bool _readAliasedClosureRequiredFlag(
  Map<String, dynamic> module, {
  required int index,
  required String source,
}) {
  const fields = <String>[
    'requiredForClosure',
    'requiredForCloseout',
    'required',
    'isRequired',
  ];
  bool? result;
  for (final field in fields) {
    if (!module.containsKey(field)) continue;
    final value = readRequiredPersistedBool(
      module[field],
      field: 'moduleSnapshotsJson[$index].$field',
      source: source,
    );
    if (result != null && result != value) {
      throw PersistedDataFormatException(
        field: 'moduleSnapshotsJson[$index].$field',
        source: source,
        detail: 'conflicts with another closure-required alias',
      );
    }
    result = value;
  }
  return result ?? false;
}

void _requireClosureReviewAuthority({
  required bool confirmed,
  required String? confirmedByUid,
  required String? confirmedByName,
  required DateTime? confirmedAt,
  required String source,
}) {
  if (confirmed) {
    if (confirmedByUid == null) {
      throw PersistedDataFormatException(
        field: 'closureReviewConfirmedByUid',
        source: source,
        detail: 'confirmed closure review requires actor authority',
      );
    }
    if (confirmedAt == null) {
      throw PersistedDataFormatException(
        field: 'closureReviewConfirmedAt',
        source: source,
        detail: 'confirmed closure review requires its timestamp',
      );
    }
  } else if (confirmedByUid != null ||
      confirmedByName != null ||
      confirmedAt != null) {
    throw PersistedDataFormatException(
      field: 'closureReviewConfirmed',
      source: source,
      detail: 'unconfirmed closure review cannot carry authority metadata',
    );
  }
  _requireGovernanceActorNamePair(
    uid: confirmedByUid,
    name: confirmedByName,
    uidField: 'closureReviewConfirmedByUid',
    nameField: 'closureReviewConfirmedByName',
    source: source,
  );
}

void _requirePackageLifecycle({
  required TemplatePackageLifecycleStatus lifecycleStatus,
  required DateTime? retiredAt,
  required String? retiredByUid,
  required String? retiredByName,
  required String? retireReason,
  required bool isDeleted,
  required DateTime? deletedAt,
  required String? deletedByUid,
  required String? deletedByName,
  required String? deleteReason,
  required String source,
}) {
  if (lifecycleStatus == TemplatePackageLifecycleStatus.retired &&
      retiredAt == null) {
    throw PersistedDataFormatException(
      field: 'retiredAt',
      source: source,
      detail: 'retired packages require a retirement timestamp',
    );
  }
  if (lifecycleStatus != TemplatePackageLifecycleStatus.retired &&
      (retiredAt != null ||
          retiredByUid != null ||
          retiredByName != null ||
          retireReason != null)) {
    throw PersistedDataFormatException(
      field: 'lifecycleStatus',
      source: source,
      detail: 'non-retired packages cannot carry retirement state',
    );
  }
  _requireGovernanceActorNamePair(
    uid: retiredByUid,
    name: retiredByName,
    uidField: 'retiredByUid',
    nameField: 'retiredByName',
    source: source,
  );
  if (isDeleted) {
    if (deletedAt == null || deletedByUid == null) {
      throw PersistedDataFormatException(
        field: deletedAt == null ? 'deletedAt' : 'deletedByUid',
        source: source,
        detail: 'deleted packages require time and actor authority',
      );
    }
  } else if (deletedAt != null ||
      deletedByUid != null ||
      deletedByName != null ||
      deleteReason != null) {
    throw PersistedDataFormatException(
      field: 'isDeleted',
      source: source,
      detail: 'active packages cannot carry deletion state',
    );
  }
  _requireGovernanceActorNamePair(
    uid: deletedByUid,
    name: deletedByName,
    uidField: 'deletedByUid',
    nameField: 'deletedByName',
    source: source,
  );
}

void _requireVersionLifecycle({
  required TemplateVersionStatus status,
  required _TemplateClosureReviewState closureState,
  required DateTime? publishedAt,
  required String? publishedByUid,
  required String? publishedByName,
  required DateTime? retiredAt,
  required String? retiredByUid,
  required String? retiredByName,
  required String? retireReason,
  required bool isDeleted,
  required DateTime? deletedAt,
  required String? deletedByUid,
  required String? deletedByName,
  required String? deleteReason,
  required String source,
}) {
  final hasPublicationState =
      publishedAt != null || publishedByUid != null || publishedByName != null;
  final hasRetirementState =
      retiredAt != null ||
      retiredByUid != null ||
      retiredByName != null ||
      retireReason != null;
  switch (status) {
    case TemplateVersionStatus.draft:
      if (hasPublicationState || hasRetirementState) {
        throw PersistedDataFormatException(
          field: hasPublicationState ? 'publishedAt' : 'retiredAt',
          source: source,
          detail: 'draft versions cannot carry publication history',
        );
      }
      break;
    case TemplateVersionStatus.published:
      if (publishedAt == null || publishedByUid == null) {
        throw PersistedDataFormatException(
          field: publishedAt == null ? 'publishedAt' : 'publishedByUid',
          source: source,
          detail: 'published versions require time and actor authority',
        );
      }
      if (hasRetirementState) {
        throw PersistedDataFormatException(
          field: 'retiredAt',
          source: source,
          detail: 'published versions cannot carry retirement history',
        );
      }
      break;
    case TemplateVersionStatus.retired:
      if (publishedAt == null || publishedByUid == null) {
        throw PersistedDataFormatException(
          field: publishedAt == null ? 'publishedAt' : 'publishedByUid',
          source: source,
          detail: 'retired versions require complete publication history',
        );
      }
      if (retiredAt == null || retiredByUid == null || retireReason == null) {
        throw PersistedDataFormatException(
          field:
              retiredAt == null
                  ? 'retiredAt'
                  : retiredByUid == null
                  ? 'retiredByUid'
                  : 'retireReason',
          source: source,
          detail: 'retired versions require complete retirement history',
        );
      }
      break;
    case TemplateVersionStatus.archived:
      if (hasPublicationState != hasRetirementState) {
        throw PersistedDataFormatException(
          field: hasPublicationState ? 'retiredAt' : 'publishedAt',
          source: source,
          detail:
              'archived versions require either complete retired history or no publication history',
        );
      }
      if (hasPublicationState &&
          (publishedAt == null ||
              publishedByUid == null ||
              retiredAt == null ||
              retiredByUid == null ||
              retireReason == null)) {
        throw PersistedDataFormatException(
          field: 'retiredAt',
          source: source,
          detail: 'archived retired versions require complete history',
        );
      }
      break;
  }
  final publishedHistory =
      status == TemplateVersionStatus.published ||
      status == TemplateVersionStatus.retired ||
      (status == TemplateVersionStatus.archived && hasPublicationState);
  if (publishedHistory &&
      closureState.criticalModuleCount > 0 &&
      !closureState.confirmed) {
    throw PersistedDataFormatException(
      field: 'closureReviewConfirmed',
      source: source,
      detail: 'published closure-critical content requires review authority',
    );
  }
  _requireGovernanceActorNamePair(
    uid: publishedByUid,
    name: publishedByName,
    uidField: 'publishedByUid',
    nameField: 'publishedByName',
    source: source,
  );
  _requireGovernanceActorNamePair(
    uid: retiredByUid,
    name: retiredByName,
    uidField: 'retiredByUid',
    nameField: 'retiredByName',
    source: source,
  );
  if (isDeleted) {
    if (deletedAt == null || deletedByUid == null) {
      throw PersistedDataFormatException(
        field: deletedAt == null ? 'deletedAt' : 'deletedByUid',
        source: source,
        detail: 'deleted versions require time and actor authority',
      );
    }
  } else if (deletedAt != null ||
      deletedByUid != null ||
      deletedByName != null ||
      deleteReason != null) {
    throw PersistedDataFormatException(
      field: 'isDeleted',
      source: source,
      detail: 'active versions cannot carry deletion state',
    );
  }
  _requireGovernanceActorNamePair(
    uid: deletedByUid,
    name: deletedByName,
    uidField: 'deletedByUid',
    nameField: 'deletedByName',
    source: source,
  );
}

void _requireGovernanceTimeline({
  required DateTime createdAt,
  required DateTime updatedAt,
  required Map<String, DateTime?> optionalTimes,
  required String source,
}) {
  if (updatedAt.isBefore(createdAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede createdAt',
    );
  }
  for (final entry in optionalTimes.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value.isBefore(createdAt) || value.isAfter(updatedAt)) {
      throw PersistedDataFormatException(
        field: entry.key,
        source: source,
        detail: 'must fall within the record timeline',
      );
    }
  }
}

void _requireGovernanceActorNamePair({
  required String? uid,
  required String? name,
  required String uidField,
  required String nameField,
  required String source,
}) {
  if (name != null && uid == null) {
    throw PersistedDataFormatException(
      field: nameField,
      source: source,
      detail: 'cannot exist without $uidField',
    );
  }
}

bool _sameGovernanceInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == right;
  return left.isAtSameMomentAs(right);
}
