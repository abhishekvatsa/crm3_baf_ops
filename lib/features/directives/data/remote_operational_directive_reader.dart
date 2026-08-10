import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/utils/asset_validator.dart';
import 'operational_directive_model.dart';
import 'remote_operational_directive_timestamps.dart';

OperationalDirective readRemoteOperationalDirective(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'directives/$documentId';
  final firestoreId = readRequiredPersistedString(
    map['firestoreId'],
    field: 'firestoreId',
    source: source,
  );
  if (firestoreId != documentId) {
    throw PersistedDataFormatException(
      field: 'firestoreId',
      source: source,
      detail: 'must match the document ID',
    );
  }

  final createdByUid = readRequiredPersistedString(
    map['createdByUid'],
    field: 'createdByUid',
    source: source,
  );
  final issuedByUid = readRequiredPersistedString(
    map['issuedByUid'],
    field: 'issuedByUid',
    source: source,
  );
  if (createdByUid != issuedByUid) {
    throw PersistedDataFormatException(
      field: 'issuedByUid',
      source: source,
      detail: 'must match createdByUid',
    );
  }

  final assetType = readOptionalPersistedEnum(
    AssetType.values,
    map['assetType'],
    field: 'assetType',
    source: source,
  );
  final assetNumber = _readOptionalPositiveInt(
    map['assetNumber'],
    field: 'assetNumber',
    source: source,
  );
  if ((assetType == null) != (assetNumber == null)) {
    throw PersistedDataFormatException(
      field: assetType == null ? 'assetType' : 'assetNumber',
      source: source,
      detail: 'assetType and assetNumber must be present together',
    );
  }
  if (assetType != null && !AssetValidator.isValid(assetType, assetNumber!)) {
    throw PersistedDataFormatException(
      field: 'assetNumber',
      source: source,
      detail: 'outside the governed range for ${assetType.name}',
    );
  }

  final status = readRequiredPersistedEnum(
    DirectiveStatus.values,
    map['status'],
    field: 'status',
    source: source,
  );
  final isActive = readRequiredPersistedBool(
    map['isActive'],
    field: 'isActive',
    source: source,
  );
  final closedWithoutAcknowledgement = readRequiredPersistedBool(
    map['closedWithoutAcknowledgement'],
    field: 'closedWithoutAcknowledgement',
    source: source,
  );
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );
  final timestamps = readRemoteOperationalDirectiveTimestamps(
    map,
    source: source,
  );
  final version = readRequiredPersistedInt(
    map['version'],
    field: 'version',
    source: source,
    minimum: 1,
  );

  final acknowledgedByUid = readOptionalPersistedString(
    map['acknowledgedByUid'],
    field: 'acknowledgedByUid',
    source: source,
  );
  final acknowledgedByName = readOptionalPersistedString(
    map['acknowledgedByName'],
    field: 'acknowledgedByName',
    source: source,
  );
  final closedByUid = readOptionalPersistedString(
    map['closedByUid'],
    field: 'closedByUid',
    source: source,
  );
  final closedByName = readOptionalPersistedString(
    map['closedByName'],
    field: 'closedByName',
    source: source,
  );
  final deletedByUid = readOptionalPersistedString(
    map['deletedByUid'],
    field: 'deletedByUid',
    source: source,
  );
  final deletedByName = readOptionalPersistedString(
    map['deletedByName'],
    field: 'deletedByName',
    source: source,
  );
  final deleteReason = readOptionalPersistedString(
    map['deleteReason'],
    field: 'deleteReason',
    source: source,
  );

  _requireTimeline(timestamps: timestamps, source: source);
  _requireLifecycle(
    status: status,
    isActive: isActive,
    acknowledgedByUid: acknowledgedByUid,
    acknowledgedByName: acknowledgedByName,
    acknowledgedAt: timestamps.acknowledgedAt,
    closedByUid: closedByUid,
    closedByName: closedByName,
    closedAt: timestamps.closedAt,
    closedWithoutAcknowledgement: closedWithoutAcknowledgement,
    isDeleted: isDeleted,
    deletedAt: timestamps.deletedAt,
    deletedByUid: deletedByUid,
    deletedByName: deletedByName,
    deleteReason: deleteReason,
    source: source,
  );

  return OperationalDirective()
    ..firestoreId = firestoreId
    ..title = readRequiredPersistedString(
      map['title'],
      field: 'title',
      source: source,
    )
    ..description = readRequiredPersistedString(
      map['description'],
      field: 'description',
      source: source,
    )
    ..assetType = assetType
    ..assetNumber = assetNumber
    ..component = _readOptionalString(map, 'component', source)
    ..subsystem = _readOptionalString(map, 'subsystem', source)
    ..tag = _readOptionalString(map, 'tag', source)
    ..hierarchyPath = readNullablePersistedStringList(
      map['hierarchyPath'],
      field: 'hierarchyPath',
      source: source,
    )
    ..directedTo = readRequiredPersistedEnum(
      AppRole.values,
      map['directedTo'],
      field: 'directedTo',
      source: source,
    )
    ..status = status
    ..priority = readRequiredPersistedEnum(
      DirectivePriority.values,
      map['priority'],
      field: 'priority',
      source: source,
    )
    ..createdByUid = createdByUid
    ..createdByName = _readOptionalString(map, 'createdByName', source)
    ..issuedByUid = issuedByUid
    ..issuedByName = _readOptionalString(map, 'issuedByName', source)
    ..issuedAt = timestamps.issuedAt
    ..isActive = isActive
    ..acknowledgedByUid = acknowledgedByUid
    ..acknowledgedByName = acknowledgedByName
    ..acknowledgedAt = timestamps.acknowledgedAt
    ..closedByUid = closedByUid
    ..closedByName = closedByName
    ..closedAt = timestamps.closedAt
    ..closedWithoutAcknowledgement = closedWithoutAcknowledgement
    ..remarks = _readOptionalString(map, 'remarks', source)
    ..linkedMaintenanceFirestoreId = _readOptionalString(
      map,
      'linkedMaintenanceFirestoreId',
      source,
    )
    ..linkedExecutionFirestoreId = _readOptionalString(
      map,
      'linkedExecutionFirestoreId',
      source,
    )
    ..metadataJson = _readOptionalJsonText(map['metadataJson'], source: source)
    ..isDeleted = isDeleted
    ..deletedAt = timestamps.deletedAt
    ..deletedByUid = deletedByUid
    ..deletedByName = deletedByName
    ..deleteReason = deleteReason
    ..createdAt = timestamps.createdAt
    ..updatedAt = timestamps.updatedAt
    ..version = version
    ..isSynced = true;
}

