part of 'abnormality_model.dart';

AbnormalityType readRemoteAbnormalityType(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'abnormality_types/$documentId';
  final firestoreId = _readDocumentIdentity(map, documentId, source);
  final timestamps = readRemoteAbnormalityTypeTimestamps(map, source: source);
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  final isActive = readRequiredPersistedBool(
    map['isActive'],
    field: 'isActive',
    source: source,
  );
  final deletedByUid = _readOptionalBoundedString(
    map['deletedByUid'],
    field: 'deletedByUid',
    source: source,
    maximum: 512,
  );
  final deletedByName = _readOptionalBoundedString(
    map['deletedByName'],
    field: 'deletedByName',
    source: source,
    maximum: 500,
  );
  final deleteReason = _readOptionalBoundedString(
    map['deleteReason'],
    field: 'deleteReason',
    source: source,
    maximum: 2000,
  );
  final createdByUid = _readOptionalBoundedString(
    map['createdByUid'],
    field: 'createdByUid',
    source: source,
    maximum: 512,
  );
  final createdByName = _readOptionalBoundedString(
    map['createdByName'],
    field: 'createdByName',
    source: source,
    maximum: 500,
  );
  final lastEditedByUid = _readOptionalBoundedString(
    map['lastEditedByUid'],
    field: 'lastEditedByUid',
    source: source,
    maximum: 512,
  );
  final lastEditedByName = _readOptionalBoundedString(
    map['lastEditedByName'],
    field: 'lastEditedByName',
    source: source,
    maximum: 500,
  );

  _requireTypeTimeline(timestamps, source: source);
  _requireTypeLifecycle(
    isDeleted: isDeleted,
    isActive: isActive,
    deletedAt: timestamps.deletedAt,
    deletedByUid: deletedByUid,
    deletedByName: deletedByName,
    deleteReason: deleteReason,
    firestoreId: firestoreId,
    source: source,
  );
  _requireActorNamePair(
    uid: createdByUid,
    name: createdByName,
    uidField: 'createdByUid',
    nameField: 'createdByName',
    source: source,
  );
  _requireActorNamePair(
    uid: lastEditedByUid,
    name: lastEditedByName,
    uidField: 'lastEditedByUid',
    nameField: 'lastEditedByName',
    source: source,
  );

  final type =
      AbnormalityType()
        ..firestoreId = firestoreId
        ..code = _readRequiredBoundedString(
          map['code'],
          field: 'code',
          source: source,
          maximum: 160,
        )
        ..title = _readRequiredBoundedString(
          map['title'],
          field: 'title',
          source: source,
          maximum: 500,
        )
        ..description = _readOptionalBoundedString(
          map['description'],
          field: 'description',
          source: source,
          maximum: 4000,
        )
        ..category = readRequiredPersistedEnum(
          AbnormalityCategory.values,
          map['category'],
          field: 'category',
          source: source,
        )
        ..severity = readRequiredPersistedEnum(
          AbnormalitySeverity.values,
          map['severity'],
          field: 'severity',
          source: source,
        )
        ..applicableAssetTypes = _readApplicableAssetTypes(
          map['applicableAssetTypes'],
          source: source,
        )
        ..suggestsReannealing = readRequiredPersistedBool(
          map['suggestsReannealing'],
          field: 'suggestsReannealing',
          source: source,
        )
        ..isActive = isActive
        ..isDeleted = isDeleted
        ..deletedAt = timestamps.deletedAt
        ..deletedByUid = deletedByUid
        ..deletedByName = deletedByName
        ..deleteReason = deleteReason
        ..version = readRequiredPersistedInt(
          map['version'],
          field: 'version',
          source: source,
          minimum: 1,
        )
        ..isSynced = true
        ..createdAt = timestamps.createdAt
        ..updatedAt = timestamps.updatedAt
        ..createdByUid = createdByUid
        ..createdByName = createdByName
        ..lastEditedByUid = lastEditedByUid
        ..lastEditedByName = lastEditedByName;

  return type;
}

