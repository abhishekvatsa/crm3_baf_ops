part of 'module_registry_model.dart';

final RegExp _moduleRegistryContentHashPattern = RegExp(
  r'^mrg1-sha256:[0-9a-f]{64}$',
);

ModuleRegistryFamily readRemoteModuleRegistryFamily(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'module_registry/$documentId';
  final registryModuleId = _readRegistryRequiredText(
    map['registryModuleId'],
    field: 'registryModuleId',
    source: source,
    maximum: 500,
  );
  if (registryModuleId != documentId) {
    throw PersistedDataFormatException(
      field: 'registryModuleId',
      source: source,
      detail: 'must match the Firestore document ID',
    );
  }

  final status = readRequiredPersistedEnum(
    ModuleRegistryFamilyStatus.values,
    map['status'],
    field: 'status',
    source: source,
  );
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  _rejectUnsupportedRegistryTombstone(isDeleted, source: source);
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
  final createdByUid = _readRegistryRequiredText(
    map['createdByUid'],
    field: 'createdByUid',
    source: source,
    maximum: 512,
  );
  final createdByName = _readRegistryOptionalText(
    map['createdByName'],
    field: 'createdByName',
    source: source,
    maximum: 500,
  );
  final updatedByUid = _readRegistryRequiredText(
    map['updatedByUid'],
    field: 'updatedByUid',
    source: source,
    maximum: 512,
  );
  final updatedByName = _readRegistryOptionalText(
    map['updatedByName'],
    field: 'updatedByName',
    source: source,
    maximum: 500,
  );
  final retiredByUid = _readRegistryOptionalText(
    map['retiredByUid'],
    field: 'retiredByUid',
    source: source,
    maximum: 512,
  );
  final retiredByName = _readRegistryOptionalText(
    map['retiredByName'],
    field: 'retiredByName',
    source: source,
    maximum: 500,
  );
  final retireReason = _readRegistryOptionalText(
    map['retireReason'],
    field: 'retireReason',
    source: source,
    maximum: 2000,
  );
  final latestPublishedRevisionNumber = readRequiredPersistedInt(
    map['latestPublishedRevisionNumber'],
    field: 'latestPublishedRevisionNumber',
    source: source,
    minimum: 0,
  );
  final latestPublishedRevisionId = _readRegistryOptionalText(
    map['latestPublishedRevisionId'],
    field: 'latestPublishedRevisionId',
    source: source,
    maximum: 500,
  );
  final latestPublishedContentHash = _readRegistryOptionalHash(
    map['latestPublishedContentHash'],
    field: 'latestPublishedContentHash',
    source: source,
  );
  final version = readRequiredPersistedInt(
    map['version'],
    field: 'version',
    source: source,
    minimum: 1,
  );
  final schemaVersion = _readRegistrySchemaVersion(map, source: source);

  _requireRegistryTimeline(
    createdAt: createdAt,
    updatedAt: updatedAt,
    optionalTimes: <String, DateTime?>{'retiredAt': retiredAt},
    source: source,
  );
  _requireRegistryActorNamePair(
    uid: createdByUid,
    name: createdByName,
    uidField: 'createdByUid',
    nameField: 'createdByName',
    source: source,
  );
  _requireRegistryActorNamePair(
    uid: updatedByUid,
    name: updatedByName,
    uidField: 'updatedByUid',
    nameField: 'updatedByName',
    source: source,
  );
  _requireRegistryFamilyLifecycle(
    status: status,
    retiredAt: retiredAt,
    retiredByUid: retiredByUid,
    retiredByName: retiredByName,
    retireReason: retireReason,
    source: source,
  );
  if (latestPublishedRevisionNumber == 0 &&
      (latestPublishedRevisionId != null ||
          latestPublishedContentHash != null)) {
    throw PersistedDataFormatException(
      field: 'latestPublishedRevisionNumber',
      source: source,
      detail: 'zero publication history cannot carry latest pointers',
    );
  }

  return ModuleRegistryFamily(
    registryModuleId: registryModuleId,
    moduleCode: _readRegistryRequiredText(
      map['moduleCode'],
      field: 'moduleCode',
      source: source,
      maximum: 160,
    ),
    canonicalTitle: _readRegistryRequiredText(
      map['canonicalTitle'],
      field: 'canonicalTitle',
      source: source,
      maximum: 500,
    ),
    status: status,
    discipline: readRequiredPersistedEnum(
      JobModuleDiscipline.values,
      map['discipline'],
      field: 'discipline',
      source: source,
    ),
    ownerDisciplines: _readRegistryRequiredStringList(
      map,
      field: 'ownerDisciplines',
      source: source,
    ),
    assetType: readRequiredPersistedEnum(
      AssetType.values,
      map['assetType'],
      field: 'assetType',
      source: source,
    ),
    functionalSection: _readRegistryRequiredTextAllowEmpty(
      map['functionalSection'],
      field: 'functionalSection',
      source: source,
      maximum: 500,
    ),
    componentGroup: _readRegistryRequiredTextAllowEmpty(
      map['componentGroup'],
      field: 'componentGroup',
      source: source,
      maximum: 500,
    ),
    targetRefs: _readRegistryRequiredStringList(
      map,
      field: 'targetRefs',
      source: source,
    ),
    deviceTagRefs: _readRegistryRequiredStringList(
      map,
      field: 'deviceTagRefs',
      source: source,
    ),
    safetyClasses: _readRegistryRequiredStringList(
      map,
      field: 'safetyClasses',
      source: source,
    ),
    requiredForClosure: readRequiredPersistedBool(
      map['requiredForClosure'],
      field: 'requiredForClosure',
      source: source,
    ),
    latestPublishedRevisionNumber: latestPublishedRevisionNumber,
    latestPublishedRevisionId: latestPublishedRevisionId,
    latestPublishedContentHash: latestPublishedContentHash,
    createdByUid: createdByUid,
    createdByName: createdByName,
    createdAt: createdAt,
    updatedByUid: updatedByUid,
    updatedByName: updatedByName,
    updatedAt: updatedAt,
    retiredByUid: retiredByUid,
    retiredByName: retiredByName,
    retiredAt: retiredAt,
    retireReason: retireReason,
    version: version,
    schemaVersion: schemaVersion,
    isDeleted: isDeleted,
  );
}