String? _readOptionalString(
  Map<String, dynamic> map,
  String field,
  String source,
) => readOptionalPersistedString(map[field], field: field, source: source);

int? _readOptionalPositiveInt(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value == null) return null;
  if (value is int && value >= 1) return value;
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'expected an integer >= 1 (${value.runtimeType})',
  );
}

String? _readOptionalJsonText(dynamic value, {required String source}) {
  final text = readOptionalPersistedString(
    value,
    field: 'metadataJson',
    source: source,
  );
  if (text == null) return null;
  readOptionalJsonObject(text, field: 'metadataJson', source: source);
  return text;
}

void _requireTimeline({
  required RemoteOperationalDirectiveTimestamps timestamps,
  required String source,
}) {
  if (timestamps.updatedAt.isBefore(timestamps.createdAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede createdAt',
    );
  }
  final events = <String, DateTime?>{
    'issuedAt': timestamps.issuedAt,
    'acknowledgedAt': timestamps.acknowledgedAt,
    'closedAt': timestamps.closedAt,
    'deletedAt': timestamps.deletedAt,
  };
  for (final entry in events.entries) {
    final value = entry.value;
    if (value != null && value.isBefore(timestamps.createdAt)) {
      throw PersistedDataFormatException(
        field: entry.key,
        source: source,
        detail: 'cannot precede createdAt',
      );
    }
    if (value != null && value.isAfter(timestamps.updatedAt)) {
      throw PersistedDataFormatException(
        field: entry.key,
        source: source,
        detail: 'cannot follow updatedAt',
      );
    }
  }
}

