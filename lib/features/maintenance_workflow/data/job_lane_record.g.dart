// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_lane_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetJobLaneRecordCollection on Isar {
  IsarCollection<JobLaneRecord> get jobLaneRecords => this.collection();
}

const JobLaneRecordSchema = CollectionSchema(
  name: r'JobLaneRecord',
  id: -3251694076183668774,
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
    r'acknowledgementDueAt': PropertySchema(
      id: 3,
      name: r'acknowledgementDueAt',
      type: IsarType.dateTime,
    ),
    r'activationGeneration': PropertySchema(
      id: 4,
      name: r'activationGeneration',
      type: IsarType.long,
    ),
    r'addReason': PropertySchema(
      id: 5,
      name: r'addReason',
      type: IsarType.string,
    ),
    r'addedAt': PropertySchema(
      id: 6,
      name: r'addedAt',
      type: IsarType.dateTime,
    ),
    r'addedByName': PropertySchema(
      id: 7,
      name: r'addedByName',
      type: IsarType.string,
    ),
    r'addedByUid': PropertySchema(
      id: 8,
      name: r'addedByUid',
      type: IsarType.string,
    ),
    r'addedDuringExecution': PropertySchema(
      id: 9,
      name: r'addedDuringExecution',
      type: IsarType.bool,
    ),
    r'assetNumber': PropertySchema(
      id: 10,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetTypeKey': PropertySchema(
      id: 11,
      name: r'assetTypeKey',
      type: IsarType.string,
    ),
    r'chargeNoAtEvent': PropertySchema(
      id: 12,
      name: r'chargeNoAtEvent',
      type: IsarType.long,
    ),
    r'closeNote': PropertySchema(
      id: 13,
      name: r'closeNote',
      type: IsarType.string,
    ),
    r'closedAt': PropertySchema(
      id: 14,
      name: r'closedAt',
      type: IsarType.dateTime,
    ),
    r'closedByName': PropertySchema(
      id: 15,
      name: r'closedByName',
      type: IsarType.string,
    ),
    r'closedByUid': PropertySchema(
      id: 16,
      name: r'closedByUid',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 17,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdByName': PropertySchema(
      id: 18,
      name: r'createdByName',
      type: IsarType.string,
    ),
    r'createdByUid': PropertySchema(
      id: 19,
      name: r'createdByUid',
      type: IsarType.string,
    ),
    r'delegationBasis': PropertySchema(
      id: 20,
      name: r'delegationBasis',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 21,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 22,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 23,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 24,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'displayOrder': PropertySchema(
      id: 25,
      name: r'displayOrder',
      type: IsarType.long,
    ),
    r'escalationTier': PropertySchema(
      id: 26,
      name: r'escalationTier',
      type: IsarType.long,
    ),
    r'firestoreId': PropertySchema(
      id: 27,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'gatingComplianceRequestId': PropertySchema(
      id: 28,
      name: r'gatingComplianceRequestId',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 29,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 30,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'jobExecutionFirestoreId': PropertySchema(
      id: 31,
      name: r'jobExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'jobExecutionLocalId': PropertySchema(
      id: 32,
      name: r'jobExecutionLocalId',
      type: IsarType.long,
    ),
    r'laneKey': PropertySchema(
      id: 33,
      name: r'laneKey',
      type: IsarType.string,
    ),
    r'laneSetFinalized': PropertySchema(
      id: 34,
      name: r'laneSetFinalized',
      type: IsarType.bool,
    ),
    r'lastEscalatedAt': PropertySchema(
      id: 35,
      name: r'lastEscalatedAt',
      type: IsarType.dateTime,
    ),
    r'metadataJson': PropertySchema(
      id: 36,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'progressRevision': PropertySchema(
      id: 37,
      name: r'progressRevision',
      type: IsarType.long,
    ),
    r'removeReason': PropertySchema(
      id: 38,
      name: r'removeReason',
      type: IsarType.string,
    ),
    r'removedAt': PropertySchema(
      id: 39,
      name: r'removedAt',
      type: IsarType.dateTime,
    ),
    r'removedByName': PropertySchema(
      id: 40,
      name: r'removedByName',
      type: IsarType.string,
    ),
    r'removedByUid': PropertySchema(
      id: 41,
      name: r'removedByUid',
      type: IsarType.string,
    ),
    r'representedLaneKey': PropertySchema(
      id: 42,
      name: r'representedLaneKey',
      type: IsarType.string,
    ),
    r'statusKey': PropertySchema(
      id: 43,
      name: r'statusKey',
      type: IsarType.string,
    ),
    r'terminateReason': PropertySchema(
      id: 44,
      name: r'terminateReason',
      type: IsarType.string,
    ),
    r'terminatedAt': PropertySchema(
      id: 45,
      name: r'terminatedAt',
      type: IsarType.dateTime,
    ),
    r'terminatedByName': PropertySchema(
      id: 46,
      name: r'terminatedByName',
      type: IsarType.string,
    ),
    r'terminatedByUid': PropertySchema(
      id: 47,
      name: r'terminatedByUid',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 48,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 49,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 50,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 51,
      name: r'version',
      type: IsarType.long,
    ),
    r'workflowFirestoreId': PropertySchema(
      id: 52,
      name: r'workflowFirestoreId',
      type: IsarType.string,
    )
  },
  estimateSize: _jobLaneRecordEstimateSize,
  serialize: _jobLaneRecordSerialize,
  deserialize: _jobLaneRecordDeserialize,
  deserializeProp: _jobLaneRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'workflowFirestoreId': IndexSchema(
      id: 623106065256834476,
      name: r'workflowFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'workflowFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'jobExecutionFirestoreId': IndexSchema(
      id: -4274754955259152555,
      name: r'jobExecutionFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'jobExecutionFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'jobExecutionLocalId': IndexSchema(
      id: 3804470798990043825,
      name: r'jobExecutionLocalId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'jobExecutionLocalId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'laneKey': IndexSchema(
      id: 8565663870941351272,
      name: r'laneKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'laneKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'statusKey': IndexSchema(
      id: -3111857984361591712,
      name: r'statusKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'statusKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'activationGeneration': IndexSchema(
      id: 4700469646171272271,
      name: r'activationGeneration',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'activationGeneration',
          type: IndexType.value,
          caseSensitive: false,
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
    r'assetNumber': IndexSchema(
      id: 1893107624136954704,
      name: r'assetNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetNumber',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'assetTypeKey': IndexSchema(
      id: -8509262865085066165,
      name: r'assetTypeKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetTypeKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _jobLaneRecordGetId,
  getLinks: _jobLaneRecordGetLinks,
  attach: _jobLaneRecordAttach,
  version: '3.1.0+1',
);

int _jobLaneRecordEstimateSize(
  JobLaneRecord object,
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
  {
    final value = object.addReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.addedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.addedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.assetTypeKey.length * 3;
  {
    final value = object.closeNote;
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
    final value = object.createdByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.createdByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.delegationBasis;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.gatingComplianceRequestId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.jobExecutionFirestoreId.length * 3;
  bytesCount += 3 + object.laneKey.length * 3;
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.removeReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.removedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.removedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.representedLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.statusKey.length * 3;
  {
    final value = object.terminateReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.terminatedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.terminatedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.updatedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.updatedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.workflowFirestoreId.length * 3;
  return bytesCount;
}

void _jobLaneRecordSerialize(
  JobLaneRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acknowledgedAt);
  writer.writeString(offsets[1], object.acknowledgedByName);
  writer.writeString(offsets[2], object.acknowledgedByUid);
  writer.writeDateTime(offsets[3], object.acknowledgementDueAt);
  writer.writeLong(offsets[4], object.activationGeneration);
  writer.writeString(offsets[5], object.addReason);
  writer.writeDateTime(offsets[6], object.addedAt);
  writer.writeString(offsets[7], object.addedByName);
  writer.writeString(offsets[8], object.addedByUid);
  writer.writeBool(offsets[9], object.addedDuringExecution);
  writer.writeLong(offsets[10], object.assetNumber);
  writer.writeString(offsets[11], object.assetTypeKey);
  writer.writeLong(offsets[12], object.chargeNoAtEvent);
  writer.writeString(offsets[13], object.closeNote);
  writer.writeDateTime(offsets[14], object.closedAt);
  writer.writeString(offsets[15], object.closedByName);
  writer.writeString(offsets[16], object.closedByUid);
  writer.writeDateTime(offsets[17], object.createdAt);
  writer.writeString(offsets[18], object.createdByName);
  writer.writeString(offsets[19], object.createdByUid);
  writer.writeString(offsets[20], object.delegationBasis);
  writer.writeString(offsets[21], object.deleteReason);
  writer.writeDateTime(offsets[22], object.deletedAt);
  writer.writeString(offsets[23], object.deletedByName);
  writer.writeString(offsets[24], object.deletedByUid);
  writer.writeLong(offsets[25], object.displayOrder);
  writer.writeLong(offsets[26], object.escalationTier);
  writer.writeString(offsets[27], object.firestoreId);
  writer.writeString(offsets[28], object.gatingComplianceRequestId);
  writer.writeBool(offsets[29], object.isDeleted);
  writer.writeBool(offsets[30], object.isSynced);
  writer.writeString(offsets[31], object.jobExecutionFirestoreId);
  writer.writeLong(offsets[32], object.jobExecutionLocalId);
  writer.writeString(offsets[33], object.laneKey);
  writer.writeBool(offsets[34], object.laneSetFinalized);
  writer.writeDateTime(offsets[35], object.lastEscalatedAt);
  writer.writeString(offsets[36], object.metadataJson);
  writer.writeLong(offsets[37], object.progressRevision);
  writer.writeString(offsets[38], object.removeReason);
  writer.writeDateTime(offsets[39], object.removedAt);
  writer.writeString(offsets[40], object.removedByName);
  writer.writeString(offsets[41], object.removedByUid);
  writer.writeString(offsets[42], object.representedLaneKey);
  writer.writeString(offsets[43], object.statusKey);
  writer.writeString(offsets[44], object.terminateReason);
  writer.writeDateTime(offsets[45], object.terminatedAt);
  writer.writeString(offsets[46], object.terminatedByName);
  writer.writeString(offsets[47], object.terminatedByUid);
  writer.writeDateTime(offsets[48], object.updatedAt);
  writer.writeString(offsets[49], object.updatedByName);
  writer.writeString(offsets[50], object.updatedByUid);
  writer.writeLong(offsets[51], object.version);
  writer.writeString(offsets[52], object.workflowFirestoreId);
}

JobLaneRecord _jobLaneRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = JobLaneRecord();
  object.acknowledgedAt = reader.readDateTimeOrNull(offsets[0]);
  object.acknowledgedByName = reader.readStringOrNull(offsets[1]);
  object.acknowledgedByUid = reader.readStringOrNull(offsets[2]);
  object.acknowledgementDueAt = reader.readDateTimeOrNull(offsets[3]);
  object.activationGeneration = reader.readLong(offsets[4]);
  object.addReason = reader.readStringOrNull(offsets[5]);
  object.addedAt = reader.readDateTimeOrNull(offsets[6]);
  object.addedByName = reader.readStringOrNull(offsets[7]);
  object.addedByUid = reader.readStringOrNull(offsets[8]);
  object.addedDuringExecution = reader.readBool(offsets[9]);
  object.assetNumber = reader.readLong(offsets[10]);
  object.assetTypeKey = reader.readString(offsets[11]);
  object.chargeNoAtEvent = reader.readLongOrNull(offsets[12]);
  object.closeNote = reader.readStringOrNull(offsets[13]);
  object.closedAt = reader.readDateTimeOrNull(offsets[14]);
  object.closedByName = reader.readStringOrNull(offsets[15]);
  object.closedByUid = reader.readStringOrNull(offsets[16]);
  object.createdAt = reader.readDateTime(offsets[17]);
  object.createdByName = reader.readStringOrNull(offsets[18]);
  object.createdByUid = reader.readStringOrNull(offsets[19]);
  object.delegationBasis = reader.readStringOrNull(offsets[20]);
  object.deleteReason = reader.readStringOrNull(offsets[21]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[22]);
  object.deletedByName = reader.readStringOrNull(offsets[23]);
  object.deletedByUid = reader.readStringOrNull(offsets[24]);
  object.displayOrder = reader.readLong(offsets[25]);
  object.escalationTier = reader.readLong(offsets[26]);
  object.firestoreId = reader.readStringOrNull(offsets[27]);
  object.gatingComplianceRequestId = reader.readStringOrNull(offsets[28]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[29]);
  object.isSynced = reader.readBool(offsets[30]);
  object.jobExecutionFirestoreId = reader.readString(offsets[31]);
  object.jobExecutionLocalId = reader.readLongOrNull(offsets[32]);
  object.laneKey = reader.readString(offsets[33]);
  object.laneSetFinalized = reader.readBool(offsets[34]);
  object.lastEscalatedAt = reader.readDateTimeOrNull(offsets[35]);
  object.metadataJson = reader.readStringOrNull(offsets[36]);
  object.progressRevision = reader.readLong(offsets[37]);
  object.removeReason = reader.readStringOrNull(offsets[38]);
  object.removedAt = reader.readDateTimeOrNull(offsets[39]);
  object.removedByName = reader.readStringOrNull(offsets[40]);
  object.removedByUid = reader.readStringOrNull(offsets[41]);
  object.representedLaneKey = reader.readStringOrNull(offsets[42]);
  object.statusKey = reader.readString(offsets[43]);
  object.terminateReason = reader.readStringOrNull(offsets[44]);
  object.terminatedAt = reader.readDateTimeOrNull(offsets[45]);
  object.terminatedByName = reader.readStringOrNull(offsets[46]);
  object.terminatedByUid = reader.readStringOrNull(offsets[47]);
  object.updatedAt = reader.readDateTime(offsets[48]);
  object.updatedByName = reader.readStringOrNull(offsets[49]);
  object.updatedByUid = reader.readStringOrNull(offsets[50]);
  object.version = reader.readLong(offsets[51]);
  object.workflowFirestoreId = reader.readString(offsets[52]);
  return object;
}

P _jobLaneRecordDeserializeProp<P>(
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
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readDateTime(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 23:
      return (reader.readStringOrNull(offset)) as P;
    case 24:
      return (reader.readStringOrNull(offset)) as P;
    case 25:
      return (reader.readLong(offset)) as P;
    case 26:
      return (reader.readLong(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readStringOrNull(offset)) as P;
    case 29:
      return (reader.readBool(offset)) as P;
    case 30:
      return (reader.readBool(offset)) as P;
    case 31:
      return (reader.readString(offset)) as P;
    case 32:
      return (reader.readLongOrNull(offset)) as P;
    case 33:
      return (reader.readString(offset)) as P;
    case 34:
      return (reader.readBool(offset)) as P;
    case 35:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 36:
      return (reader.readStringOrNull(offset)) as P;
    case 37:
      return (reader.readLong(offset)) as P;
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
      return (reader.readStringOrNull(offset)) as P;
    case 45:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 46:
      return (reader.readStringOrNull(offset)) as P;
    case 47:
      return (reader.readStringOrNull(offset)) as P;
    case 48:
      return (reader.readDateTime(offset)) as P;
    case 49:
      return (reader.readStringOrNull(offset)) as P;
    case 50:
      return (reader.readStringOrNull(offset)) as P;
    case 51:
      return (reader.readLong(offset)) as P;
    case 52:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _jobLaneRecordGetId(JobLaneRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _jobLaneRecordGetLinks(JobLaneRecord object) {
  return [];
}

void _jobLaneRecordAttach(
    IsarCollection<dynamic> col, Id id, JobLaneRecord object) {
  object.id = id;
}

extension JobLaneRecordByIndex on IsarCollection<JobLaneRecord> {
  Future<JobLaneRecord?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  JobLaneRecord? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<JobLaneRecord?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<JobLaneRecord?> getAllByFirestoreIdSync(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'firestoreId', values);
  }

  Future<int> deleteAllByFirestoreId(List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'firestoreId', values);
  }

  int deleteAllByFirestoreIdSync(List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'firestoreId', values);
  }

  Future<Id> putByFirestoreId(JobLaneRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(JobLaneRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<JobLaneRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<JobLaneRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension JobLaneRecordQueryWhereSort
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QWhere> {
  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhere>
      anyJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'jobExecutionLocalId'),
      );
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhere>
      anyActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'activationGeneration'),
      );
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhere> anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }
}

extension JobLaneRecordQueryWhere
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QWhereClause> {
  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> idBetween(
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      workflowFirestoreIdEqualTo(String workflowFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'workflowFirestoreId',
        value: [workflowFirestoreId],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      workflowFirestoreIdNotEqualTo(String workflowFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowFirestoreId',
              lower: [],
              upper: [workflowFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowFirestoreId',
              lower: [workflowFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowFirestoreId',
              lower: [workflowFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'workflowFirestoreId',
              lower: [],
              upper: [workflowFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionFirestoreIdEqualTo(String jobExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionFirestoreId',
        value: [jobExecutionFirestoreId],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionFirestoreIdNotEqualTo(String jobExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [],
              upper: [jobExecutionFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [jobExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [jobExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [],
              upper: [jobExecutionFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionLocalId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdEqualTo(int? jobExecutionLocalId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionLocalId',
        value: [jobExecutionLocalId],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdNotEqualTo(int? jobExecutionLocalId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [],
              upper: [jobExecutionLocalId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [jobExecutionLocalId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [jobExecutionLocalId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [],
              upper: [jobExecutionLocalId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdGreaterThan(
    int? jobExecutionLocalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [jobExecutionLocalId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdLessThan(
    int? jobExecutionLocalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [],
        upper: [jobExecutionLocalId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      jobExecutionLocalIdBetween(
    int? lowerJobExecutionLocalId,
    int? upperJobExecutionLocalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [lowerJobExecutionLocalId],
        includeLower: includeLower,
        upper: [upperJobExecutionLocalId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> laneKeyEqualTo(
      String laneKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'laneKey',
        value: [laneKey],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      laneKeyNotEqualTo(String laneKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [],
              upper: [laneKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [laneKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [laneKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [],
              upper: [laneKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      statusKeyEqualTo(String statusKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'statusKey',
        value: [statusKey],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      statusKeyNotEqualTo(String statusKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'statusKey',
              lower: [],
              upper: [statusKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'statusKey',
              lower: [statusKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'statusKey',
              lower: [statusKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'statusKey',
              lower: [],
              upper: [statusKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      activationGenerationEqualTo(int activationGeneration) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'activationGeneration',
        value: [activationGeneration],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      activationGenerationNotEqualTo(int activationGeneration) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activationGeneration',
              lower: [],
              upper: [activationGeneration],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activationGeneration',
              lower: [activationGeneration],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activationGeneration',
              lower: [activationGeneration],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activationGeneration',
              lower: [],
              upper: [activationGeneration],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      activationGenerationGreaterThan(
    int activationGeneration, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'activationGeneration',
        lower: [activationGeneration],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      activationGenerationLessThan(
    int activationGeneration, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'activationGeneration',
        lower: [],
        upper: [activationGeneration],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      activationGenerationBetween(
    int lowerActivationGeneration,
    int upperActivationGeneration, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'activationGeneration',
        lower: [lowerActivationGeneration],
        includeLower: includeLower,
        upper: [upperActivationGeneration],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause> isSyncedEqualTo(
      bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetNumberNotEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetNumber',
              lower: [],
              upper: [assetNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetNumber',
              lower: [assetNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetNumber',
              lower: [assetNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetNumber',
              lower: [],
              upper: [assetNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetNumberGreaterThan(
    int assetNumber, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetNumber',
        lower: [assetNumber],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetNumberLessThan(
    int assetNumber, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetNumber',
        lower: [],
        upper: [assetNumber],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetNumberBetween(
    int lowerAssetNumber,
    int upperAssetNumber, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetNumber',
        lower: [lowerAssetNumber],
        includeLower: includeLower,
        upper: [upperAssetNumber],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetTypeKeyEqualTo(String assetTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetTypeKey',
        value: [assetTypeKey],
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterWhereClause>
      assetTypeKeyNotEqualTo(String assetTypeKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetTypeKey',
              lower: [],
              upper: [assetTypeKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetTypeKey',
              lower: [assetTypeKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetTypeKey',
              lower: [assetTypeKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetTypeKey',
              lower: [],
              upper: [assetTypeKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension JobLaneRecordQueryFilter
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QFilterCondition> {
  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgementDueAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgementDueAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgementDueAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgementDueAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgementDueAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgementDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgementDueAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgementDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgementDueAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgementDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      acknowledgementDueAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgementDueAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      activationGenerationEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activationGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      activationGenerationGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'activationGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      activationGenerationLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'activationGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      activationGenerationBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'activationGeneration',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'addReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'addReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'addedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'addedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'addedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'addedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      addedDuringExecutionEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedDuringExecution',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      assetTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      chargeNoAtEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      chargeNoAtEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      chargeNoAtEventEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closeNote',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closeNote',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closeNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closeNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closeNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closeNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closeNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closeNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closeNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closeNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closeNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closeNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closeNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      closedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'delegationBasis',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'delegationBasis',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'delegationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'delegationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'delegationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'delegationBasis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'delegationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'delegationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'delegationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'delegationBasis',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'delegationBasis',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      delegationBasisIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'delegationBasis',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      displayOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      displayOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      displayOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      displayOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      escalationTierEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'escalationTier',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      escalationTierGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'escalationTier',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      escalationTierLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'escalationTier',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      escalationTierBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'escalationTier',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gatingComplianceRequestId',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gatingComplianceRequestId',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gatingComplianceRequestId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gatingComplianceRequestId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gatingComplianceRequestId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gatingComplianceRequestId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'gatingComplianceRequestId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'gatingComplianceRequestId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'gatingComplianceRequestId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'gatingComplianceRequestId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gatingComplianceRequestId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      gatingComplianceRequestIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'gatingComplianceRequestId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition> idBetween(
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobExecutionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'jobExecutionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'jobExecutionLocalId',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionLocalIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'jobExecutionLocalId',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionLocalIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionLocalIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionLocalIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      jobExecutionLocalIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobExecutionLocalId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      laneSetFinalizedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalized',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      lastEscalatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastEscalatedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      lastEscalatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastEscalatedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      lastEscalatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEscalatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      lastEscalatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastEscalatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      lastEscalatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastEscalatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      lastEscalatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastEscalatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      progressRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'progressRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      progressRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'progressRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      progressRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'progressRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      progressRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'progressRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'removeReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'removeReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removeReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'removeReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'removeReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'removeReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'removeReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'removeReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'removeReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'removeReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removeReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removeReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'removeReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'removedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'removedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'removedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'removedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'removedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'removedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'removedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'removedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'removedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'removedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'removedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'removedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'removedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'removedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'removedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'removedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'removedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'removedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'removedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'removedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'removedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'removedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'removedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'removedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'removedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      removedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'removedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'representedLaneKey',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'representedLaneKey',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'representedLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'representedLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'representedLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      representedLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'representedLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'statusKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'statusKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'statusKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      statusKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'statusKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'terminateReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'terminateReason',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminateReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'terminateReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'terminateReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'terminateReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'terminateReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'terminateReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'terminateReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'terminateReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminateReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminateReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'terminateReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'terminatedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'terminatedAt',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'terminatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'terminatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'terminatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'terminatedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'terminatedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'terminatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'terminatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'terminatedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'terminatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'terminatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'terminatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'terminatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'terminatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'terminatedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'terminatedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'terminatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'terminatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'terminatedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'terminatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'terminatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'terminatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'terminatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'terminatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      terminatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'terminatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
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

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterFilterCondition>
      workflowFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowFirestoreId',
        value: '',
      ));
    });
  }
}

extension JobLaneRecordQueryObject
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QFilterCondition> {}

extension JobLaneRecordQueryLinks
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QFilterCondition> {}

extension JobLaneRecordQuerySortBy
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QSortBy> {
  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgementDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAcknowledgementDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activationGeneration', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByActivationGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activationGeneration', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByAddReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAddReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByAddedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAddedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByAddedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAddedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAddedDuringExecutionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByCloseNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closeNote', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByCloseNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closeNote', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByClosedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByClosedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByClosedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByClosedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByClosedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDelegationBasis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delegationBasis', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDelegationBasisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delegationBasis', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDisplayOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByDisplayOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByEscalationTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByEscalationTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByGatingComplianceRequestId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatingComplianceRequestId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByGatingComplianceRequestIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatingComplianceRequestId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByJobExecutionLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByLaneSetFinalized() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalized', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByLaneSetFinalizedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalized', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByLastEscalatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByLastEscalatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByProgressRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progressRevision', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByProgressRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progressRevision', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemoveReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removeReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemoveReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removeReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByRemovedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemovedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemovedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemovedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemovedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRemovedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRepresentedLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByRepresentedLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByStatusKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByStatusKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminateReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminateReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminateReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminateReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByTerminatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByWorkflowFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      sortByWorkflowFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowFirestoreId', Sort.desc);
    });
  }
}

extension JobLaneRecordQuerySortThenBy
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QSortThenBy> {
  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgementDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAcknowledgementDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activationGeneration', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByActivationGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activationGeneration', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByAddReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAddReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByAddedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAddedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByAddedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAddedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAddedDuringExecutionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByCloseNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closeNote', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByCloseNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closeNote', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByClosedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByClosedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByClosedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByClosedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByClosedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDelegationBasis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delegationBasis', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDelegationBasisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delegationBasis', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDisplayOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByDisplayOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByEscalationTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByEscalationTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByGatingComplianceRequestId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatingComplianceRequestId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByGatingComplianceRequestIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatingComplianceRequestId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByJobExecutionLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByLaneSetFinalized() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalized', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByLaneSetFinalizedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalized', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByLastEscalatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByLastEscalatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByProgressRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progressRevision', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByProgressRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progressRevision', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemoveReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removeReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemoveReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removeReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByRemovedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemovedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemovedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemovedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemovedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRemovedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'removedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRepresentedLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByRepresentedLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByStatusKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByStatusKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminateReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminateReason', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminateReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminateReason', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByTerminatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'terminatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByWorkflowFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QAfterSortBy>
      thenByWorkflowFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowFirestoreId', Sort.desc);
    });
  }
}

extension JobLaneRecordQueryWhereDistinct
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> {
  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByAcknowledgedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByAcknowledgedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByAcknowledgementDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgementDueAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activationGeneration');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByAddReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByAddedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByAddedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedDuringExecution');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByAssetTypeKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetTypeKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByCloseNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closeNote', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByClosedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByClosedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByCreatedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByCreatedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByDelegationBasis({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'delegationBasis',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByDeleteReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByDeletedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByDeletedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByDisplayOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayOrder');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByEscalationTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'escalationTier');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByFirestoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByGatingComplianceRequestId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gatingComplianceRequestId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByJobExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionLocalId');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByLaneKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByLaneSetFinalized() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalized');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByLastEscalatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastEscalatedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByMetadataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByProgressRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'progressRevision');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByRemoveReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'removeReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByRemovedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'removedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByRemovedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'removedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByRemovedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'removedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByRepresentedLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'representedLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByStatusKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByTerminateReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'terminateReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByTerminatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'terminatedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByTerminatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'terminatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByTerminatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'terminatedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByUpdatedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByUpdatedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<JobLaneRecord, JobLaneRecord, QDistinct>
      distinctByWorkflowFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowFirestoreId',
          caseSensitive: caseSensitive);
    });
  }
}

extension JobLaneRecordQueryProperty
    on QueryBuilder<JobLaneRecord, JobLaneRecord, QQueryProperty> {
  QueryBuilder<JobLaneRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations>
      acknowledgedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      acknowledgedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      acknowledgedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations>
      acknowledgementDueAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgementDueAt');
    });
  }

  QueryBuilder<JobLaneRecord, int, QQueryOperations>
      activationGenerationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activationGeneration');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations> addReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addReason');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations> addedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations> addedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations> addedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, bool, QQueryOperations>
      addedDuringExecutionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedDuringExecution');
    });
  }

  QueryBuilder<JobLaneRecord, int, QQueryOperations> assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<JobLaneRecord, String, QQueryOperations> assetTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetTypeKey');
    });
  }

  QueryBuilder<JobLaneRecord, int?, QQueryOperations>
      chargeNoAtEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations> closeNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closeNote');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations> closedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      closedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations> closedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      delegationBasisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'delegationBasis');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, int, QQueryOperations> displayOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayOrder');
    });
  }

  QueryBuilder<JobLaneRecord, int, QQueryOperations> escalationTierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'escalationTier');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      gatingComplianceRequestIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gatingComplianceRequestId');
    });
  }

  QueryBuilder<JobLaneRecord, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<JobLaneRecord, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<JobLaneRecord, String, QQueryOperations>
      jobExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionFirestoreId');
    });
  }

  QueryBuilder<JobLaneRecord, int?, QQueryOperations>
      jobExecutionLocalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionLocalId');
    });
  }

  QueryBuilder<JobLaneRecord, String, QQueryOperations> laneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneKey');
    });
  }

  QueryBuilder<JobLaneRecord, bool, QQueryOperations>
      laneSetFinalizedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalized');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations>
      lastEscalatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastEscalatedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<JobLaneRecord, int, QQueryOperations>
      progressRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'progressRevision');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      removeReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'removeReason');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations> removedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'removedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      removedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'removedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      removedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'removedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      representedLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'representedLaneKey');
    });
  }

  QueryBuilder<JobLaneRecord, String, QQueryOperations> statusKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusKey');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      terminateReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'terminateReason');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime?, QQueryOperations>
      terminatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'terminatedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      terminatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'terminatedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      terminatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'terminatedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<JobLaneRecord, String?, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<JobLaneRecord, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<JobLaneRecord, String, QQueryOperations>
      workflowFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowFirestoreId');
    });
  }
}