ModuleRegistryRevision readRemoteModuleRegistryRevision(
  Map<String, dynamic> map, {
  required String documentId,
  required String registryModuleId,
}) {
  final source = 'module_registry/$registryModuleId/revisions/$documentId';
  final storedRegistryModuleId = _readRegistryRequiredText(
    map['registryModuleId'],
    field: 'registryModuleId',
    source: source,
    maximum: 500,
  );
  if (storedRegistryModuleId != registryModuleId) {
    throw PersistedDataFormatException(
      field: 'registryModuleId',
      source: source,
      detail: 'must match the parent registry document ID',
    );
  }
  final revisionId = _readRegistryRequiredText(
    map['revisionId'],
    field: 'revisionId',
    source: source,
    maximum: 500,
  );
  if (revisionId != documentId) {
    throw PersistedDataFormatException(
      field: 'revisionId',
      source: source,
      detail: 'must match the Firestore revision document ID',
    );
  }

  final revisionStatus = readRequiredPersistedEnum(
    ModuleRegistryRevisionStatus.values,
    map['revisionStatus'],
    field: 'revisionStatus',
    source: source,
  );
  final revisionNumber = readRequiredPersistedInt(
    map['revisionNumber'],
    field: 'revisionNumber',
    source: source,
    minimum: 0,
  );
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  _rejectUnsupportedRegistryTombstone(isDeleted, source: source);

  final moduleSnapshotJson = _readRegistryRequiredText(
    map['moduleSnapshotJson'],
    field: 'moduleSnapshotJson',
    source: source,
    maximum: 1000000,
  );
  final fieldDefinitionsJson = _readRegistryRequiredText(
    map['fieldDefinitionsJson'],
    field: 'fieldDefinitionsJson',
    source: source,
    maximum: 2000000,
  );
  final checklistJson = _readRegistryRequiredText(
    map['checklistJson'],
    field: 'checklistJson',
    source: source,
    maximum: 2000000,
  );
  final lineageJson = _readRegistryRequiredText(
    map['lineageJson'],
    field: 'lineageJson',
    source: source,
    maximum: 100000,
  );
  final contentHash = _readRegistryRequiredHash(
    map['contentHash'],
    field: 'contentHash',
    source: source,
  );
  final moduleSnapshot = readRequiredJsonObject(
    moduleSnapshotJson,
    field: 'moduleSnapshotJson',
    source: source,
  );
  final fieldDefinitions = readRequiredJsonObjectList(
    fieldDefinitionsJson,
    field: 'fieldDefinitionsJson',
    source: source,
  );
  final checklist = readRequiredJsonObjectList(
    checklistJson,
    field: 'checklistJson',
    source: source,
  );
  readRequiredJsonObject(lineageJson, field: 'lineageJson', source: source);
  final moduleCode = _moduleCodeFromSnapshot(moduleSnapshot);
  if (moduleCode == null || moduleCode.length > 160) {
    throw PersistedDataFormatException(
      field: 'moduleSnapshotJson.moduleCode',
      source: source,
      detail:
          'a recognized module identity of at most 160 characters is required',
    );
  }
  _requireRegistryModuleReferences(
    fieldDefinitions,
    field: 'fieldDefinitionsJson',
    moduleCode: moduleCode,
    source: source,
  );
  _requireRegistryModuleReferences(
    checklist,
    field: 'checklistJson',
    moduleCode: moduleCode,
    source: source,
  );
  final actualHash = stableModuleRegistryContentHashStrict(
    moduleSnapshotJson: moduleSnapshotJson,
    fieldDefinitionsJson: fieldDefinitionsJson,
    checklistJson: checklistJson,
  );
  if (contentHash != actualHash) {
    throw PersistedDataFormatException(
      field: 'contentHash',
      source: source,
      detail: 'does not match the canonical registry payload',
    );
  }

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
  final createdByUid = _readRegistryRequiredText(
    map['createdByUid'],
    field: 'createdByUid',
    source: source,
    maximum: 512,
  );
  final createdByName = _readRegistryOptionalText(
    map['createdByName'],
    field: 'createdByName',
    source: source,
    maximum: 500,
  );
  final updatedByUid = _readRegistryRequiredText(
    map['updatedByUid'],
    field: 'updatedByUid',
    source: source,
    maximum: 512,
  );
  final updatedByName = _readRegistryOptionalText(
    map['updatedByName'],
    field: 'updatedByName',
    source: source,
    maximum: 500,
  );
  final publishedByUid = _readRegistryOptionalText(
    map['publishedByUid'],
    field: 'publishedByUid',
    source: source,
    maximum: 512,
  );
  final publishedByName = _readRegistryOptionalText(
    map['publishedByName'],
    field: 'publishedByName',
    source: source,
    maximum: 500,
  );
  final retiredByUid = _readRegistryOptionalText(
    map['retiredByUid'],
    field: 'retiredByUid',
    source: source,
    maximum: 512,
  );
  final retiredByName = _readRegistryOptionalText(
    map['retiredByName'],
    field: 'retiredByName',
    source: source,
    maximum: 500,
  );
  final retireReason = _readRegistryOptionalText(
    map['retireReason'],
    field: 'retireReason',
    source: source,
    maximum: 2000,
  );
  final version = readRequiredPersistedInt(
    map['version'],
    field: 'version',
    source: source,
    minimum: 1,
  );
  final schemaVersion = _readRegistrySchemaVersion(map, source: source);

  _requireRegistryTimeline(
    createdAt: createdAt,
    updatedAt: updatedAt,
    optionalTimes: <String, DateTime?>{
      'publishedAt': publishedAt,
      'retiredAt': retiredAt,
    },
    source: source,
  );
  _requireRegistryRevisionLifecycle(
    status: revisionStatus,
    revisionNumber: revisionNumber,
    publishedAt: publishedAt,
    publishedByUid: publishedByUid,
    publishedByName: publishedByName,
    retiredAt: retiredAt,
    retiredByUid: retiredByUid,
    retiredByName: retiredByName,
    retireReason: retireReason,
    source: source,
  );

  return ModuleRegistryRevision(
    registryModuleId: storedRegistryModuleId,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    revisionStatus: revisionStatus,
    moduleSnapshotJson: moduleSnapshotJson,
    fieldDefinitionsJson: fieldDefinitionsJson,
    checklistJson: checklistJson,
    contentHash: contentHash,
    lineageJson: lineageJson,
    createdByUid: createdByUid,
    createdByName: createdByName,
    createdAt: createdAt,
    updatedByUid: updatedByUid,
    updatedByName: updatedByName,
    updatedAt: updatedAt,
    publishedByUid: publishedByUid,
    publishedByName: publishedByName,
    publishedAt: publishedAt,
    retiredByUid: retiredByUid,
    retiredByName: retiredByName,
    retiredAt: retiredAt,
    retireReason: retireReason,
    version: version,
    schemaVersion: schemaVersion,
    isDeleted: isDeleted,
  );
}