ChargeAbnormality readRemoteChargeAbnormality(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'charge_abnormalities/$documentId';
  final firestoreId = _readDocumentIdentity(map, documentId, source);
  final timestamps = readRemoteChargeAbnormalityTimestamps(map, source: source);
  final sourceChargeNo = readRequiredPersistedInt(
    map['sourceChargeNo'],
    field: 'sourceChargeNo',
    source: source,
    minimum: 1,
  );
  if (!isValidChargeNumber(sourceChargeNo)) {
    throw PersistedDataFormatException(
      field: 'sourceChargeNo',
      source: source,
      detail: 'expected one five-digit charge number',
    );
  }
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  final reannealingStatus = readRequiredPersistedEnum(
    ReannealingStatus.values,
    map['reannealingStatus'],
    field: 'reannealingStatus',
    source: source,
  );
  final reannealedToChargeNo = _readOptionalPositiveInt(
    map['reannealedToChargeNo'],
    field: 'reannealedToChargeNo',
    source: source,
  );
  if (reannealedToChargeNo != null &&
      !isValidChargeNumber(reannealedToChargeNo)) {
    throw PersistedDataFormatException(
      field: 'reannealedToChargeNo',
      source: source,
      detail: 'expected one five-digit charge number',
    );
  }
  final deletedByUid = _readOptionalBoundedString(
    map['deletedByUid'],
    field: 'deletedByUid',
    source: source,
    maximum: 512,
  );
  final deletedByName = _readOptionalBoundedString(
    map['deletedByName'],
    field: 'deletedByName',
    source: source,
    maximum: 500,
  );
  final deleteReason = _readOptionalBoundedString(
    map['deleteReason'],
    field: 'deleteReason',
    source: source,
    maximum: 500,
  );
  final loggedByUid = _readRequiredBoundedString(
    map['loggedByUid'],
    field: 'loggedByUid',
    source: source,
    maximum: 512,
  );
  final loggedByName = _readOptionalBoundedString(
    map['loggedByName'],
    field: 'loggedByName',
    source: source,
    maximum: 500,
  );
  final updatedByUid = _readRequiredBoundedString(
    map['updatedByUid'],
    field: 'updatedByUid',
    source: source,
    maximum: 512,
  );
  final updatedByName = _readOptionalBoundedString(
    map['updatedByName'],
    field: 'updatedByName',
    source: source,
    maximum: 500,
  );
  _requireChargeTimeline(timestamps, source: source);
  _requireReannealingState(
    sourceChargeNo: sourceChargeNo,
    status: reannealingStatus,
    targetChargeNo: reannealedToChargeNo,
    source: source,
  );
  _requireChargeDeletionLifecycle(
    isDeleted: isDeleted,
    deletedAt: timestamps.deletedAt,
    deletedByUid: deletedByUid,
    deletedByName: deletedByName,
    deleteReason: deleteReason,
    firestoreId: firestoreId,
    source: source,
  );

  final affectedAssets = _readAffectedAssetList(
    map['affectedAssets'],
    field: 'affectedAssets',
    source: source,
  );
  final affectedAssetsWithHierarchy = _mergeAffectedAssetHierarchyReferences(
    affectedAssets,
    map['affectedAssetHierarchyRefs'],
    source: source,
  );

  return ChargeAbnormality()
    ..firestoreId = firestoreId
    ..sourceChargeNo = sourceChargeNo
    ..abnormalityTypeId = _readRequiredBoundedString(
      map['abnormalityTypeId'],
      field: 'abnormalityTypeId',
      source: source,
      maximum: 512,
    )
    ..abnormalityTypeTitle = _readRequiredBoundedString(
      map['abnormalityTypeTitle'],
      field: 'abnormalityTypeTitle',
      source: source,
      maximum: 500,
    )
    ..abnormalityTypeCode = _readRequiredBoundedString(
      map['abnormalityTypeCode'],
      field: 'abnormalityTypeCode',
      source: source,
      maximum: 160,
    )
    ..category = readRequiredPersistedEnum(
      AbnormalityCategory.values,
      map['category'],
      field: 'category',
      source: source,
    )
    ..severity = readRequiredPersistedEnum(
      AbnormalitySeverity.values,
      map['severity'],
      field: 'severity',
      source: source,
    )
    ..affectedAssets = affectedAssetsWithHierarchy
    ..component = _readOptionalBoundedString(
      map['component'],
      field: 'component',
      source: source,
      maximum: 200,
    )
    ..observedReason = _readRequiredBoundedString(
      map['observedReason'],
      field: 'observedReason',
      source: source,
      maximum: 2000,
    )
    ..description = _readOptionalBoundedString(
      map['description'],
      field: 'description',
      source: source,
      maximum: 4000,
    )
    ..possibleRootReasonCategory = readRequiredPersistedEnum(
      RootReasonCategory.values,
      map['possibleRootReasonCategory'],
      field: 'possibleRootReasonCategory',
      source: source,
    )
    ..possibleRootReasonNotes = _readOptionalBoundedString(
      map['possibleRootReasonNotes'],
      field: 'possibleRootReasonNotes',
      source: source,
      maximum: 4000,
    )
    ..reannealingStatus = reannealingStatus
    ..reannealedToChargeNo = reannealedToChargeNo
    ..loggedAt = timestamps.loggedAt
    ..updatedAt = timestamps.updatedAt
    ..loggedByUid = loggedByUid
    ..loggedByName = loggedByName
    ..updatedByUid = updatedByUid
    ..updatedByName = updatedByName
    ..linkedTicketFirestoreId = _readOptionalBoundedString(
      map['linkedTicketFirestoreId'],
      field: 'linkedTicketFirestoreId',
      source: source,
      maximum: 512,
    )
    ..linkedExecutionFirestoreId = _readOptionalBoundedString(
      map['linkedExecutionFirestoreId'],
      field: 'linkedExecutionFirestoreId',
      source: source,
      maximum: 512,
    )
    ..version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    )
    ..isSynced = true
    ..isDeleted = isDeleted
    ..deletedAt = timestamps.deletedAt
    ..deletedByUid = deletedByUid
    ..deletedByName = deletedByName
    ..deleteReason = deleteReason;
}