void _requireLifecycle({
  required DirectiveStatus status,
  required bool isActive,
  required String? acknowledgedByUid,
  required String? acknowledgedByName,
  required DateTime? acknowledgedAt,
  required String? closedByUid,
  required String? closedByName,
  required DateTime? closedAt,
  required bool closedWithoutAcknowledgement,
  required bool isDeleted,
  required DateTime? deletedAt,
  required String? deletedByUid,
  required String? deletedByName,
  required String? deleteReason,
  required String source,
}) {
  final shouldBeActive = status != DirectiveStatus.closed;
  if (isActive != shouldBeActive) {
    throw PersistedDataFormatException(
      field: 'isActive',
      source: source,
      detail: 'does not match status ${status.name}',
    );
  }

  if ((acknowledgedByUid == null) != (acknowledgedAt == null)) {
    throw PersistedDataFormatException(
      field: acknowledgedByUid == null ? 'acknowledgedByUid' : 'acknowledgedAt',
      source: source,
      detail: 'acknowledgement actor and timestamp must be present together',
    );
  }
  if (acknowledgedByName != null && acknowledgedByUid == null) {
    throw PersistedDataFormatException(
      field: 'acknowledgedByName',
      source: source,
      detail: 'cannot exist without acknowledgedByUid',
    );
  }
  if ((closedByUid == null) != (closedAt == null)) {
    throw PersistedDataFormatException(
      field: closedByUid == null ? 'closedByUid' : 'closedAt',
      source: source,
      detail: 'closure actor and timestamp must be present together',
    );
  }
  if (closedByName != null && closedByUid == null) {
    throw PersistedDataFormatException(
      field: 'closedByName',
      source: source,
      detail: 'cannot exist without closedByUid',
    );
  }

  if (status == DirectiveStatus.open && acknowledgedAt != null) {
    throw PersistedDataFormatException(
      field: 'acknowledgedAt',
      source: source,
      detail: 'open directives cannot carry acknowledgement state',
    );
  }
  if (status == DirectiveStatus.acknowledged && acknowledgedAt == null) {
    throw PersistedDataFormatException(
      field: 'acknowledgedAt',
      source: source,
      detail: 'acknowledged directives require acknowledgement state',
    );
  }
  if (status != DirectiveStatus.closed && closedAt != null) {
    throw PersistedDataFormatException(
      field: 'closedAt',
      source: source,
      detail: 'only closed directives may carry closure state',
    );
  }
  if (status == DirectiveStatus.closed && closedAt == null) {
    throw PersistedDataFormatException(
      field: 'closedAt',
      source: source,
      detail: 'closed directives require closure state',
    );
  }
  if (status != DirectiveStatus.closed && closedWithoutAcknowledgement) {
    throw PersistedDataFormatException(
      field: 'closedWithoutAcknowledgement',
      source: source,
      detail: 'may be true only for a closed directive',
    );
  }
  if (closedWithoutAcknowledgement && acknowledgedAt != null) {
    throw PersistedDataFormatException(
      field: 'closedWithoutAcknowledgement',
      source: source,
      detail: 'contradicts persisted acknowledgement state',
    );
  }
  if (isDeleted != (deletedAt != null)) {
    throw PersistedDataFormatException(
      field: 'deletedAt',
      source: source,
      detail: 'must be present exactly when isDeleted is true',
    );
  }
  if (isDeleted && deletedByUid == null) {
    throw PersistedDataFormatException(
      field: 'deletedByUid',
      source: source,
      detail: 'deleted directives require deletion actor authority',
    );
  }
  if (deletedByName != null && deletedByUid == null) {
    throw PersistedDataFormatException(
      field: 'deletedByName',
      source: source,
      detail: 'cannot exist without deletedByUid',
    );
  }
  if (!isDeleted &&
      (deletedByUid != null || deletedByName != null || deleteReason != null)) {
    throw PersistedDataFormatException(
      field:
          deletedByUid != null
              ? 'deletedByUid'
              : deletedByName != null
              ? 'deletedByName'
              : 'deleteReason',
      source: source,
      detail: 'non-deleted directives cannot carry deletion state',
    );
  }
}