String _readRegistryRequiredText(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  final text = readRequiredPersistedString(value, field: field, source: source);
  if (text.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most $maximum characters',
    );
  }
  return text;
}

String _readRegistryRequiredTextAllowEmpty(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  if (value is! String) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'required string (${value.runtimeType})',
    );
  }
  final text = value.trim();
  if (text.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most $maximum characters',
    );
  }
  return text;
}

String? _readRegistryOptionalText(
  dynamic value, {
  required String field,
  required String source,
  required int maximum,
}) {
  final text = readOptionalPersistedString(value, field: field, source: source);
  if (text != null && text.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most $maximum characters',
    );
  }
  return text;
}

List<String> _readRegistryRequiredStringList(
  Map<String, dynamic> map, {
  required String field,
  required String source,
}) {
  if (!map.containsKey(field) || map[field] is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'required array (${map[field].runtimeType})',
    );
  }
  final values = readOptionalPersistedStringList(
    map[field],
    field: field,
    source: source,
  );
  if (values.length > 250) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most 250 values',
    );
  }
  final seen = <String>{};
  for (var index = 0; index < values.length; index++) {
    if (values[index].length > 500) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'must contain at most 500 characters',
      );
    }
    if (!seen.add(values[index])) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'duplicate values are not allowed',
      );
    }
  }
  return values;
}