String _readDocumentIdentity(
  Map<String, dynamic> map,
  String documentId,
  String source,
) {
  final firestoreId = _readRequiredBoundedString(
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

String _readRequiredBoundedString(
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

String? _readOptionalBoundedString(
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

int? _readOptionalPositiveInt(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value == null) return null;
  return readRequiredPersistedInt(
    value,
    field: field,
    source: source,
    minimum: 1,
  );
}

List<AssetType> _readApplicableAssetTypes(
  dynamic value, {
  required String source,
}) {
  if (value is! List || value.length > AssetType.values.length) {
    throw PersistedDataFormatException(
      field: 'applicableAssetTypes',
      source: source,
      detail: 'required asset-type array without duplicates',
    );
  }
  final result = <AssetType>[];
  final seen = <AssetType>{};
  for (var index = 0; index < value.length; index++) {
    final type = readRequiredPersistedEnum(
      AssetType.values,
      value[index],
      field: 'applicableAssetTypes[$index]',
      source: source,
    );
    if (!seen.add(type)) {
      throw PersistedDataFormatException(
        field: 'applicableAssetTypes',
        source: source,
        detail: 'duplicate asset type ${type.name}',
      );
    }
    result.add(type);
  }
  return result;
}

List<AffectedAssetRef> _readAffectedAssetList(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value is! List || value.length > 50) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'required array of at most 50 assets (${value.runtimeType})',
    );
  }
  final result = <AffectedAssetRef>[];
  final identities = <String>{};
  for (var index = 0; index < value.length; index++) {
    final raw = value[index];
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'expected an object (${raw.runtimeType})',
      );
    }
    Map<String, dynamic> map;
    try {
      map = Map<String, dynamic>.from(raw);
    } on TypeError {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'object keys must be strings',
      );
    }
    final asset = AffectedAssetRef.fromMap(
      map,
      source: '$source $field[$index]',
    );
    final identity = '${asset.assetType.name}:${asset.assetNumber}';
    if (!identities.add(identity)) {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'must not contain duplicate asset $identity',
      );
    }
    result.add(asset);
  }
  return result;
}

List<AffectedAssetRef> _mergeAffectedAssetHierarchyReferences(
  List<AffectedAssetRef> assets,
  dynamic value, {
  required String source,
}) {
  if (value == null) return assets;
  if (value is! List || value.length > 50) {
    throw PersistedDataFormatException(
      field: 'affectedAssetHierarchyRefs',
      source: source,
      detail: 'expected an optional array of at most 50 governed references',
    );
  }
  final byIdentity = <String, AffectedAssetRef>{
    for (final asset in assets)
      '${asset.assetType.name}:${asset.assetNumber}': asset,
  };
  final governedIdentities = <String>{};
  for (var index = 0; index < value.length; index++) {
    final raw = value[index];
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'affectedAssetHierarchyRefs[$index]',
        source: source,
        detail: 'expected an asset reference object',
      );
    }
    final governed = AffectedAssetRef.fromMap(
      Map<String, dynamic>.from(raw),
      source: '$source affectedAssetHierarchyRefs[$index]',
    );
    final identity = '${governed.assetType.name}:${governed.assetNumber}';
    if (!governed.isGoverned || !byIdentity.containsKey(identity)) {
      throw PersistedDataFormatException(
        field: 'affectedAssetHierarchyRefs[$index]',
        source: source,
        detail: 'must identify one affected asset and its governed hierarchy',
      );
    }
    if (!governedIdentities.add(identity)) {
      throw PersistedDataFormatException(
        field: 'affectedAssetHierarchyRefs',
        source: source,
        detail: 'must not repeat governed reference $identity',
      );
    }
    if (byIdentity[identity]!.isGoverned) {
      throw PersistedDataFormatException(
        field: 'affectedAssetHierarchyRefs[$index]',
        source: source,
        detail: 'must not duplicate an inline governed hierarchy reference',
      );
    }
    byIdentity[identity] = governed;
  }
  return <AffectedAssetRef>[
    for (final asset in assets)
      byIdentity['${asset.assetType.name}:${asset.assetNumber}']!,
  ];
}

