// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMaintenanceRecordCollection on Isar {
  IsarCollection<MaintenanceRecord> get maintenanceRecords => this.collection();
}

const MaintenanceRecordSchema = CollectionSchema(
  name: r'MaintenanceRecord',
  id: 8394037719530270343,
  properties: {
    r'acknowledgedAt': PropertySchema(
      id: 0,
      name: r'acknowledgedAt',
      type: IsarType.dateTime,
    ),
    r'acknowledgedByName': PropertySchema(
      id: 1,
      name: r'acknowledgedByName',
      type: IsarType.string,
    ),
    r'acknowledgedByUid': PropertySchema(
      id: 2,
      name: r'acknowledgedByUid',
      type: IsarType.string,
    ),
    r'actionsJson': PropertySchema(
      id: 3,
      name: r'actionsJson',
      type: IsarType.string,
    ),
    r'assetHierarchyRefJson': PropertySchema(
      id: 4,
      name: r'assetHierarchyRefJson',
      type: IsarType.string,
    ),
    r'assetNumber': PropertySchema(
      id: 5,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetType': PropertySchema(
      id: 6,
      name: r'assetType',
      type: IsarType.string,
      enumMap: _MaintenanceRecordassetTypeEnumValueMap,
    ),
    r'chargeNoAtEvent': PropertySchema(
      id: 7,
      name: r'chargeNoAtEvent',
      type: IsarType.long,
    ),
    r'classification': PropertySchema(
      id: 8,
      name: r'classification',
      type: IsarType.string,
    ),
    r'closedByName': PropertySchema(
      id: 9,
      name: r'closedByName',
      type: IsarType.string,
    ),
    r'closedByUid': PropertySchema(
      id: 10,
      name: r'closedByUid',
      type: IsarType.string,
    ),
    r'component': PropertySchema(
      id: 11,
      name: r'component',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 12,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'debugLabel': PropertySchema(
      id: 13,
      name: r'debugLabel',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 14,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 15,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 16,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 17,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 18,
      name: r'description',
      type: IsarType.string,
    ),
    r'downtimeHours': PropertySchema(
      id: 19,
      name: r'downtimeHours',
      type: IsarType.double,
    ),
    r'endDate': PropertySchema(
      id: 20,
      name: r'endDate',
      type: IsarType.dateTime,
    ),
    r'firestoreId': PropertySchema(
      id: 21,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'hasComponentContext': PropertySchema(
      id: 22,
      name: r'hasComponentContext',
      type: IsarType.bool,
    ),
    r'hierarchyPath': PropertySchema(
      id: 23,
      name: r'hierarchyPath',
      type: IsarType.stringList,
    ),
    r'isClosed': PropertySchema(
      id: 24,
      name: r'isClosed',
      type: IsarType.bool,
    ),
    r'isCritical': PropertySchema(
      id: 25,
      name: r'isCritical',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 26,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isOpen': PropertySchema(
      id: 27,
      name: r'isOpen',
      type: IsarType.bool,
    ),
    r'isResolved': PropertySchema(
      id: 28,
      name: r'isResolved',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 29,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'loggedByName': PropertySchema(
      id: 30,
      name: r'loggedByName',
      type: IsarType.string,
    ),
    r'loggedByUid': PropertySchema(
      id: 31,
      name: r'loggedByUid',
      type: IsarType.string,
    ),
    r'maintenanceType': PropertySchema(
      id: 32,
      name: r'maintenanceType',
      type: IsarType.string,
      enumMap: _MaintenanceRecordmaintenanceTypeEnumValueMap,
    ),
    r'metadataJson': PropertySchema(
      id: 33,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'operationalEventIssueLinkIds': PropertySchema(
      id: 34,
      name: r'operationalEventIssueLinkIds',
      type: IsarType.stringList,
    ),
    r'otherDepartment': PropertySchema(
      id: 35,
      name: r'otherDepartment',
      type: IsarType.string,
    ),
    r'performedBy': PropertySchema(
      id: 36,
      name: r'performedBy',
      type: IsarType.string,
    ),
    r'remarks': PropertySchema(
      id: 37,
      name: r'remarks',
      type: IsarType.string,
    ),
    r'reopenReason': PropertySchema(
      id: 38,
      name: r'reopenReason',
      type: IsarType.string,
    ),
    r'reopenedAt': PropertySchema(
      id: 39,
      name: r'reopenedAt',
      type: IsarType.dateTime,
    ),
    r'reopenedByName': PropertySchema(
      id: 40,
      name: r'reopenedByName',
      type: IsarType.string,
    ),
    r'reopenedByUid': PropertySchema(
      id: 41,
      name: r'reopenedByUid',
      type: IsarType.string,
    ),
    r'reportedBy': PropertySchema(
      id: 42,
      name: r'reportedBy',
      type: IsarType.string,
    ),
    r'resolutionHistoryJson': PropertySchema(
      id: 43,
      name: r'resolutionHistoryJson',
      type: IsarType.string,
    ),
    r'routedTo': PropertySchema(
      id: 44,
      name: r'routedTo',
      type: IsarType.string,
      enumMap: _MaintenanceRecordroutedToEnumValueMap,
    ),
    r'startDate': PropertySchema(
      id: 45,
      name: r'startDate',
      type: IsarType.dateTime,
    ),
    r'status': PropertySchema(
      id: 46,
      name: r'status',
      type: IsarType.string,
      enumMap: _MaintenanceRecordstatusEnumValueMap,
    ),
    r'subsystem': PropertySchema(
      id: 47,
      name: r'subsystem',
      type: IsarType.string,
    ),
    r'tag': PropertySchema(
      id: 48,
      name: r'tag',
      type: IsarType.string,
    ),
    r'teamsInvolved': PropertySchema(
      id: 49,
      name: r'teamsInvolved',
      type: IsarType.stringList,
    ),
    r'updatedAt': PropertySchema(
      id: 50,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 51,
      name: r'version',
      type: IsarType.long,
    ),
    r'workflowAggregateId': PropertySchema(
      id: 52,
      name: r'workflowAggregateId',
      type: IsarType.string,
    ),
    r'workflowComplianceId': PropertySchema(
      id: 53,
      name: r'workflowComplianceId',
      type: IsarType.string,
    ),
    r'workflowConditionRef': PropertySchema(
      id: 54,
      name: r'workflowConditionRef',
      type: IsarType.string,
    ),
    r'workflowConditionTypeKey': PropertySchema(
      id: 55,
      name: r'workflowConditionTypeKey',
      type: IsarType.string,
    ),
    r'workflowCorrectionReason': PropertySchema(
      id: 56,
      name: r'workflowCorrectionReason',
      type: IsarType.string,
    ),
    r'workflowDeferred': PropertySchema(
      id: 57,
      name: r'workflowDeferred',
      type: IsarType.bool,
    ),
    r'workflowDeferredAt': PropertySchema(
      id: 58,
      name: r'workflowDeferredAt',
      type: IsarType.dateTime,
    ),
    r'workflowDeferredByName': PropertySchema(
      id: 59,
      name: r'workflowDeferredByName',
      type: IsarType.string,
    ),
    r'workflowDeferredByUid': PropertySchema(
      id: 60,
      name: r'workflowDeferredByUid',
      type: IsarType.string,
    ),
    r'workflowOriginLaneKey': PropertySchema(
      id: 61,
      name: r'workflowOriginLaneKey',
      type: IsarType.string,
    ),
    r'workflowQueueState': PropertySchema(
      id: 62,
      name: r'workflowQueueState',
      type: IsarType.string,
    ),
    r'workflowReactivatedAt': PropertySchema(
      id: 63,
      name: r'workflowReactivatedAt',
      type: IsarType.dateTime,
    ),
    r'workflowReactivatedByName': PropertySchema(
      id: 64,
      name: r'workflowReactivatedByName',
      type: IsarType.string,
    ),
    r'workflowReactivatedByUid': PropertySchema(
      id: 65,
      name: r'workflowReactivatedByUid',
      type: IsarType.string,
    ),
    r'workflowReleasedAt': PropertySchema(
      id: 66,
      name: r'workflowReleasedAt',
      type: IsarType.dateTime,
    ),
    r'workflowReleasedByName': PropertySchema(
      id: 67,
      name: r'workflowReleasedByName',
      type: IsarType.string,
    ),
    r'workflowReleasedByUid': PropertySchema(
      id: 68,
      name: r'workflowReleasedByUid',
      type: IsarType.string,
    ),
    r'workflowTargetLaneKey': PropertySchema(
      id: 69,
      name: r'workflowTargetLaneKey',
      type: IsarType.string,
    ),
    r'workflowUpdatedAt': PropertySchema(
      id: 70,
      name: r'workflowUpdatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _maintenanceRecordEstimateSize,
  serialize: _maintenanceRecordSerialize,
  deserialize: _maintenanceRecordDeserialize,
  deserializeProp: _maintenanceRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'isSynced': IndexSchema(
      id: -39763503327887510,
      name: r'isSynced',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isSynced',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isCritical': IndexSchema(
      id: -4049092732655300237,
      name: r'isCritical',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isCritical',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isResolved': IndexSchema(
      id: 2669446589477246375,
      name: r'isResolved',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isResolved',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'workflowDeferred': IndexSchema(
      id: 8143402864508404568,
      name: r'workflowDeferred',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workflowDeferred',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'workflowQueueState': IndexSchema(
      id: 635631872922716470,
      name: r'workflowQueueState',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workflowQueueState',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'workflowAggregateId': IndexSchema(
      id: -1039964421306686580,
      name: r'workflowAggregateId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workflowAggregateId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'workflowComplianceId': IndexSchema(
      id: 4790428875013184106,
      name: r'workflowComplianceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workflowComplianceId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'loggedByUid': IndexSchema(
      id: 2935914899007439258,
      name: r'loggedByUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'loggedByUid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'updatedAt': IndexSchema(
      id: -6238191080293565125,
      name: r'updatedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updatedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _maintenanceRecordGetId,
  getLinks: _maintenanceRecordGetLinks,
  attach: _maintenanceRecordAttach,
  version: '3.1.0+1',
);

int _maintenanceRecordEstimateSize(
  MaintenanceRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.acknowledgedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.acknowledgedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.actionsJson.length * 3;
  {
    final value = object.assetHierarchyRefJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.assetType.name.length * 3;
  {
    final value = object.classification;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.closedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.closedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.component;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.debugLabel.length * 3;
  {
    final value = object.deleteReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.deletedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.deletedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.description.length * 3;
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final list = object.hierarchyPath;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  {
    final value = object.loggedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.loggedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.maintenanceType.name.length * 3;
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.operationalEventIssueLinkIds.length * 3;
  {
    for (var i = 0; i < object.operationalEventIssueLinkIds.length; i++) {
      final value = object.operationalEventIssueLinkIds[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.otherDepartment;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.performedBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.remarks;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reopenReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reopenedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reopenedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reportedBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.resolutionHistoryJson.length * 3;
  bytesCount += 3 + object.routedTo.name.length * 3;
  bytesCount += 3 + object.status.name.length * 3;
  {
    final value = object.subsystem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.tag;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.teamsInvolved.length * 3;
  {
    for (var i = 0; i < object.teamsInvolved.length; i++) {
      final value = object.teamsInvolved[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.workflowAggregateId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowComplianceId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowConditionRef;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowConditionTypeKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowCorrectionReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowDeferredByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowDeferredByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowOriginLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.workflowQueueState.length * 3;
  {
    final value = object.workflowReactivatedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowReactivatedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowReleasedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowReleasedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.workflowTargetLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _maintenanceRecordSerialize(
  MaintenanceRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acknowledgedAt);
  writer.writeString(offsets[1], object.acknowledgedByName);
  writer.writeString(offsets[2], object.acknowledgedByUid);
  writer.writeString(offsets[3], object.actionsJson);
  writer.writeString(offsets[4], object.assetHierarchyRefJson);
  writer.writeLong(offsets[5], object.assetNumber);
  writer.writeString(offsets[6], object.assetType.name);
  writer.writeLong(offsets[7], object.chargeNoAtEvent);
  writer.writeString(offsets[8], object.classification);
  writer.writeString(offsets[9], object.closedByName);
  writer.writeString(offsets[10], object.closedByUid);
  writer.writeString(offsets[11], object.component);
  writer.writeDateTime(offsets[12], object.createdAt);
  writer.writeString(offsets[13], object.debugLabel);
  writer.writeString(offsets[14], object.deleteReason);
  writer.writeDateTime(offsets[15], object.deletedAt);
  writer.writeString(offsets[16], object.deletedByName);
  writer.writeString(offsets[17], object.deletedByUid);
  writer.writeString(offsets[18], object.description);
  writer.writeDouble(offsets[19], object.downtimeHours);
  writer.writeDateTime(offsets[20], object.endDate);
  writer.writeString(offsets[21], object.firestoreId);
  writer.writeBool(offsets[22], object.hasComponentContext);
  writer.writeStringList(offsets[23], object.hierarchyPath);
  writer.writeBool(offsets[24], object.isClosed);
  writer.writeBool(offsets[25], object.isCritical);
  writer.writeBool(offsets[26], object.isDeleted);
  writer.writeBool(offsets[27], object.isOpen);
  writer.writeBool(offsets[28], object.isResolved);
  writer.writeBool(offsets[29], object.isSynced);
  writer.writeString(offsets[30], object.loggedByName);
  writer.writeString(offsets[31], object.loggedByUid);
  writer.writeString(offsets[32], object.maintenanceType.name);
  writer.writeString(offsets[33], object.metadataJson);
  writer.writeStringList(offsets[34], object.operationalEventIssueLinkIds);
  writer.writeString(offsets[35], object.otherDepartment);
  writer.writeString(offsets[36], object.performedBy);
  writer.writeString(offsets[37], object.remarks);
  writer.writeString(offsets[38], object.reopenReason);
  writer.writeDateTime(offsets[39], object.reopenedAt);
  writer.writeString(offsets[40], object.reopenedByName);
  writer.writeString(offsets[41], object.reopenedByUid);
  writer.writeString(offsets[42], object.reportedBy);
  writer.writeString(offsets[43], object.resolutionHistoryJson);
  writer.writeString(offsets[44], object.routedTo.name);
  writer.writeDateTime(offsets[45], object.startDate);
  writer.writeString(offsets[46], object.status.name);
  writer.writeString(offsets[47], object.subsystem);
  writer.writeString(offsets[48], object.tag);
  writer.writeStringList(offsets[49], object.teamsInvolved);
  writer.writeDateTime(offsets[50], object.updatedAt);
  writer.writeLong(offsets[51], object.version);
  writer.writeString(offsets[52], object.workflowAggregateId);
  writer.writeString(offsets[53], object.workflowComplianceId);
  writer.writeString(offsets[54], object.workflowConditionRef);
  writer.writeString(offsets[55], object.workflowConditionTypeKey);
  writer.writeString(offsets[56], object.workflowCorrectionReason);
  writer.writeBool(offsets[57], object.workflowDeferred);
  writer.writeDateTime(offsets[58], object.workflowDeferredAt);
  writer.writeString(offsets[59], object.workflowDeferredByName);
  writer.writeString(offsets[60], object.workflowDeferredByUid);
  writer.writeString(offsets[61], object.workflowOriginLaneKey);
  writer.writeString(offsets[62], object.workflowQueueState);
  writer.writeDateTime(offsets[63], object.workflowReactivatedAt);
  writer.writeString(offsets[64], object.workflowReactivatedByName);
  writer.writeString(offsets[65], object.workflowReactivatedByUid);
  writer.writeDateTime(offsets[66], object.workflowReleasedAt);
  writer.writeString(offsets[67], object.workflowReleasedByName);
  writer.writeString(offsets[68], object.workflowReleasedByUid);
  writer.writeString(offsets[69], object.workflowTargetLaneKey);
  writer.writeDateTime(offsets[70], object.workflowUpdatedAt);
}

MaintenanceRecord _maintenanceRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MaintenanceRecord();
  object.acknowledgedAt = reader.readDateTimeOrNull(offsets[0]);
  object.acknowledgedByName = reader.readStringOrNull(offsets[1]);
  object.acknowledgedByUid = reader.readStringOrNull(offsets[2]);
  object.actionsJson = reader.readString(offsets[3]);
  object.assetHierarchyRefJson = reader.readStringOrNull(offsets[4]);
  object.assetNumber = reader.readLong(offsets[5]);
  object.assetType = _MaintenanceRecordassetTypeValueEnumMap[
          reader.readStringOrNull(offsets[6])] ??
      AssetType.base;
  object.chargeNoAtEvent = reader.readLongOrNull(offsets[7]);
  object.classification = reader.readStringOrNull(offsets[8]);
  object.closedByName = reader.readStringOrNull(offsets[9]);
  object.closedByUid = reader.readStringOrNull(offsets[10]);
  object.component = reader.readStringOrNull(offsets[11]);
  object.createdAt = reader.readDateTime(offsets[12]);
  object.deleteReason = reader.readStringOrNull(offsets[14]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[15]);
  object.deletedByName = reader.readStringOrNull(offsets[16]);
  object.deletedByUid = reader.readStringOrNull(offsets[17]);
  object.description = reader.readString(offsets[18]);
  object.downtimeHours = reader.readDoubleOrNull(offsets[19]);
  object.endDate = reader.readDateTimeOrNull(offsets[20]);
  object.firestoreId = reader.readStringOrNull(offsets[21]);
  object.hierarchyPath = reader.readStringList(offsets[23]);
  object.id = id;
  object.isCritical = reader.readBool(offsets[25]);
  object.isDeleted = reader.readBool(offsets[26]);
  object.isResolved = reader.readBool(offsets[28]);
  object.isSynced = reader.readBool(offsets[29]);
  object.loggedByName = reader.readStringOrNull(offsets[30]);
  object.loggedByUid = reader.readStringOrNull(offsets[31]);
  object.maintenanceType = _MaintenanceRecordmaintenanceTypeValueEnumMap[
          reader.readStringOrNull(offsets[32])] ??
      MaintenanceType.scheduled;
  object.metadataJson = reader.readStringOrNull(offsets[33]);
  object.operationalEventIssueLinkIds =
      reader.readStringList(offsets[34]) ?? [];
  object.otherDepartment = reader.readStringOrNull(offsets[35]);
  object.performedBy = reader.readStringOrNull(offsets[36]);
  object.remarks = reader.readStringOrNull(offsets[37]);
  object.reopenReason = reader.readStringOrNull(offsets[38]);
  object.reopenedAt = reader.readDateTimeOrNull(offsets[39]);
  object.reopenedByName = reader.readStringOrNull(offsets[40]);
  object.reopenedByUid = reader.readStringOrNull(offsets[41]);
  object.reportedBy = reader.readStringOrNull(offsets[42]);
  object.resolutionHistoryJson = reader.readString(offsets[43]);
  object.routedTo = _MaintenanceRecordroutedToValueEnumMap[
          reader.readStringOrNull(offsets[44])] ??
      RoutedTo.operations;
  object.startDate = reader.readDateTime(offsets[45]);
  object.status = _MaintenanceRecordstatusValueEnumMap[
          reader.readStringOrNull(offsets[46])] ??
      TicketStatus.open;
  object.subsystem = reader.readStringOrNull(offsets[47]);
  object.tag = reader.readStringOrNull(offsets[48]);
  object.teamsInvolved = reader.readStringList(offsets[49]) ?? [];
  object.updatedAt = reader.readDateTime(offsets[50]);
  object.version = reader.readLong(offsets[51]);
  object.workflowAggregateId = reader.readStringOrNull(offsets[52]);
  object.workflowComplianceId = reader.readStringOrNull(offsets[53]);
  object.workflowConditionRef = reader.readStringOrNull(offsets[54]);
  object.workflowConditionTypeKey = reader.readStringOrNull(offsets[55]);
  object.workflowCorrectionReason = reader.readStringOrNull(offsets[56]);
  object.workflowDeferred = reader.readBool(offsets[57]);
  object.workflowDeferredAt = reader.readDateTimeOrNull(offsets[58]);
  object.workflowDeferredByName = reader.readStringOrNull(offsets[59]);
  object.workflowDeferredByUid = reader.readStringOrNull(offsets[60]);
  object.workflowOriginLaneKey = reader.readStringOrNull(offsets[61]);
  object.workflowQueueState = reader.readString(offsets[62]);
  object.workflowReactivatedAt = reader.readDateTimeOrNull(offsets[63]);
  object.workflowReactivatedByName = reader.readStringOrNull(offsets[64]);
  object.workflowReactivatedByUid = reader.readStringOrNull(offsets[65]);
  object.workflowReleasedAt = reader.readDateTimeOrNull(offsets[66]);
  object.workflowReleasedByName = reader.readStringOrNull(offsets[67]);
  object.workflowReleasedByUid = reader.readStringOrNull(offsets[68]);
  object.workflowTargetLaneKey = reader.readStringOrNull(offsets[69]);
  object.workflowUpdatedAt = reader.readDateTimeOrNull(offsets[70]);
  return object;
}

P _maintenanceRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (_MaintenanceRecordassetTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AssetType.base) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readDateTime(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readDoubleOrNull(offset)) as P;
    case 20:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readBool(offset)) as P;
    case 23:
      return (reader.readStringList(offset)) as P;
    case 24:
      return (reader.readBool(offset)) as P;
    case 25:
      return (reader.readBool(offset)) as P;
    case 26:
      return (reader.readBool(offset)) as P;
    case 27:
      return (reader.readBool(offset)) as P;
    case 28:
      return (reader.readBool(offset)) as P;
    case 29:
      return (reader.readBool(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readStringOrNull(offset)) as P;
    case 32:
      return (_MaintenanceRecordmaintenanceTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          MaintenanceType.scheduled) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringList(offset) ?? []) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readStringOrNull(offset)) as P;
    case 37:
      return (reader.readStringOrNull(offset)) as P;
    case 38:
      return (reader.readStringOrNull(offset)) as P;
    case 39:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 40:
      return (reader.readStringOrNull(offset)) as P;
    case 41:
      return (reader.readStringOrNull(offset)) as P;
    case 42:
      return (reader.readStringOrNull(offset)) as P;
    case 43:
      return (reader.readString(offset)) as P;
    case 44:
      return (_MaintenanceRecordroutedToValueEnumMap[
              reader.readStringOrNull(offset)] ??
          RoutedTo.operations) as P;
    case 45:
      return (reader.readDateTime(offset)) as P;
    case 46:
      return (_MaintenanceRecordstatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          TicketStatus.open) as P;
    case 47:
      return (reader.readStringOrNull(offset)) as P;
    case 48:
      return (reader.readStringOrNull(offset)) as P;
    case 49:
      return (reader.readStringList(offset) ?? []) as P;
    case 50:
      return (reader.readDateTime(offset)) as P;
    case 51:
      return (reader.readLong(offset)) as P;
    case 52:
      return (reader.readStringOrNull(offset)) as P;
    case 53:
      return (reader.readStringOrNull(offset)) as P;
    case 54:
      return (reader.readStringOrNull(offset)) as P;
    case 55:
      return (reader.readStringOrNull(offset)) as P;
    case 56:
      return (reader.readStringOrNull(offset)) as P;
    case 57:
      return (reader.readBool(offset)) as P;
    case 58:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 59:
      return (reader.readStringOrNull(offset)) as P;
    case 60:
      return (reader.readStringOrNull(offset)) as P;
    case 61:
      return (reader.readStringOrNull(offset)) as P;
    case 62:
      return (reader.readString(offset)) as P;
    case 63:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 64:
      return (reader.readStringOrNull(offset)) as P;
    case 65:
      return (reader.readStringOrNull(offset)) as P;
    case 66:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 67:
      return (reader.readStringOrNull(offset)) as P;
    case 68:
      return (reader.readStringOrNull(offset)) as P;
    case 69:
      return (reader.readStringOrNull(offset)) as P;
    case 70:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _MaintenanceRecordassetTypeEnumValueMap = {
  r'base': r'base',
  r'furnace': r'furnace',
  r'forceCooler': r'forceCooler',
  r'innerCover': r'innerCover',
  r'governedCustom': r'governedCustom',
};
const _MaintenanceRecordassetTypeValueEnumMap = {
  r'base': AssetType.base,
  r'furnace': AssetType.furnace,
  r'forceCooler': AssetType.forceCooler,
  r'innerCover': AssetType.innerCover,
  r'governedCustom': AssetType.governedCustom,
};
const _MaintenanceRecordmaintenanceTypeEnumValueMap = {
  r'scheduled': r'scheduled',
  r'breakdown': r'breakdown',
  r'performance': r'performance',
  r'inspection': r'inspection',
  r'overhaul': r'overhaul',
};
const _MaintenanceRecordmaintenanceTypeValueEnumMap = {
  r'scheduled': MaintenanceType.scheduled,
  r'breakdown': MaintenanceType.breakdown,
  r'performance': MaintenanceType.performance,
  r'inspection': MaintenanceType.inspection,
  r'overhaul': MaintenanceType.overhaul,
};
const _MaintenanceRecordroutedToEnumValueMap = {
  r'operations': r'operations',
  r'electrical': r'electrical',
  r'mechanical': r'mechanical',
  r'instrumentation': r'instrumentation',
  r'refractory': r'refractory',
  r'emd': r'emd',
  r'shiftInCharge': r'shiftInCharge',
  r'others': r'others',
};
const _MaintenanceRecordroutedToValueEnumMap = {
  r'operations': RoutedTo.operations,
  r'electrical': RoutedTo.electrical,
  r'mechanical': RoutedTo.mechanical,
  r'instrumentation': RoutedTo.instrumentation,
  r'refractory': RoutedTo.refractory,
  r'emd': RoutedTo.emd,
  r'shiftInCharge': RoutedTo.shiftInCharge,
  r'others': RoutedTo.others,
};
const _MaintenanceRecordstatusEnumValueMap = {
  r'open': r'open',
  r'acknowledged': r'acknowledged',
  r'inProgress': r'inProgress',
  r'resolved': r'resolved',
  r'closedWithoutResolution': r'closedWithoutResolution',
};
const _MaintenanceRecordstatusValueEnumMap = {
  r'open': TicketStatus.open,
  r'acknowledged': TicketStatus.acknowledged,
  r'inProgress': TicketStatus.inProgress,
  r'resolved': TicketStatus.resolved,
  r'closedWithoutResolution': TicketStatus.closedWithoutResolution,
};

Id _maintenanceRecordGetId(MaintenanceRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _maintenanceRecordGetLinks(
    MaintenanceRecord object) {
  return [];
}

void _maintenanceRecordAttach(
    IsarCollection<dynamic> col, Id id, MaintenanceRecord object) {
  object.id = id;
}

extension MaintenanceRecordQueryWhereSort
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QWhere> {
  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere>
      anyIsCritical() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isCritical'),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere>
      anyIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isResolved'),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere>
      anyWorkflowDeferred() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'workflowDeferred'),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere>
      anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhere>
      anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension MaintenanceRecordQueryWhere
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QWhereClause> {
  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'firestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      firestoreIdNotEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firestoreId',
              lower: [],
              upper: [firestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firestoreId',
              lower: [firestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firestoreId',
              lower: [firestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firestoreId',
              lower: [],
              upper: [firestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      isSyncedNotEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isSynced',
              lower: [],
              upper: [isSynced],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isSynced',
              lower: [isSynced],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isSynced',
              lower: [isSynced],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isSynced',
              lower: [],
              upper: [isSynced],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      isCriticalEqualTo(bool isCritical) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isCritical',
        value: [isCritical],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      isCriticalNotEqualTo(bool isCritical) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCritical',
              lower: [],
              upper: [isCritical],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCritical',
              lower: [isCritical],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCritical',
              lower: [isCritical],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCritical',
              lower: [],
              upper: [isCritical],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      isResolvedEqualTo(bool isResolved) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isResolved',
        value: [isResolved],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      isResolvedNotEqualTo(bool isResolved) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isResolved',
              lower: [],
              upper: [isResolved],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isResolved',
              lower: [isResolved],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isResolved',
              lower: [isResolved],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isResolved',
              lower: [],
              upper: [isResolved],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowDeferredEqualTo(bool workflowDeferred) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowDeferred',
        value: [workflowDeferred],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowDeferredNotEqualTo(bool workflowDeferred) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowDeferred',
              lower: [],
              upper: [workflowDeferred],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowDeferred',
              lower: [workflowDeferred],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowDeferred',
              lower: [workflowDeferred],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowDeferred',
              lower: [],
              upper: [workflowDeferred],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowQueueStateEqualTo(String workflowQueueState) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowQueueState',
        value: [workflowQueueState],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowQueueStateNotEqualTo(String workflowQueueState) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowQueueState',
              lower: [],
              upper: [workflowQueueState],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowQueueState',
              lower: [workflowQueueState],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowQueueState',
              lower: [workflowQueueState],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowQueueState',
              lower: [],
              upper: [workflowQueueState],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowAggregateIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowAggregateId',
        value: [null],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowAggregateIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'workflowAggregateId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowAggregateIdEqualTo(String? workflowAggregateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowAggregateId',
        value: [workflowAggregateId],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowAggregateIdNotEqualTo(String? workflowAggregateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowAggregateId',
              lower: [],
              upper: [workflowAggregateId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowAggregateId',
              lower: [workflowAggregateId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowAggregateId',
              lower: [workflowAggregateId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowAggregateId',
              lower: [],
              upper: [workflowAggregateId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowComplianceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowComplianceId',
        value: [null],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowComplianceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'workflowComplianceId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowComplianceIdEqualTo(String? workflowComplianceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowComplianceId',
        value: [workflowComplianceId],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      workflowComplianceIdNotEqualTo(String? workflowComplianceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowComplianceId',
              lower: [],
              upper: [workflowComplianceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowComplianceId',
              lower: [workflowComplianceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowComplianceId',
              lower: [workflowComplianceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowComplianceId',
              lower: [],
              upper: [workflowComplianceId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      loggedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'loggedByUid',
        value: [null],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      loggedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'loggedByUid',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      loggedByUidEqualTo(String? loggedByUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'loggedByUid',
        value: [loggedByUid],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      loggedByUidNotEqualTo(String? loggedByUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedByUid',
              lower: [],
              upper: [loggedByUid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedByUid',
              lower: [loggedByUid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedByUid',
              lower: [loggedByUid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedByUid',
              lower: [],
              upper: [loggedByUid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      updatedAtNotEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [],
              upper: [updatedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [updatedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [updatedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [],
              upper: [updatedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      updatedAtGreaterThan(
    DateTime updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [updatedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      updatedAtLessThan(
    DateTime updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [],
        upper: [updatedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterWhereClause>
      updatedAtBetween(
    DateTime lowerUpdatedAt,
    DateTime upperUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [lowerUpdatedAt],
        includeLower: includeLower,
        upper: [upperUpdatedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MaintenanceRecordQueryFilter
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QFilterCondition> {
  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      acknowledgedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      actionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetHierarchyRefJson',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetHierarchyRefJson',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetHierarchyRefJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetHierarchyRefJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetHierarchyRefJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetHierarchyRefJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetHierarchyRefJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetHierarchyRefJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetHierarchyRefJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetHierarchyRefJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetHierarchyRefJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetHierarchyRefJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetHierarchyRefJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetNumberGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetNumberLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeEqualTo(
    AssetType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeGreaterThan(
    AssetType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeLessThan(
    AssetType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeBetween(
    AssetType lower,
    AssetType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      assetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      chargeNoAtEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      chargeNoAtEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      chargeNoAtEventEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      chargeNoAtEventGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      chargeNoAtEventLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      chargeNoAtEventBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chargeNoAtEvent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'classification',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'classification',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'classification',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'classification',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'classification',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'classification',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'classification',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'classification',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'classification',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'classification',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'classification',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      classificationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'classification',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      closedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'component',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'component',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      componentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'debugLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'debugLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'debugLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      debugLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'debugLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deleteReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      downtimeHoursIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'downtimeHours',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      downtimeHoursIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'downtimeHours',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      downtimeHoursEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'downtimeHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      downtimeHoursGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'downtimeHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      downtimeHoursLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'downtimeHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      downtimeHoursBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'downtimeHours',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      endDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'endDate',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      endDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'endDate',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      endDateEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      endDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      endDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      endDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'firestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hasComponentContextEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasComponentContext',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'hierarchyPath',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'hierarchyPath',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hierarchyPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'hierarchyPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hierarchyPath',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'hierarchyPath',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      hierarchyPathLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      isClosedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isClosed',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      isCriticalEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCritical',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      isOpenEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isOpen',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      isResolvedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isResolved',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'loggedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'loggedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'loggedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'loggedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'loggedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'loggedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'loggedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'loggedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'loggedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      loggedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'loggedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeEqualTo(
    MaintenanceType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maintenanceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeGreaterThan(
    MaintenanceType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maintenanceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeLessThan(
    MaintenanceType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maintenanceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeBetween(
    MaintenanceType lower,
    MaintenanceType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maintenanceType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'maintenanceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'maintenanceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'maintenanceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'maintenanceType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maintenanceType',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      maintenanceTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'maintenanceType',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'metadataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalEventIssueLinkIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'operationalEventIssueLinkIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'operationalEventIssueLinkIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'operationalEventIssueLinkIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'operationalEventIssueLinkIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'operationalEventIssueLinkIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'operationalEventIssueLinkIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'operationalEventIssueLinkIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalEventIssueLinkIds',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'operationalEventIssueLinkIds',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalEventIssueLinkIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalEventIssueLinkIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalEventIssueLinkIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalEventIssueLinkIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalEventIssueLinkIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      operationalEventIssueLinkIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalEventIssueLinkIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'otherDepartment',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'otherDepartment',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherDepartment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'otherDepartment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'otherDepartment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'otherDepartment',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'otherDepartment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'otherDepartment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'otherDepartment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'otherDepartment',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'otherDepartment',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      otherDepartmentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'otherDepartment',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'performedBy',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'performedBy',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'performedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'performedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'performedBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'performedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'performedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'performedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'performedBy',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      performedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'performedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remarks',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remarks',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      remarksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenReason',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenReason',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reopenReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenReason',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reopenReason',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reopenedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reopenedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reopenedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reopenedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reopenedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reportedBy',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reportedBy',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reportedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reportedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reportedBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reportedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reportedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reportedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reportedBy',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      reportedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reportedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolutionHistoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolutionHistoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolutionHistoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolutionHistoryJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolutionHistoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolutionHistoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolutionHistoryJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolutionHistoryJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolutionHistoryJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      resolutionHistoryJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolutionHistoryJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToEqualTo(
    RoutedTo value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToGreaterThan(
    RoutedTo value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToLessThan(
    RoutedTo value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToBetween(
    RoutedTo lower,
    RoutedTo upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routedTo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'routedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'routedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'routedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'routedTo',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routedTo',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      routedToIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'routedTo',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      startDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      startDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      startDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      startDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusEqualTo(
    TicketStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusGreaterThan(
    TicketStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusLessThan(
    TicketStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusBetween(
    TicketStatus lower,
    TicketStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'subsystem',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'subsystem',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      subsystemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tag',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tag',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tag',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tag',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tag',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      tagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tag',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'teamsInvolved',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'teamsInvolved',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'teamsInvolved',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'teamsInvolved',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      teamsInvolvedLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      versionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      versionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'version',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowAggregateId',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowAggregateId',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowAggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowAggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowAggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowAggregateId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowAggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowAggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowAggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowAggregateId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowAggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowAggregateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowAggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowComplianceId',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowComplianceId',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowComplianceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowComplianceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowComplianceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowComplianceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowComplianceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowComplianceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowComplianceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowComplianceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowComplianceId',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowComplianceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowComplianceId',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowConditionRef',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowConditionRef',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowConditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowConditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowConditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowConditionRef',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowConditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowConditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowConditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowConditionRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowConditionRef',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowConditionRef',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowConditionTypeKey',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowConditionTypeKey',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowConditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowConditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowConditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowConditionTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowConditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowConditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowConditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowConditionTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowConditionTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowConditionTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowConditionTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowCorrectionReason',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowCorrectionReason',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowCorrectionReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowCorrectionReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowCorrectionReason',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowCorrectionReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowCorrectionReason',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowDeferred',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowDeferredAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowDeferredAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowDeferredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowDeferredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowDeferredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowDeferredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowDeferredByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowDeferredByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowDeferredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowDeferredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowDeferredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowDeferredByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowDeferredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowDeferredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowDeferredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowDeferredByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowDeferredByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowDeferredByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowDeferredByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowDeferredByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowDeferredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowDeferredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowDeferredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowDeferredByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowDeferredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowDeferredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowDeferredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowDeferredByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowDeferredByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowDeferredByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowDeferredByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowOriginLaneKey',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowOriginLaneKey',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowOriginLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowOriginLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowOriginLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowOriginLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowOriginLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowOriginLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowOriginLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowOriginLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowOriginLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowOriginLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowOriginLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowQueueState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowQueueState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowQueueState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowQueueState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowQueueState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowQueueState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowQueueState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowQueueState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowQueueState',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowQueueStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowQueueState',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowReactivatedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowReactivatedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReactivatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowReactivatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowReactivatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowReactivatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowReactivatedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowReactivatedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReactivatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowReactivatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowReactivatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowReactivatedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowReactivatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowReactivatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowReactivatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowReactivatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReactivatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowReactivatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowReactivatedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowReactivatedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReactivatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowReactivatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowReactivatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowReactivatedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowReactivatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowReactivatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowReactivatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowReactivatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReactivatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReactivatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowReactivatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowReleasedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowReleasedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReleasedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowReleasedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowReleasedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowReleasedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowReleasedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowReleasedByName',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReleasedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowReleasedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowReleasedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowReleasedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowReleasedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowReleasedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowReleasedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowReleasedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReleasedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowReleasedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowReleasedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowReleasedByUid',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReleasedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowReleasedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowReleasedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowReleasedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowReleasedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowReleasedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowReleasedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowReleasedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowReleasedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowReleasedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowReleasedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowTargetLaneKey',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowTargetLaneKey',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowTargetLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowTargetLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowTargetLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowTargetLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowTargetLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowUpdatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowUpdatedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowUpdatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowUpdatedAt',
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowUpdatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowUpdatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowUpdatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterFilterCondition>
      workflowUpdatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MaintenanceRecordQueryObject
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QFilterCondition> {}

extension MaintenanceRecordQueryLinks
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QFilterCondition> {}

extension MaintenanceRecordQuerySortBy
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QSortBy> {
  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByActionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByActionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAssetHierarchyRefJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetHierarchyRefJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAssetHierarchyRefJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetHierarchyRefJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByClassification() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classification', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByClassificationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classification', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByClosedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByClosedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByClosedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByClosedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDebugLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDebugLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDowntimeHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downtimeHours', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByDowntimeHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downtimeHours', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByEndDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByHasComponentContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByHasComponentContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsClosedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsCritical() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCritical', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsCriticalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCritical', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsOpen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsOpenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsResolvedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByLoggedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByLoggedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByLoggedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByLoggedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByMaintenanceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceType', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByMaintenanceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceType', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByOtherDepartment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherDepartment', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByOtherDepartmentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherDepartment', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByPerformedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedBy', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByPerformedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedBy', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByRemarks() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByRemarksDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReopenedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReportedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportedBy', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByReportedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportedBy', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByResolutionHistoryJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionHistoryJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByResolutionHistoryJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionHistoryJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByRoutedTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routedTo', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByRoutedToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routedTo', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy> sortByTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowAggregateId', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowAggregateId', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowComplianceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowComplianceId', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowComplianceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowComplianceId', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowConditionRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionRef', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowConditionRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionRef', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowConditionTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionTypeKey', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowConditionTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionTypeKey', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowCorrectionReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowCorrectionReason', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowCorrectionReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowCorrectionReason', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferred() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferred', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferred', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowDeferredByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowOriginLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowOriginLaneKey', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowOriginLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowOriginLaneKey', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowQueueState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowQueueState', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowQueueStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowQueueState', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReactivatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReactivatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReactivatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReactivatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReactivatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReactivatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReleasedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReleasedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReleasedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReleasedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReleasedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowReleasedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowTargetLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowTargetLaneKey', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowTargetLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowTargetLaneKey', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      sortByWorkflowUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowUpdatedAt', Sort.desc);
    });
  }
}

extension MaintenanceRecordQuerySortThenBy
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QSortThenBy> {
  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByActionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByActionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAssetHierarchyRefJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetHierarchyRefJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAssetHierarchyRefJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetHierarchyRefJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByClassification() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classification', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByClassificationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classification', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByClosedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByClosedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByClosedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByClosedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDebugLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDebugLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDowntimeHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downtimeHours', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByDowntimeHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downtimeHours', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByEndDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endDate', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByHasComponentContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByHasComponentContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsClosedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsCritical() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCritical', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsCriticalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCritical', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsOpen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsOpenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsResolvedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByLoggedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByLoggedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByLoggedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByLoggedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByMaintenanceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceType', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByMaintenanceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceType', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByOtherDepartment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherDepartment', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByOtherDepartmentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'otherDepartment', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByPerformedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedBy', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByPerformedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedBy', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByRemarks() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByRemarksDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReopenedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReportedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportedBy', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByReportedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportedBy', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByResolutionHistoryJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionHistoryJson', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByResolutionHistoryJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionHistoryJson', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByRoutedTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routedTo', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByRoutedToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routedTo', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByStartDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startDate', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy> thenByTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowAggregateId', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowAggregateId', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowComplianceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowComplianceId', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowComplianceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowComplianceId', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowConditionRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionRef', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowConditionRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionRef', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowConditionTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionTypeKey', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowConditionTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowConditionTypeKey', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowCorrectionReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowCorrectionReason', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowCorrectionReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowCorrectionReason', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferred() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferred', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferred', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowDeferredByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowDeferredByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowOriginLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowOriginLaneKey', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowOriginLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowOriginLaneKey', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowQueueState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowQueueState', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowQueueStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowQueueState', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReactivatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReactivatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReactivatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReactivatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReactivatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReactivatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReactivatedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReleasedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReleasedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedAt', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReleasedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByName', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReleasedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByName', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReleasedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByUid', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowReleasedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowReleasedByUid', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowTargetLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowTargetLaneKey', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowTargetLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowTargetLaneKey', Sort.desc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QAfterSortBy>
      thenByWorkflowUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowUpdatedAt', Sort.desc);
    });
  }
}

extension MaintenanceRecordQueryWhereDistinct
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct> {
  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByAcknowledgedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByAcknowledgedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByActionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actionsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByAssetHierarchyRefJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetHierarchyRefJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByAssetType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByClassification({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'classification',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByClosedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByClosedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByComponent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'component', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDebugLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'debugLabel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByDowntimeHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'downtimeHours');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByEndDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endDate');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByHasComponentContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasComponentContext');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByHierarchyPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hierarchyPath');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isClosed');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByIsCritical() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCritical');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByIsOpen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOpen');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isResolved');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByLoggedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByLoggedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByMaintenanceType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maintenanceType',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByOperationalEventIssueLinkIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operationalEventIssueLinkIds');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByOtherDepartment({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'otherDepartment',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByPerformedBy({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'performedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByRemarks({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remarks', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByReopenReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByReopenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByReopenedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByReopenedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByReportedBy({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByResolutionHistoryJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolutionHistoryJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByRoutedTo({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routedTo', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByStartDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startDate');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctBySubsystem({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subsystem', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct> distinctByTag(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tag', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByTeamsInvolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'teamsInvolved');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowAggregateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowAggregateId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowComplianceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowComplianceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowConditionRef({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowConditionRef',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowConditionTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowConditionTypeKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowCorrectionReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowCorrectionReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowDeferred() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowDeferred');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowDeferredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowDeferredAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowDeferredByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowDeferredByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowDeferredByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowDeferredByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowOriginLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowOriginLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowQueueState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowQueueState',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowReactivatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowReactivatedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowReactivatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowReactivatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowReactivatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowReactivatedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowReleasedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowReleasedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowReleasedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowReleasedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowReleasedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowReleasedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowTargetLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowTargetLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceRecord, QDistinct>
      distinctByWorkflowUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowUpdatedAt');
    });
  }
}

extension MaintenanceRecordQueryProperty
    on QueryBuilder<MaintenanceRecord, MaintenanceRecord, QQueryProperty> {
  QueryBuilder<MaintenanceRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      acknowledgedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      acknowledgedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      acknowledgedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, String, QQueryOperations>
      actionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actionsJson');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      assetHierarchyRefJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetHierarchyRefJson');
    });
  }

  QueryBuilder<MaintenanceRecord, int, QQueryOperations> assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<MaintenanceRecord, AssetType, QQueryOperations>
      assetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetType');
    });
  }

  QueryBuilder<MaintenanceRecord, int?, QQueryOperations>
      chargeNoAtEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      classificationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'classification');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      closedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      closedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      componentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'component');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String, QQueryOperations>
      debugLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'debugLabel');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, String, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<MaintenanceRecord, double?, QQueryOperations>
      downtimeHoursProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'downtimeHours');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      endDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endDate');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations>
      hasComponentContextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasComponentContext');
    });
  }

  QueryBuilder<MaintenanceRecord, List<String>?, QQueryOperations>
      hierarchyPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hierarchyPath');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations> isClosedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isClosed');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations> isCriticalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCritical');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations> isOpenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOpen');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations> isResolvedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isResolved');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      loggedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      loggedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, MaintenanceType, QQueryOperations>
      maintenanceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maintenanceType');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<MaintenanceRecord, List<String>, QQueryOperations>
      operationalEventIssueLinkIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationalEventIssueLinkIds');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      otherDepartmentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'otherDepartment');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      performedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'performedBy');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations> remarksProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remarks');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      reopenReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenReason');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      reopenedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      reopenedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      reopenedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      reportedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportedBy');
    });
  }

  QueryBuilder<MaintenanceRecord, String, QQueryOperations>
      resolutionHistoryJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolutionHistoryJson');
    });
  }

  QueryBuilder<MaintenanceRecord, RoutedTo, QQueryOperations>
      routedToProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routedTo');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime, QQueryOperations>
      startDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startDate');
    });
  }

  QueryBuilder<MaintenanceRecord, TicketStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      subsystemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subsystem');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations> tagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tag');
    });
  }

  QueryBuilder<MaintenanceRecord, List<String>, QQueryOperations>
      teamsInvolvedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'teamsInvolved');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowAggregateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowAggregateId');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowComplianceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowComplianceId');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowConditionRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowConditionRef');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowConditionTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowConditionTypeKey');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowCorrectionReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowCorrectionReason');
    });
  }

  QueryBuilder<MaintenanceRecord, bool, QQueryOperations>
      workflowDeferredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowDeferred');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      workflowDeferredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowDeferredAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowDeferredByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowDeferredByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowDeferredByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowDeferredByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowOriginLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowOriginLaneKey');
    });
  }

  QueryBuilder<MaintenanceRecord, String, QQueryOperations>
      workflowQueueStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowQueueState');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      workflowReactivatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowReactivatedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowReactivatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowReactivatedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowReactivatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowReactivatedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      workflowReleasedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowReleasedAt');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowReleasedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowReleasedByName');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowReleasedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowReleasedByUid');
    });
  }

  QueryBuilder<MaintenanceRecord, String?, QQueryOperations>
      workflowTargetLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowTargetLaneKey');
    });
  }

  QueryBuilder<MaintenanceRecord, DateTime?, QQueryOperations>
      workflowUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowUpdatedAt');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const ResolutionHistorySchema = Schema(
  name: r'ResolutionHistory',
  id: 5859852291693714328,
  properties: {
    r'actionsJson': PropertySchema(
      id: 0,
      name: r'actionsJson',
      type: IsarType.string,
    ),
    r'downtimeHours': PropertySchema(
      id: 1,
      name: r'downtimeHours',
      type: IsarType.double,
    ),
    r'remarks': PropertySchema(
      id: 2,
      name: r'remarks',
      type: IsarType.string,
    ),
    r'resolvedAt': PropertySchema(
      id: 3,
      name: r'resolvedAt',
      type: IsarType.dateTime,
    ),
    r'resolvedByName': PropertySchema(
      id: 4,
      name: r'resolvedByName',
      type: IsarType.string,
    ),
    r'resolvedByUid': PropertySchema(
      id: 5,
      name: r'resolvedByUid',
      type: IsarType.string,
    ),
    r'teamsInvolved': PropertySchema(
      id: 6,
      name: r'teamsInvolved',
      type: IsarType.stringList,
    )
  },
  estimateSize: _resolutionHistoryEstimateSize,
  serialize: _resolutionHistorySerialize,
  deserialize: _resolutionHistoryDeserialize,
  deserializeProp: _resolutionHistoryDeserializeProp,
);

int _resolutionHistoryEstimateSize(
  ResolutionHistory object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.actionsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.remarks;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolvedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolvedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.teamsInvolved.length * 3;
  {
    for (var i = 0; i < object.teamsInvolved.length; i++) {
      final value = object.teamsInvolved[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _resolutionHistorySerialize(
  ResolutionHistory object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.actionsJson);
  writer.writeDouble(offsets[1], object.downtimeHours);
  writer.writeString(offsets[2], object.remarks);
  writer.writeDateTime(offsets[3], object.resolvedAt);
  writer.writeString(offsets[4], object.resolvedByName);
  writer.writeString(offsets[5], object.resolvedByUid);
  writer.writeStringList(offsets[6], object.teamsInvolved);
}

ResolutionHistory _resolutionHistoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ResolutionHistory(
    actionsJson: reader.readStringOrNull(offsets[0]),
    downtimeHours: reader.readDoubleOrNull(offsets[1]),
    remarks: reader.readStringOrNull(offsets[2]),
    resolvedAt: reader.readDateTimeOrNull(offsets[3]),
    resolvedByName: reader.readStringOrNull(offsets[4]),
    resolvedByUid: reader.readStringOrNull(offsets[5]),
    teamsInvolved: reader.readStringList(offsets[6]) ?? const [],
  );
  return object;
}

P _resolutionHistoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringList(offset) ?? const []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension ResolutionHistoryQueryFilter
    on QueryBuilder<ResolutionHistory, ResolutionHistory, QFilterCondition> {
  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'actionsJson',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'actionsJson',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      actionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      downtimeHoursIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'downtimeHours',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      downtimeHoursIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'downtimeHours',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      downtimeHoursEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'downtimeHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      downtimeHoursGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'downtimeHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      downtimeHoursLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'downtimeHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      downtimeHoursBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'downtimeHours',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remarks',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remarks',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      remarksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedAt',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedAt',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedByName',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedByName',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedByUid',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedByUid',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      resolvedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'teamsInvolved',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'teamsInvolved',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'teamsInvolved',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'teamsInvolved',
        value: '',
      ));
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ResolutionHistory, ResolutionHistory, QAfterFilterCondition>
      teamsInvolvedLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension ResolutionHistoryQueryObject
    on QueryBuilder<ResolutionHistory, ResolutionHistory, QFilterCondition> {}