String _readRegistryRequiredHash(
  dynamic value, {
  required String field,
  required String source,
}) {
  final hash = _readRegistryRequiredText(
    value,
    field: field,
    source: source,
    maximum: 128,
  );
  if (!_moduleRegistryContentHashPattern.hasMatch(hash)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'unsupported registry content hash',
    );
  }
  return hash;
}

String? _readRegistryOptionalHash(
  dynamic value, {
  required String field,
  required String source,
}) {
  final hash = _readRegistryOptionalText(
    value,
    field: field,
    source: source,
    maximum: 128,
  );
  if (hash != null && !_moduleRegistryContentHashPattern.hasMatch(hash)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'unsupported registry content hash',
    );
  }
  return hash;
}

int _readRegistrySchemaVersion(
  Map<String, dynamic> map, {
  required String source,
}) {
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
      detail: 'unsupported schema version $schemaVersion',
    );
  }
  return schemaVersion;
}

void _requireRegistryTimeline({
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
    final instant = entry.value;
    if (instant != null &&
        (instant.isBefore(createdAt) || instant.isAfter(updatedAt))) {
      throw PersistedDataFormatException(
        field: entry.key,
        source: source,
        detail: 'must fall between createdAt and updatedAt',
      );
    }
  }
  final publishedAt = optionalTimes['publishedAt'];
  final retiredAt = optionalTimes['retiredAt'];
  if (publishedAt != null &&
      retiredAt != null &&
      retiredAt.isBefore(publishedAt)) {
    throw PersistedDataFormatException(
      field: 'retiredAt',
      source: source,
      detail: 'cannot precede publishedAt',
    );
  }
}

void _requireRegistryActorNamePair({
  required String? uid,
  required String? name,
  required String uidField,
  required String nameField,
  required String source,
}) {
  if (uid == null && name != null) {
    throw PersistedDataFormatException(
      field: nameField,
      source: source,
      detail: 'cannot exist without $uidField',
    );
  }
}