void _requireTypeTimeline(
  RemoteAbnormalityTypeTimestamps timestamps, {
  required String source,
}) {
  if (timestamps.updatedAt.isBefore(timestamps.createdAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede createdAt',
    );
  }
  final deletedAt = timestamps.deletedAt;
  if (deletedAt != null && deletedAt.isBefore(timestamps.createdAt)) {
    throw PersistedDataFormatException(
      field: 'deletedAt',
      source: source,
      detail: 'cannot precede createdAt',
    );
  }
  if (deletedAt != null && deletedAt.isAfter(timestamps.updatedAt)) {
    throw PersistedDataFormatException(
      field: 'deletedAt',
      source: source,
      detail: 'cannot follow updatedAt',
    );
  }
}

void _requireChargeTimeline(
  RemoteChargeAbnormalityTimestamps timestamps, {
  required String source,
}) {
  if (timestamps.updatedAt.isBefore(timestamps.loggedAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede loggedAt',
    );
  }
  final deletedAt = timestamps.deletedAt;
  if (deletedAt != null && deletedAt.isBefore(timestamps.loggedAt)) {
    throw PersistedDataFormatException(
      field: 'deletedAt',
      source: source,
      detail: 'cannot precede loggedAt',
    );
  }
  if (deletedAt != null && deletedAt.isAfter(timestamps.updatedAt)) {
    throw PersistedDataFormatException(
      field: 'deletedAt',
      source: source,
      detail: 'cannot follow updatedAt',
    );
  }
}

void _requireTypeLifecycle({
  required bool isDeleted,
  required bool isActive,
  required DateTime? deletedAt,
  required String? deletedByUid,
  required String? deletedByName,
  required String? deleteReason,
  required String firestoreId,
  required String source,
}) {
  if (isDeleted) {
    requireRemoteTombstoneDeletedAt(
      deletedAt,
      entityLabel: 'abnormality type',
      firestoreId: firestoreId,
    );
    if (isActive) {
      throw PersistedDataFormatException(
        field: 'isActive',
        source: source,
        detail: 'deleted abnormality types cannot remain active',
      );
    }
    if (deletedByUid == null) {
      throw PersistedDataFormatException(
        field: 'deletedByUid',
        source: source,
        detail: 'deleted abnormality types require deletion authority',
      );
    }
  } else if (deletedAt != null ||
      deletedByUid != null ||
      deletedByName != null ||
      deleteReason != null) {
    throw PersistedDataFormatException(
      field: 'isDeleted',
      source: source,
      detail: 'non-deleted abnormality types cannot carry deletion state',
    );
  }
  _requireActorNamePair(
    uid: deletedByUid,
    name: deletedByName,
    uidField: 'deletedByUid',
    nameField: 'deletedByName',
    source: source,
  );
}

void _requireReannealingState({
  required int sourceChargeNo,
  required ReannealingStatus status,
  required int? targetChargeNo,
  required String source,
}) {
  final completed = status == ReannealingStatus.completed;
  if (completed != (targetChargeNo != null)) {
    throw PersistedDataFormatException(
      field: 'reannealingStatus',
      source: source,
      detail: 'completed status and target charge must be present together',
    );
  }
  if (targetChargeNo == sourceChargeNo) {
    throw PersistedDataFormatException(
      field: 'reannealedToChargeNo',
      source: source,
      detail: 'must differ from sourceChargeNo',
    );
  }
}

void _requireChargeDeletionLifecycle({
  required bool isDeleted,
  required DateTime? deletedAt,
  required String? deletedByUid,
  required String? deletedByName,
  required String? deleteReason,
  required String firestoreId,
  required String source,
}) {
  if (isDeleted) {
    requireRemoteTombstoneDeletedAt(
      deletedAt,
      entityLabel: 'charge abnormality',
      firestoreId: firestoreId,
    );
    if (deletedByUid == null) {
      throw PersistedDataFormatException(
        field: 'deletedByUid',
        source: source,
        detail: 'deleted abnormalities require deletion authority',
      );
    }
    if (deletedByName == null) {
      throw PersistedDataFormatException(
        field: 'deletedByName',
        source: source,
        detail: 'deleted abnormalities require the actor display name',
      );
    }
    if (deleteReason == null) {
      throw PersistedDataFormatException(
        field: 'deleteReason',
        source: source,
        detail: 'deleted abnormalities require a reason',
      );
    }
  } else if (deletedAt != null ||
      deletedByUid != null ||
      deletedByName != null ||
      deleteReason != null) {
    throw PersistedDataFormatException(
      field: 'isDeleted',
      source: source,
      detail: 'active abnormalities cannot carry deletion state',
    );
  }
}

void _requireActorNamePair({
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