void _requireRegistryFamilyLifecycle({
  required ModuleRegistryFamilyStatus status,
  required DateTime? retiredAt,
  required String? retiredByUid,
  required String? retiredByName,
  required String? retireReason,
  required String source,
}) {
  _requireRegistryActorNamePair(
    uid: retiredByUid,
    name: retiredByName,
    uidField: 'retiredByUid',
    nameField: 'retiredByName',
    source: source,
  );
  if (status == ModuleRegistryFamilyStatus.active) {
    if (retiredAt != null ||
        retiredByUid != null ||
        retiredByName != null ||
        retireReason != null) {
      throw PersistedDataFormatException(
        field: 'retiredAt',
        source: source,
        detail: 'active registry families cannot carry retirement history',
      );
    }
    return;
  }
  if (retiredAt == null) {
    throw PersistedDataFormatException(
      field: 'retiredAt',
      source: source,
      detail: 'retired registry families require a retirement timestamp',
    );
  }
  if (retiredByUid == null) {
    throw PersistedDataFormatException(
      field: 'retiredByUid',
      source: source,
      detail: 'retired registry families require an actor UID',
    );
  }
  if (retireReason == null) {
    throw PersistedDataFormatException(
      field: 'retireReason',
      source: source,
      detail: 'retired registry families require a reason',
    );
  }
}

void _requireRegistryRevisionLifecycle({
  required ModuleRegistryRevisionStatus status,
  required int revisionNumber,
  required DateTime? publishedAt,
  required String? publishedByUid,
  required String? publishedByName,
  required DateTime? retiredAt,
  required String? retiredByUid,
  required String? retiredByName,
  required String? retireReason,
  required String source,
}) {
  _requireRegistryActorNamePair(
    uid: publishedByUid,
    name: publishedByName,
    uidField: 'publishedByUid',
    nameField: 'publishedByName',
    source: source,
  );
  _requireRegistryActorNamePair(
    uid: retiredByUid,
    name: retiredByName,
    uidField: 'retiredByUid',
    nameField: 'retiredByName',
    source: source,
  );
  if (status == ModuleRegistryRevisionStatus.draft) {
    if (revisionNumber != 0) {
      throw PersistedDataFormatException(
        field: 'revisionNumber',
        source: source,
        detail: 'draft revisions require revision number zero',
      );
    }
    if (publishedAt != null ||
        publishedByUid != null ||
        publishedByName != null ||
        retiredAt != null ||
        retiredByUid != null ||
        retiredByName != null ||
        retireReason != null) {
      throw PersistedDataFormatException(
        field:
            publishedAt != null || publishedByUid != null
                ? 'publishedAt'
                : 'retiredAt',
        source: source,
        detail: 'draft registry revisions cannot carry lifecycle history',
      );
    }
    return;
  }
  if (revisionNumber < 1) {
    throw PersistedDataFormatException(
      field: 'revisionNumber',
      source: source,
      detail: 'published history requires a positive revision number',
    );
  }
  if (publishedAt == null) {
    throw PersistedDataFormatException(
      field: 'publishedAt',
      source: source,
      detail: 'published history requires a publication timestamp',
    );
  }
  if (publishedByUid == null) {
    throw PersistedDataFormatException(
      field: 'publishedByUid',
      source: source,
      detail: 'published history requires an actor UID',
    );
  }
  if (status == ModuleRegistryRevisionStatus.published) {
    if (retiredAt != null ||
        retiredByUid != null ||
        retiredByName != null ||
        retireReason != null) {
      throw PersistedDataFormatException(
        field: 'retiredAt',
        source: source,
        detail: 'published revisions cannot carry retirement history',
      );
    }
    return;
  }
  if (retiredAt == null) {
    throw PersistedDataFormatException(
      field: 'retiredAt',
      source: source,
      detail: 'retired revisions require a retirement timestamp',
    );
  }
  if (retiredByUid == null) {
    throw PersistedDataFormatException(
      field: 'retiredByUid',
      source: source,
      detail: 'retired revisions require an actor UID',
    );
  }
  if (retireReason == null) {
    throw PersistedDataFormatException(
      field: 'retireReason',
      source: source,
      detail: 'retired revisions require a reason',
    );
  }
}

void _requireRegistryModuleReferences(
  List<Map<String, dynamic>> entries, {
  required String field,
  required String moduleCode,
  required String source,
}) {
  for (var index = 0; index < entries.length; index++) {
    if (!_moduleReferenceMatches(entries[index], moduleCode)) {
      throw PersistedDataFormatException(
        field: '$field[$index].moduleCode',
        source: source,
        detail: 'must reference module $moduleCode',
      );
    }
  }
}
