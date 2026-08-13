// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compliance_request_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetComplianceRequestRecordCollection on Isar {
  IsarCollection<ComplianceRequestRecord> get complianceRequestRecords =>
      this.collection();
}

const ComplianceRequestRecordSchema = CollectionSchema(
  name: r'ComplianceRequestRecord',
  id: -9091307646920879515,
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
    r'assetNumber': PropertySchema(
      id: 4,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetTypeKey': PropertySchema(
      id: 5,
      name: r'assetTypeKey',
      type: IsarType.string,
    ),
    r'attemptCount': PropertySchema(
      id: 6,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'becameDueAt': PropertySchema(
      id: 7,
      name: r'becameDueAt',
      type: IsarType.dateTime,
    ),
    r'chargeNoAtEvent': PropertySchema(
      id: 8,
      name: r'chargeNoAtEvent',
      type: IsarType.long,
    ),
    r'complianceDueAt': PropertySchema(
      id: 9,
      name: r'complianceDueAt',
      type: IsarType.dateTime,
    ),
    r'complianceNote': PropertySchema(
      id: 10,
      name: r'complianceNote',
      type: IsarType.string,
    ),
    r'compliedAt': PropertySchema(
      id: 11,
      name: r'compliedAt',
      type: IsarType.dateTime,
    ),
    r'compliedByName': PropertySchema(
      id: 12,
      name: r'compliedByName',
      type: IsarType.string,
    ),
    r'compliedByUid': PropertySchema(
      id: 13,
      name: r'compliedByUid',
      type: IsarType.string,
    ),
    r'conditionRef': PropertySchema(
      id: 14,
      name: r'conditionRef',
      type: IsarType.string,
    ),
    r'conditionTypeKey': PropertySchema(
      id: 15,
      name: r'conditionTypeKey',
      type: IsarType.string,
    ),
    r'confirmNote': PropertySchema(
      id: 16,
      name: r'confirmNote',
      type: IsarType.string,
    ),
    r'confirmedAt': PropertySchema(
      id: 17,
      name: r'confirmedAt',
      type: IsarType.dateTime,
    ),
    r'confirmedByName': PropertySchema(
      id: 18,
      name: r'confirmedByName',
      type: IsarType.string,
    ),
    r'confirmedByUid': PropertySchema(
      id: 19,
      name: r'confirmedByUid',
      type: IsarType.string,
    ),
    r'coordinationBasis': PropertySchema(
      id: 20,
      name: r'coordinationBasis',
      type: IsarType.string,
    ),
    r'correctionCount': PropertySchema(
      id: 21,
      name: r'correctionCount',
      type: IsarType.long,
    ),
    r'counterConditionOfId': PropertySchema(
      id: 22,
      name: r'counterConditionOfId',
      type: IsarType.string,
    ),
    r'counterDecisionAt': PropertySchema(
      id: 23,
      name: r'counterDecisionAt',
      type: IsarType.dateTime,
    ),
    r'counterDecisionByName': PropertySchema(
      id: 24,
      name: r'counterDecisionByName',
      type: IsarType.string,
    ),
    r'counterDecisionByUid': PropertySchema(
      id: 25,
      name: r'counterDecisionByUid',
      type: IsarType.string,
    ),
    r'counterDecisionNote': PropertySchema(
      id: 26,
      name: r'counterDecisionNote',
      type: IsarType.string,
    ),
    r'counterDepth': PropertySchema(
      id: 27,
      name: r'counterDepth',
      type: IsarType.long,
    ),
    r'counterProposedAt': PropertySchema(
      id: 28,
      name: r'counterProposedAt',
      type: IsarType.dateTime,
    ),
    r'counterProposedByName': PropertySchema(
      id: 29,
      name: r'counterProposedByName',
      type: IsarType.string,
    ),
    r'counterProposedByUid': PropertySchema(
      id: 30,
      name: r'counterProposedByUid',
      type: IsarType.string,
    ),
    r'counterRevisedDescription': PropertySchema(
      id: 31,
      name: r'counterRevisedDescription',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 32,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'currentAttemptId': PropertySchema(
      id: 33,
      name: r'currentAttemptId',
      type: IsarType.string,
    ),
    r'defermentBasisKey': PropertySchema(
      id: 34,
      name: r'defermentBasisKey',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 35,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 36,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 37,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 38,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 39,
      name: r'description',
      type: IsarType.string,
    ),
    r'dueMarkedAt': PropertySchema(
      id: 40,
      name: r'dueMarkedAt',
      type: IsarType.dateTime,
    ),
    r'dueMarkedByName': PropertySchema(
      id: 41,
      name: r'dueMarkedByName',
      type: IsarType.string,
    ),
    r'dueMarkedByUid': PropertySchema(
      id: 42,
      name: r'dueMarkedByUid',
      type: IsarType.string,
    ),
    r'escalationTier': PropertySchema(
      id: 43,
      name: r'escalationTier',
      type: IsarType.long,
    ),
    r'firestoreId': PropertySchema(
      id: 44,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'gatesLaneFirestoreId': PropertySchema(
      id: 45,
      name: r'gatesLaneFirestoreId',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 46,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 47,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'lastCorrectionAt': PropertySchema(
      id: 48,
      name: r'lastCorrectionAt',
      type: IsarType.dateTime,
    ),
    r'lastCorrectionByName': PropertySchema(
      id: 49,
      name: r'lastCorrectionByName',
      type: IsarType.string,
    ),
    r'lastCorrectionByUid': PropertySchema(
      id: 50,
      name: r'lastCorrectionByUid',
      type: IsarType.string,
    ),
    r'lastCorrectionReason': PropertySchema(
      id: 51,
      name: r'lastCorrectionReason',
      type: IsarType.string,
    ),
    r'lastEscalatedAt': PropertySchema(
      id: 52,
      name: r'lastEscalatedAt',
      type: IsarType.dateTime,
    ),
    r'linkedExecutionFirestoreId': PropertySchema(
      id: 53,
      name: r'linkedExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'linkedLaneFirestoreId': PropertySchema(
      id: 54,
      name: r'linkedLaneFirestoreId',
      type: IsarType.string,
    ),
    r'linkedMaintenanceFirestoreId': PropertySchema(
      id: 55,
      name: r'linkedMaintenanceFirestoreId',
      type: IsarType.string,
    ),
    r'linkedModuleFirestoreId': PropertySchema(
      id: 56,
      name: r'linkedModuleFirestoreId',
      type: IsarType.string,
    ),
    r'linkedWorkflowId': PropertySchema(
      id: 57,
      name: r'linkedWorkflowId',
      type: IsarType.string,
    ),
    r'metadataJson': PropertySchema(
      id: 58,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'operationsResourceKey': PropertySchema(
      id: 59,
      name: r'operationsResourceKey',
      type: IsarType.string,
    ),
    r'operationsSupportTypeKey': PropertySchema(
      id: 60,
      name: r'operationsSupportTypeKey',
      type: IsarType.string,
    ),
    r'originLaneKey': PropertySchema(
      id: 61,
      name: r'originLaneKey',
      type: IsarType.string,
    ),
    r'priorityKey': PropertySchema(
      id: 62,
      name: r'priorityKey',
      type: IsarType.string,
    ),
    r'raisedAt': PropertySchema(
      id: 63,
      name: r'raisedAt',
      type: IsarType.dateTime,
    ),
    r'raisedByName': PropertySchema(
      id: 64,
      name: r'raisedByName',
      type: IsarType.string,
    ),
    r'raisedByUid': PropertySchema(
      id: 65,
      name: r'raisedByUid',
      type: IsarType.string,
    ),
    r'raisedUnderCoordination': PropertySchema(
      id: 66,
      name: r'raisedUnderCoordination',
      type: IsarType.bool,
    ),
    r'requestPurposeKey': PropertySchema(
      id: 67,
      name: r'requestPurposeKey',
      type: IsarType.string,
    ),
    r'requestedLocation': PropertySchema(
      id: 68,
      name: r'requestedLocation',
      type: IsarType.string,
    ),
    r'statusKey': PropertySchema(
      id: 69,
      name: r'statusKey',
      type: IsarType.string,
    ),
    r'supersededById': PropertySchema(
      id: 70,
      name: r'supersededById',
      type: IsarType.string,
    ),
    r'targetLaneKey': PropertySchema(
      id: 71,
      name: r'targetLaneKey',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 72,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 73,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 74,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _complianceRequestRecordEstimateSize,
  serialize: _complianceRequestRecordSerialize,
  deserialize: _complianceRequestRecordDeserialize,
  deserializeProp: _complianceRequestRecordDeserializeProp,
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
    r'targetLaneKey': IndexSchema(
      id: 4924031179401406302,
      name: r'targetLaneKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'targetLaneKey',
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
    r'conditionTypeKey': IndexSchema(
      id: 4770958395200459754,
      name: r'conditionTypeKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conditionTypeKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'conditionRef': IndexSchema(
      id: 5258209796694220704,
      name: r'conditionRef',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conditionRef',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'requestPurposeKey': IndexSchema(
      id: 100764239856524010,
      name: r'requestPurposeKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'requestPurposeKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'counterConditionOfId': IndexSchema(
      id: 920210282975451480,
      name: r'counterConditionOfId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'counterConditionOfId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'linkedWorkflowId': IndexSchema(
      id: 2733958680042996841,
      name: r'linkedWorkflowId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'linkedWorkflowId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'linkedMaintenanceFirestoreId': IndexSchema(
      id: -912488027824445930,
      name: r'linkedMaintenanceFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'linkedMaintenanceFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'linkedExecutionFirestoreId': IndexSchema(
      id: 1647195491388909668,
      name: r'linkedExecutionFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'linkedExecutionFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'gatesLaneFirestoreId': IndexSchema(
      id: 7062890400356929919,
      name: r'gatesLaneFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'gatesLaneFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
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
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _complianceRequestRecordGetId,
  getLinks: _complianceRequestRecordGetLinks,
  attach: _complianceRequestRecordAttach,
  version: '3.1.0+1',
);

int _complianceRequestRecordEstimateSize(
  ComplianceRequestRecord object,
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
  bytesCount += 3 + object.assetTypeKey.length * 3;
  {
    final value = object.complianceNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.compliedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.compliedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.conditionRef;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.conditionTypeKey.length * 3;
  {
    final value = object.confirmNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.confirmedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.confirmedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.coordinationBasis;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterConditionOfId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterDecisionByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterDecisionByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterDecisionNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterProposedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterProposedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.counterRevisedDescription;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.currentAttemptId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.defermentBasisKey;
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
  bytesCount += 3 + object.description.length * 3;
  {
    final value = object.dueMarkedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.dueMarkedByUid;
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
    final value = object.gatesLaneFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastCorrectionByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastCorrectionByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastCorrectionReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.linkedExecutionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.linkedLaneFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.linkedMaintenanceFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.linkedModuleFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.linkedWorkflowId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.operationsResourceKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.operationsSupportTypeKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.originLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.priorityKey.length * 3;
  {
    final value = object.raisedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.raisedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.requestPurposeKey.length * 3;
  {
    final value = object.requestedLocation;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.statusKey.length * 3;
  {
    final value = object.supersededById;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.targetLaneKey.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _complianceRequestRecordSerialize(
  ComplianceRequestRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acknowledgedAt);
  writer.writeString(offsets[1], object.acknowledgedByName);
  writer.writeString(offsets[2], object.acknowledgedByUid);
  writer.writeDateTime(offsets[3], object.acknowledgementDueAt);
  writer.writeLong(offsets[4], object.assetNumber);
  writer.writeString(offsets[5], object.assetTypeKey);
  writer.writeLong(offsets[6], object.attemptCount);
  writer.writeDateTime(offsets[7], object.becameDueAt);
  writer.writeLong(offsets[8], object.chargeNoAtEvent);
  writer.writeDateTime(offsets[9], object.complianceDueAt);
  writer.writeString(offsets[10], object.complianceNote);
  writer.writeDateTime(offsets[11], object.compliedAt);
  writer.writeString(offsets[12], object.compliedByName);
  writer.writeString(offsets[13], object.compliedByUid);
  writer.writeString(offsets[14], object.conditionRef);
  writer.writeString(offsets[15], object.conditionTypeKey);
  writer.writeString(offsets[16], object.confirmNote);
  writer.writeDateTime(offsets[17], object.confirmedAt);
  writer.writeString(offsets[18], object.confirmedByName);
  writer.writeString(offsets[19], object.confirmedByUid);
  writer.writeString(offsets[20], object.coordinationBasis);
  writer.writeLong(offsets[21], object.correctionCount);
  writer.writeString(offsets[22], object.counterConditionOfId);
  writer.writeDateTime(offsets[23], object.counterDecisionAt);
  writer.writeString(offsets[24], object.counterDecisionByName);
  writer.writeString(offsets[25], object.counterDecisionByUid);
  writer.writeString(offsets[26], object.counterDecisionNote);
  writer.writeLong(offsets[27], object.counterDepth);
  writer.writeDateTime(offsets[28], object.counterProposedAt);
  writer.writeString(offsets[29], object.counterProposedByName);
  writer.writeString(offsets[30], object.counterProposedByUid);
  writer.writeString(offsets[31], object.counterRevisedDescription);
  writer.writeDateTime(offsets[32], object.createdAt);
  writer.writeString(offsets[33], object.currentAttemptId);
  writer.writeString(offsets[34], object.defermentBasisKey);
  writer.writeString(offsets[35], object.deleteReason);
  writer.writeDateTime(offsets[36], object.deletedAt);
  writer.writeString(offsets[37], object.deletedByName);
  writer.writeString(offsets[38], object.deletedByUid);
  writer.writeString(offsets[39], object.description);
  writer.writeDateTime(offsets[40], object.dueMarkedAt);
  writer.writeString(offsets[41], object.dueMarkedByName);
  writer.writeString(offsets[42], object.dueMarkedByUid);
  writer.writeLong(offsets[43], object.escalationTier);
  writer.writeString(offsets[44], object.firestoreId);
  writer.writeString(offsets[45], object.gatesLaneFirestoreId);
  writer.writeBool(offsets[46], object.isDeleted);
  writer.writeBool(offsets[47], object.isSynced);
  writer.writeDateTime(offsets[48], object.lastCorrectionAt);
  writer.writeString(offsets[49], object.lastCorrectionByName);
  writer.writeString(offsets[50], object.lastCorrectionByUid);
  writer.writeString(offsets[51], object.lastCorrectionReason);
  writer.writeDateTime(offsets[52], object.lastEscalatedAt);
  writer.writeString(offsets[53], object.linkedExecutionFirestoreId);
  writer.writeString(offsets[54], object.linkedLaneFirestoreId);
  writer.writeString(offsets[55], object.linkedMaintenanceFirestoreId);
  writer.writeString(offsets[56], object.linkedModuleFirestoreId);
  writer.writeString(offsets[57], object.linkedWorkflowId);
  writer.writeString(offsets[58], object.metadataJson);
  writer.writeString(offsets[59], object.operationsResourceKey);
  writer.writeString(offsets[60], object.operationsSupportTypeKey);
  writer.writeString(offsets[61], object.originLaneKey);
  writer.writeString(offsets[62], object.priorityKey);
  writer.writeDateTime(offsets[63], object.raisedAt);
  writer.writeString(offsets[64], object.raisedByName);
  writer.writeString(offsets[65], object.raisedByUid);
  writer.writeBool(offsets[66], object.raisedUnderCoordination);
  writer.writeString(offsets[67], object.requestPurposeKey);
  writer.writeString(offsets[68], object.requestedLocation);
  writer.writeString(offsets[69], object.statusKey);
  writer.writeString(offsets[70], object.supersededById);
  writer.writeString(offsets[71], object.targetLaneKey);
  writer.writeString(offsets[72], object.title);
  writer.writeDateTime(offsets[73], object.updatedAt);
  writer.writeLong(offsets[74], object.version);
}

ComplianceRequestRecord _complianceRequestRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ComplianceRequestRecord();
  object.acknowledgedAt = reader.readDateTimeOrNull(offsets[0]);
  object.acknowledgedByName = reader.readStringOrNull(offsets[1]);
  object.acknowledgedByUid = reader.readStringOrNull(offsets[2]);
  object.acknowledgementDueAt = reader.readDateTimeOrNull(offsets[3]);
  object.assetNumber = reader.readLong(offsets[4]);
  object.assetTypeKey = reader.readString(offsets[5]);
  object.attemptCount = reader.readLong(offsets[6]);
  object.becameDueAt = reader.readDateTimeOrNull(offsets[7]);
  object.chargeNoAtEvent = reader.readLongOrNull(offsets[8]);
  object.complianceDueAt = reader.readDateTimeOrNull(offsets[9]);
  object.complianceNote = reader.readStringOrNull(offsets[10]);
  object.compliedAt = reader.readDateTimeOrNull(offsets[11]);
  object.compliedByName = reader.readStringOrNull(offsets[12]);
  object.compliedByUid = reader.readStringOrNull(offsets[13]);
  object.conditionRef = reader.readStringOrNull(offsets[14]);
  object.conditionTypeKey = reader.readString(offsets[15]);
  object.confirmNote = reader.readStringOrNull(offsets[16]);
  object.confirmedAt = reader.readDateTimeOrNull(offsets[17]);
  object.confirmedByName = reader.readStringOrNull(offsets[18]);
  object.confirmedByUid = reader.readStringOrNull(offsets[19]);
  object.coordinationBasis = reader.readStringOrNull(offsets[20]);
  object.correctionCount = reader.readLong(offsets[21]);
  object.counterConditionOfId = reader.readStringOrNull(offsets[22]);
  object.counterDecisionAt = reader.readDateTimeOrNull(offsets[23]);
  object.counterDecisionByName = reader.readStringOrNull(offsets[24]);
  object.counterDecisionByUid = reader.readStringOrNull(offsets[25]);
  object.counterDecisionNote = reader.readStringOrNull(offsets[26]);
  object.counterDepth = reader.readLong(offsets[27]);
  object.counterProposedAt = reader.readDateTimeOrNull(offsets[28]);
  object.counterProposedByName = reader.readStringOrNull(offsets[29]);
  object.counterProposedByUid = reader.readStringOrNull(offsets[30]);
  object.counterRevisedDescription = reader.readStringOrNull(offsets[31]);
  object.createdAt = reader.readDateTime(offsets[32]);
  object.currentAttemptId = reader.readStringOrNull(offsets[33]);
  object.defermentBasisKey = reader.readStringOrNull(offsets[34]);
  object.deleteReason = reader.readStringOrNull(offsets[35]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[36]);
  object.deletedByName = reader.readStringOrNull(offsets[37]);
  object.deletedByUid = reader.readStringOrNull(offsets[38]);
  object.description = reader.readString(offsets[39]);
  object.dueMarkedAt = reader.readDateTimeOrNull(offsets[40]);
  object.dueMarkedByName = reader.readStringOrNull(offsets[41]);
  object.dueMarkedByUid = reader.readStringOrNull(offsets[42]);
  object.escalationTier = reader.readLong(offsets[43]);
  object.firestoreId = reader.readStringOrNull(offsets[44]);
  object.gatesLaneFirestoreId = reader.readStringOrNull(offsets[45]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[46]);
  object.isSynced = reader.readBool(offsets[47]);
  object.lastCorrectionAt = reader.readDateTimeOrNull(offsets[48]);
  object.lastCorrectionByName = reader.readStringOrNull(offsets[49]);
  object.lastCorrectionByUid = reader.readStringOrNull(offsets[50]);
  object.lastCorrectionReason = reader.readStringOrNull(offsets[51]);
  object.lastEscalatedAt = reader.readDateTimeOrNull(offsets[52]);
  object.linkedExecutionFirestoreId = reader.readStringOrNull(offsets[53]);
  object.linkedLaneFirestoreId = reader.readStringOrNull(offsets[54]);
  object.linkedMaintenanceFirestoreId = reader.readStringOrNull(offsets[55]);
  object.linkedModuleFirestoreId = reader.readStringOrNull(offsets[56]);
  object.linkedWorkflowId = reader.readStringOrNull(offsets[57]);
  object.metadataJson = reader.readStringOrNull(offsets[58]);
  object.operationsResourceKey = reader.readStringOrNull(offsets[59]);
  object.operationsSupportTypeKey = reader.readStringOrNull(offsets[60]);
  object.originLaneKey = reader.readStringOrNull(offsets[61]);
  object.priorityKey = reader.readString(offsets[62]);
  object.raisedAt = reader.readDateTimeOrNull(offsets[63]);
  object.raisedByName = reader.readStringOrNull(offsets[64]);
  object.raisedByUid = reader.readStringOrNull(offsets[65]);
  object.raisedUnderCoordination = reader.readBool(offsets[66]);
  object.requestPurposeKey = reader.readString(offsets[67]);
  object.requestedLocation = reader.readStringOrNull(offsets[68]);
  object.statusKey = reader.readString(offsets[69]);
  object.supersededById = reader.readStringOrNull(offsets[70]);
  object.targetLaneKey = reader.readString(offsets[71]);
  object.title = reader.readString(offsets[72]);
  object.updatedAt = reader.readDateTime(offsets[73]);
  object.version = reader.readLong(offsets[74]);
  return object;
}

P _complianceRequestRecordDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (reader.readLong(offset)) as P;
    case 22:
      return (reader.readStringOrNull(offset)) as P;
    case 23:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 24:
      return (reader.readStringOrNull(offset)) as P;
    case 25:
      return (reader.readStringOrNull(offset)) as P;
    case 26:
      return (reader.readStringOrNull(offset)) as P;
    case 27:
      return (reader.readLong(offset)) as P;
    case 28:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 29:
      return (reader.readStringOrNull(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readStringOrNull(offset)) as P;
    case 32:
      return (reader.readDateTime(offset)) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 37:
      return (reader.readStringOrNull(offset)) as P;
    case 38:
      return (reader.readStringOrNull(offset)) as P;
    case 39:
      return (reader.readString(offset)) as P;
    case 40:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 41:
      return (reader.readStringOrNull(offset)) as P;
    case 42:
      return (reader.readStringOrNull(offset)) as P;
    case 43:
      return (reader.readLong(offset)) as P;
    case 44:
      return (reader.readStringOrNull(offset)) as P;
    case 45:
      return (reader.readStringOrNull(offset)) as P;
    case 46:
      return (reader.readBool(offset)) as P;
    case 47:
      return (reader.readBool(offset)) as P;
    case 48:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 49:
      return (reader.readStringOrNull(offset)) as P;
    case 50:
      return (reader.readStringOrNull(offset)) as P;
    case 51:
      return (reader.readStringOrNull(offset)) as P;
    case 52:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 53:
      return (reader.readStringOrNull(offset)) as P;
    case 54:
      return (reader.readStringOrNull(offset)) as P;
    case 55:
      return (reader.readStringOrNull(offset)) as P;
    case 56:
      return (reader.readStringOrNull(offset)) as P;
    case 57:
      return (reader.readStringOrNull(offset)) as P;
    case 58:
      return (reader.readStringOrNull(offset)) as P;
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
      return (reader.readBool(offset)) as P;
    case 67:
      return (reader.readString(offset)) as P;
    case 68:
      return (reader.readStringOrNull(offset)) as P;
    case 69:
      return (reader.readString(offset)) as P;
    case 70:
      return (reader.readStringOrNull(offset)) as P;
    case 71:
      return (reader.readString(offset)) as P;
    case 72:
      return (reader.readString(offset)) as P;
    case 73:
      return (reader.readDateTime(offset)) as P;
    case 74:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _complianceRequestRecordGetId(ComplianceRequestRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _complianceRequestRecordGetLinks(
    ComplianceRequestRecord object) {
  return [];
}

void _complianceRequestRecordAttach(
    IsarCollection<dynamic> col, Id id, ComplianceRequestRecord object) {
  object.id = id;
}

extension ComplianceRequestRecordByIndex
    on IsarCollection<ComplianceRequestRecord> {
  Future<ComplianceRequestRecord?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  ComplianceRequestRecord? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<ComplianceRequestRecord?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<ComplianceRequestRecord?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(ComplianceRequestRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(ComplianceRequestRecord object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<ComplianceRequestRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<ComplianceRequestRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension ComplianceRequestRecordQueryWhereSort
    on QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QWhere> {
  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterWhere>
      anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }
}

extension ComplianceRequestRecordQueryWhere on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QWhereClause> {
  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> idBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'firestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> firestoreIdNotEqualTo(String? firestoreId) {
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> isSyncedNotEqualTo(bool isSynced) {
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> targetLaneKeyEqualTo(String targetLaneKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'targetLaneKey',
        value: [targetLaneKey],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> targetLaneKeyNotEqualTo(String targetLaneKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetLaneKey',
              lower: [],
              upper: [targetLaneKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetLaneKey',
              lower: [targetLaneKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetLaneKey',
              lower: [targetLaneKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetLaneKey',
              lower: [],
              upper: [targetLaneKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> statusKeyEqualTo(String statusKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'statusKey',
        value: [statusKey],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> statusKeyNotEqualTo(String statusKey) {
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> conditionTypeKeyEqualTo(String conditionTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conditionTypeKey',
        value: [conditionTypeKey],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> conditionTypeKeyNotEqualTo(String conditionTypeKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionTypeKey',
              lower: [],
              upper: [conditionTypeKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionTypeKey',
              lower: [conditionTypeKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionTypeKey',
              lower: [conditionTypeKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionTypeKey',
              lower: [],
              upper: [conditionTypeKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> conditionRefIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conditionRef',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> conditionRefIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'conditionRef',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> conditionRefEqualTo(String? conditionRef) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conditionRef',
        value: [conditionRef],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> conditionRefNotEqualTo(String? conditionRef) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionRef',
              lower: [],
              upper: [conditionRef],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionRef',
              lower: [conditionRef],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionRef',
              lower: [conditionRef],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conditionRef',
              lower: [],
              upper: [conditionRef],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> requestPurposeKeyEqualTo(String requestPurposeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'requestPurposeKey',
        value: [requestPurposeKey],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> requestPurposeKeyNotEqualTo(String requestPurposeKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requestPurposeKey',
              lower: [],
              upper: [requestPurposeKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requestPurposeKey',
              lower: [requestPurposeKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requestPurposeKey',
              lower: [requestPurposeKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requestPurposeKey',
              lower: [],
              upper: [requestPurposeKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> counterConditionOfIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'counterConditionOfId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> counterConditionOfIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'counterConditionOfId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      counterConditionOfIdEqualTo(String? counterConditionOfId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'counterConditionOfId',
        value: [counterConditionOfId],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      counterConditionOfIdNotEqualTo(String? counterConditionOfId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'counterConditionOfId',
              lower: [],
              upper: [counterConditionOfId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'counterConditionOfId',
              lower: [counterConditionOfId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'counterConditionOfId',
              lower: [counterConditionOfId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'counterConditionOfId',
              lower: [],
              upper: [counterConditionOfId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedWorkflowIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'linkedWorkflowId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedWorkflowIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'linkedWorkflowId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedWorkflowIdEqualTo(String? linkedWorkflowId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'linkedWorkflowId',
        value: [linkedWorkflowId],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedWorkflowIdNotEqualTo(String? linkedWorkflowId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedWorkflowId',
              lower: [],
              upper: [linkedWorkflowId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedWorkflowId',
              lower: [linkedWorkflowId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedWorkflowId',
              lower: [linkedWorkflowId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedWorkflowId',
              lower: [],
              upper: [linkedWorkflowId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedMaintenanceFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'linkedMaintenanceFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedMaintenanceFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'linkedMaintenanceFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      linkedMaintenanceFirestoreIdEqualTo(
          String? linkedMaintenanceFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'linkedMaintenanceFirestoreId',
        value: [linkedMaintenanceFirestoreId],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      linkedMaintenanceFirestoreIdNotEqualTo(
          String? linkedMaintenanceFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedMaintenanceFirestoreId',
              lower: [],
              upper: [linkedMaintenanceFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedMaintenanceFirestoreId',
              lower: [linkedMaintenanceFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedMaintenanceFirestoreId',
              lower: [linkedMaintenanceFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedMaintenanceFirestoreId',
              lower: [],
              upper: [linkedMaintenanceFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'linkedExecutionFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> linkedExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'linkedExecutionFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      linkedExecutionFirestoreIdEqualTo(String? linkedExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'linkedExecutionFirestoreId',
        value: [linkedExecutionFirestoreId],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      linkedExecutionFirestoreIdNotEqualTo(String? linkedExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedExecutionFirestoreId',
              lower: [],
              upper: [linkedExecutionFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedExecutionFirestoreId',
              lower: [linkedExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedExecutionFirestoreId',
              lower: [linkedExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'linkedExecutionFirestoreId',
              lower: [],
              upper: [linkedExecutionFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> gatesLaneFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'gatesLaneFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> gatesLaneFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'gatesLaneFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      gatesLaneFirestoreIdEqualTo(String? gatesLaneFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'gatesLaneFirestoreId',
        value: [gatesLaneFirestoreId],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterWhereClause>
      gatesLaneFirestoreIdNotEqualTo(String? gatesLaneFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'gatesLaneFirestoreId',
              lower: [],
              upper: [gatesLaneFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'gatesLaneFirestoreId',
              lower: [gatesLaneFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'gatesLaneFirestoreId',
              lower: [gatesLaneFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'gatesLaneFirestoreId',
              lower: [],
              upper: [gatesLaneFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetTypeKeyEqualTo(String assetTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetTypeKey',
        value: [assetTypeKey],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetTypeKeyNotEqualTo(String assetTypeKey) {
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetNumberNotEqualTo(int assetNumber) {
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetNumberGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetNumberLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterWhereClause> assetNumberBetween(
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
}

extension ComplianceRequestRecordQueryFilter on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QFilterCondition> {
  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedAtGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedAtLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedAtBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      acknowledgedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      acknowledgedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      acknowledgedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      acknowledgedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgementDueAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgementDueAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgementDueAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgementDueAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgementDueAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgementDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgementDueAtGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgementDueAtLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> acknowledgementDueAtBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetNumberGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetNumberLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetNumberBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      assetTypeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      assetTypeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> assetTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> attemptCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> attemptCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> attemptCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> becameDueAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'becameDueAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> becameDueAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'becameDueAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> becameDueAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'becameDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> becameDueAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'becameDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> becameDueAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'becameDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> becameDueAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'becameDueAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> chargeNoAtEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> chargeNoAtEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> chargeNoAtEventEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> chargeNoAtEventGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> chargeNoAtEventLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> chargeNoAtEventBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceDueAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'complianceDueAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceDueAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'complianceDueAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceDueAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceDueAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'complianceDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceDueAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'complianceDueAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceDueAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'complianceDueAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'complianceNote',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'complianceNote',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'complianceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'complianceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'complianceNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'complianceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'complianceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      complianceNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'complianceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      complianceNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'complianceNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> complianceNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'complianceNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'compliedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'compliedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'compliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'compliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'compliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'compliedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'compliedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'compliedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'compliedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'compliedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'compliedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'compliedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'compliedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'compliedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      compliedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'compliedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      compliedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'compliedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'compliedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'compliedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'compliedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'compliedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'compliedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'compliedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'compliedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'compliedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'compliedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'compliedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      compliedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'compliedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      compliedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'compliedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'compliedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> compliedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'compliedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'conditionRef',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'conditionRef',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conditionRef',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      conditionRefContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conditionRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      conditionRefMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conditionRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conditionRef',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conditionRef',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conditionTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      conditionTypeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conditionTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      conditionTypeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conditionTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conditionTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> conditionTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conditionTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'confirmNote',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'confirmNote',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confirmNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confirmNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confirmNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'confirmNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'confirmNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      confirmNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'confirmNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      confirmNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'confirmNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'confirmNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'confirmedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'confirmedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confirmedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confirmedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confirmedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'confirmedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'confirmedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confirmedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'confirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'confirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      confirmedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'confirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      confirmedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'confirmedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'confirmedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'confirmedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'confirmedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confirmedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'confirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'confirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      confirmedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'confirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      confirmedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'confirmedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confirmedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> confirmedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'confirmedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coordinationBasis',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coordinationBasis',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coordinationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coordinationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coordinationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coordinationBasis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'coordinationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'coordinationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      coordinationBasisContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'coordinationBasis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      coordinationBasisMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'coordinationBasis',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coordinationBasis',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> coordinationBasisIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'coordinationBasis',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> correctionCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'correctionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> correctionCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'correctionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> correctionCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'correctionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> correctionCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'correctionCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterConditionOfId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterConditionOfId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterConditionOfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterConditionOfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterConditionOfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterConditionOfId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterConditionOfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterConditionOfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterConditionOfIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterConditionOfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterConditionOfIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterConditionOfId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterConditionOfId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterConditionOfIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterConditionOfId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterDecisionAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterDecisionAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterDecisionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterDecisionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterDecisionAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterDecisionByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterDecisionByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterDecisionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterDecisionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterDecisionByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterDecisionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterDecisionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterDecisionByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterDecisionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterDecisionByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterDecisionByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterDecisionByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterDecisionByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterDecisionByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterDecisionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterDecisionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterDecisionByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterDecisionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterDecisionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterDecisionByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterDecisionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterDecisionByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterDecisionByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterDecisionByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterDecisionNote',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterDecisionNote',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterDecisionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterDecisionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterDecisionNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterDecisionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterDecisionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterDecisionNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterDecisionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterDecisionNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterDecisionNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDecisionNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDecisionNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterDecisionNote',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDepthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterDepth',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDepthGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterDepth',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDepthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterDepth',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterDepthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterDepth',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterProposedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterProposedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterProposedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterProposedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterProposedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterProposedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterProposedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterProposedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterProposedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterProposedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterProposedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterProposedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterProposedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterProposedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterProposedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterProposedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterProposedByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterProposedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterProposedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterProposedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterProposedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterProposedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterProposedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterProposedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterProposedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterProposedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterProposedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterProposedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterProposedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterProposedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterProposedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterProposedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterProposedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterProposedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterProposedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'counterRevisedDescription',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'counterRevisedDescription',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterRevisedDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'counterRevisedDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'counterRevisedDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'counterRevisedDescription',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'counterRevisedDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'counterRevisedDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterRevisedDescriptionContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'counterRevisedDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      counterRevisedDescriptionMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'counterRevisedDescription',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'counterRevisedDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> counterRevisedDescriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'counterRevisedDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'currentAttemptId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'currentAttemptId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currentAttemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'currentAttemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'currentAttemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'currentAttemptId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'currentAttemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'currentAttemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      currentAttemptIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'currentAttemptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      currentAttemptIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'currentAttemptId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currentAttemptId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> currentAttemptIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'currentAttemptId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'defermentBasisKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'defermentBasisKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'defermentBasisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'defermentBasisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'defermentBasisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'defermentBasisKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'defermentBasisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'defermentBasisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      defermentBasisKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'defermentBasisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      defermentBasisKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'defermentBasisKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'defermentBasisKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> defermentBasisKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'defermentBasisKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedAtGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedAtLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedAtBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dueMarkedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dueMarkedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dueMarkedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dueMarkedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dueMarkedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dueMarkedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dueMarkedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dueMarkedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dueMarkedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dueMarkedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dueMarkedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dueMarkedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dueMarkedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dueMarkedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      dueMarkedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dueMarkedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      dueMarkedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dueMarkedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dueMarkedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dueMarkedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dueMarkedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dueMarkedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dueMarkedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dueMarkedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dueMarkedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dueMarkedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dueMarkedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dueMarkedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      dueMarkedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dueMarkedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      dueMarkedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dueMarkedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dueMarkedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> dueMarkedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dueMarkedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> escalationTierEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'escalationTier',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> escalationTierGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> escalationTierLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> escalationTierBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gatesLaneFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gatesLaneFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gatesLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gatesLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gatesLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gatesLaneFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'gatesLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'gatesLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      gatesLaneFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'gatesLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      gatesLaneFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'gatesLaneFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gatesLaneFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> gatesLaneFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'gatesLaneFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> idLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> idBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastCorrectionAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastCorrectionAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastCorrectionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastCorrectionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastCorrectionAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastCorrectionByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastCorrectionByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastCorrectionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastCorrectionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastCorrectionByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastCorrectionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastCorrectionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      lastCorrectionByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastCorrectionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      lastCorrectionByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastCorrectionByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastCorrectionByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastCorrectionByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastCorrectionByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastCorrectionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastCorrectionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastCorrectionByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastCorrectionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastCorrectionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      lastCorrectionByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastCorrectionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      lastCorrectionByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastCorrectionByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastCorrectionByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastCorrectionReason',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastCorrectionReason',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastCorrectionReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      lastCorrectionReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastCorrectionReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      lastCorrectionReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastCorrectionReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastCorrectionReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastCorrectionReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastCorrectionReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastEscalatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastEscalatedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastEscalatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastEscalatedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastEscalatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEscalatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastEscalatedAtGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastEscalatedAtLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> lastEscalatedAtBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedExecutionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedExecutionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedExecutionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedExecutionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedLaneFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedLaneFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedLaneFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedLaneFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedLaneFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedLaneFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedLaneFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedLaneFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedLaneFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedMaintenanceFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedMaintenanceFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedMaintenanceFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedMaintenanceFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedMaintenanceFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedMaintenanceFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedMaintenanceFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedMaintenanceFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedModuleFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedModuleFirestoreId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedModuleFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedModuleFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedModuleFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedModuleFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedModuleFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedModuleFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedModuleFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedModuleFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedModuleFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedModuleFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedModuleFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedModuleFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedModuleFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedWorkflowId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedWorkflowId',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedWorkflowId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedWorkflowId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedWorkflowId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedWorkflowId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedWorkflowId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedWorkflowId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedWorkflowIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedWorkflowId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      linkedWorkflowIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedWorkflowId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedWorkflowId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> linkedWorkflowIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedWorkflowId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'operationsResourceKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'operationsResourceKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationsResourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'operationsResourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'operationsResourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'operationsResourceKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'operationsResourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'operationsResourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      operationsResourceKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'operationsResourceKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      operationsResourceKeyMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'operationsResourceKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationsResourceKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsResourceKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'operationsResourceKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'operationsSupportTypeKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'operationsSupportTypeKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationsSupportTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'operationsSupportTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'operationsSupportTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'operationsSupportTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'operationsSupportTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'operationsSupportTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      operationsSupportTypeKeyContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'operationsSupportTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      operationsSupportTypeKeyMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'operationsSupportTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationsSupportTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> operationsSupportTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'operationsSupportTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'originLaneKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'originLaneKey',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      originLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      originLaneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> originLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'priorityKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'priorityKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'priorityKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'priorityKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'priorityKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'priorityKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      priorityKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'priorityKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      priorityKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'priorityKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'priorityKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> priorityKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'priorityKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'raisedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'raisedAt',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'raisedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'raisedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'raisedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'raisedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'raisedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'raisedByName',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'raisedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'raisedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'raisedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'raisedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'raisedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'raisedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      raisedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'raisedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      raisedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'raisedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'raisedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'raisedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'raisedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'raisedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'raisedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'raisedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'raisedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'raisedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'raisedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'raisedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      raisedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'raisedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      raisedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'raisedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'raisedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'raisedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> raisedUnderCoordinationEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'raisedUnderCoordination',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requestPurposeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'requestPurposeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'requestPurposeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'requestPurposeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'requestPurposeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'requestPurposeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      requestPurposeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'requestPurposeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      requestPurposeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'requestPurposeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requestPurposeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestPurposeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'requestPurposeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'requestedLocation',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'requestedLocation',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requestedLocation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'requestedLocation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'requestedLocation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'requestedLocation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'requestedLocation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'requestedLocation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      requestedLocationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'requestedLocation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      requestedLocationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'requestedLocation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requestedLocation',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> requestedLocationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'requestedLocation',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyEqualTo(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyStartsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyEndsWith(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      statusKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'statusKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      statusKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'statusKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'statusKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> statusKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'statusKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'supersededById',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'supersededById',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supersededById',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'supersededById',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'supersededById',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'supersededById',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'supersededById',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'supersededById',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      supersededByIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'supersededById',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      supersededByIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'supersededById',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supersededById',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> supersededByIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'supersededById',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      targetLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      targetLaneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> targetLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
          QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> updatedAtBetween(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> versionGreaterThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> versionLessThan(
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

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord,
      QAfterFilterCondition> versionBetween(
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
}

extension ComplianceRequestRecordQueryObject on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QFilterCondition> {}

extension ComplianceRequestRecordQueryLinks on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QFilterCondition> {}

extension ComplianceRequestRecordQuerySortBy
    on QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QSortBy> {
  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgementDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAcknowledgementDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByBecameDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'becameDueAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByBecameDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'becameDueAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByComplianceDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceDueAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByComplianceDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceDueAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByComplianceNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceNote', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByComplianceNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceNote', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCompliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCompliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCompliedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCompliedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCompliedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCompliedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConditionRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionRef', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConditionRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionRef', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConditionTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionTypeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConditionTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionTypeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmNote', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmNote', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByConfirmedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCoordinationBasis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coordinationBasis', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCoordinationBasisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coordinationBasis', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCorrectionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctionCount', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCorrectionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctionCount', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterConditionOfId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterConditionOfId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterConditionOfIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterConditionOfId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionNote', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDecisionNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionNote', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDepth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDepth', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterDepthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDepth', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterProposedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterProposedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterProposedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterProposedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterProposedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterProposedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterRevisedDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterRevisedDescription', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCounterRevisedDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterRevisedDescription', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCurrentAttemptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAttemptId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByCurrentAttemptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAttemptId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDefermentBasisKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defermentBasisKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDefermentBasisKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defermentBasisKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDueMarkedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDueMarkedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDueMarkedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDueMarkedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDueMarkedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByDueMarkedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByEscalationTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByEscalationTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByGatesLaneFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatesLaneFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByGatesLaneFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatesLaneFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionReason', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastCorrectionReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionReason', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastEscalatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLastEscalatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedLaneFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedLaneFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedLaneFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedLaneFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedMaintenanceFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedMaintenanceFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedModuleFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedModuleFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedModuleFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedModuleFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedWorkflowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedWorkflowId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByLinkedWorkflowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedWorkflowId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByOperationsResourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsResourceKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByOperationsResourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsResourceKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByOperationsSupportTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsSupportTypeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByOperationsSupportTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsSupportTypeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByOriginLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originLaneKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByOriginLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originLaneKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByPriorityKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priorityKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByPriorityKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priorityKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedUnderCoordination() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedUnderCoordination', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRaisedUnderCoordinationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedUnderCoordination', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRequestPurposeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestPurposeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRequestPurposeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestPurposeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRequestedLocation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestedLocation', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByRequestedLocationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestedLocation', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByStatusKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByStatusKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortBySupersededById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supersededById', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortBySupersededByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supersededById', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByTargetLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLaneKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByTargetLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLaneKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension ComplianceRequestRecordQuerySortThenBy on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QSortThenBy> {
  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgementDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAcknowledgementDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgementDueAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByBecameDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'becameDueAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByBecameDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'becameDueAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByComplianceDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceDueAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByComplianceDueAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceDueAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByComplianceNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceNote', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByComplianceNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceNote', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCompliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCompliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCompliedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCompliedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCompliedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCompliedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compliedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConditionRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionRef', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConditionRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionRef', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConditionTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionTypeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConditionTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conditionTypeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmNote', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmNote', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByConfirmedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confirmedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCoordinationBasis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coordinationBasis', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCoordinationBasisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coordinationBasis', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCorrectionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctionCount', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCorrectionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'correctionCount', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterConditionOfId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterConditionOfId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterConditionOfIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterConditionOfId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionNote', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDecisionNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDecisionNote', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDepth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDepth', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterDepthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterDepth', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterProposedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterProposedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterProposedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterProposedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterProposedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterProposedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterProposedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterRevisedDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterRevisedDescription', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCounterRevisedDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'counterRevisedDescription', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCurrentAttemptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAttemptId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByCurrentAttemptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAttemptId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDefermentBasisKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defermentBasisKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDefermentBasisKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defermentBasisKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDueMarkedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDueMarkedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDueMarkedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDueMarkedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDueMarkedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByDueMarkedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueMarkedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByEscalationTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByEscalationTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'escalationTier', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByGatesLaneFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatesLaneFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByGatesLaneFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gatesLaneFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionReason', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastCorrectionReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCorrectionReason', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastEscalatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLastEscalatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEscalatedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedLaneFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedLaneFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedLaneFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedLaneFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedMaintenanceFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedMaintenanceFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedModuleFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedModuleFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedModuleFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedModuleFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedWorkflowId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedWorkflowId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByLinkedWorkflowIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedWorkflowId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByOperationsResourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsResourceKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByOperationsResourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsResourceKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByOperationsSupportTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsSupportTypeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByOperationsSupportTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationsSupportTypeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByOriginLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originLaneKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByOriginLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originLaneKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByPriorityKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priorityKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByPriorityKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priorityKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedUnderCoordination() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedUnderCoordination', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRaisedUnderCoordinationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'raisedUnderCoordination', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRequestPurposeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestPurposeKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRequestPurposeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestPurposeKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRequestedLocation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestedLocation', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByRequestedLocationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestedLocation', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByStatusKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByStatusKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenBySupersededById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supersededById', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenBySupersededByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supersededById', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByTargetLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLaneKey', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByTargetLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetLaneKey', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension ComplianceRequestRecordQueryWhereDistinct on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QDistinct> {
  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAcknowledgedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAcknowledgedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAcknowledgementDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgementDueAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAssetTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetTypeKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByBecameDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'becameDueAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByComplianceDueAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'complianceDueAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByComplianceNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'complianceNote',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCompliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'compliedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCompliedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'compliedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCompliedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'compliedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByConditionRef({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conditionRef', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByConditionTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conditionTypeKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByConfirmNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmNote', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByConfirmedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByConfirmedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confirmedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCoordinationBasis({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coordinationBasis',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCorrectionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'correctionCount');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterConditionOfId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterConditionOfId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterDecisionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterDecisionAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterDecisionByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterDecisionByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterDecisionByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterDecisionByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterDecisionNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterDecisionNote',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterDepth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterDepth');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterProposedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterProposedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterProposedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterProposedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterProposedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterProposedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCounterRevisedDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'counterRevisedDescription',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByCurrentAttemptId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currentAttemptId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDefermentBasisKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defermentBasisKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDueMarkedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dueMarkedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDueMarkedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dueMarkedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByDueMarkedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dueMarkedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByEscalationTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'escalationTier');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByGatesLaneFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gatesLaneFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLastCorrectionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastCorrectionAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLastCorrectionByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastCorrectionByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLastCorrectionByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastCorrectionByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLastCorrectionReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastCorrectionReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLastEscalatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastEscalatedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLinkedExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLinkedLaneFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedLaneFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLinkedMaintenanceFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedMaintenanceFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLinkedModuleFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedModuleFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByLinkedWorkflowId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedWorkflowId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByOperationsResourceKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operationsResourceKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByOperationsSupportTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operationsSupportTypeKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByOriginLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByPriorityKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'priorityKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByRaisedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'raisedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByRaisedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'raisedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByRaisedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'raisedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByRaisedUnderCoordination() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'raisedUnderCoordination');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByRequestPurposeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requestPurposeKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByRequestedLocation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requestedLocation',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByStatusKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctBySupersededById({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'supersededById',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByTargetLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, ComplianceRequestRecord, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension ComplianceRequestRecordQueryProperty on QueryBuilder<
    ComplianceRequestRecord, ComplianceRequestRecord, QQueryProperty> {
  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      acknowledgedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      acknowledgedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      acknowledgedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      acknowledgementDueAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgementDueAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations>
      assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      assetTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetTypeKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations>
      attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      becameDueAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'becameDueAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int?, QQueryOperations>
      chargeNoAtEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      complianceDueAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'complianceDueAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      complianceNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'complianceNote');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      compliedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'compliedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      compliedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'compliedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      compliedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'compliedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      conditionRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conditionRef');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      conditionTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conditionTypeKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      confirmNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmNote');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      confirmedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      confirmedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      confirmedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confirmedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      coordinationBasisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coordinationBasis');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations>
      correctionCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'correctionCount');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterConditionOfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterConditionOfId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      counterDecisionAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterDecisionAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterDecisionByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterDecisionByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterDecisionByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterDecisionByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterDecisionNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterDecisionNote');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations>
      counterDepthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterDepth');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      counterProposedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterProposedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterProposedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterProposedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterProposedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterProposedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      counterRevisedDescriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'counterRevisedDescription');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      currentAttemptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentAttemptId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      defermentBasisKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defermentBasisKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      dueMarkedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dueMarkedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      dueMarkedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dueMarkedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      dueMarkedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dueMarkedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations>
      escalationTierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'escalationTier');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      gatesLaneFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gatesLaneFirestoreId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, bool, QQueryOperations>
      isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<ComplianceRequestRecord, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      lastCorrectionAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastCorrectionAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      lastCorrectionByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastCorrectionByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      lastCorrectionByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastCorrectionByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      lastCorrectionReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastCorrectionReason');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      lastEscalatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastEscalatedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      linkedExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedExecutionFirestoreId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      linkedLaneFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedLaneFirestoreId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      linkedMaintenanceFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedMaintenanceFirestoreId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      linkedModuleFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedModuleFirestoreId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      linkedWorkflowIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedWorkflowId');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      operationsResourceKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationsResourceKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      operationsSupportTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationsSupportTypeKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      originLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originLaneKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      priorityKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'priorityKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime?, QQueryOperations>
      raisedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'raisedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      raisedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'raisedByName');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      raisedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'raisedByUid');
    });
  }

  QueryBuilder<ComplianceRequestRecord, bool, QQueryOperations>
      raisedUnderCoordinationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'raisedUnderCoordination');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      requestPurposeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requestPurposeKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      requestedLocationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requestedLocation');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      statusKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String?, QQueryOperations>
      supersededByIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'supersededById');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      targetLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetLaneKey');
    });
  }

  QueryBuilder<ComplianceRequestRecord, String, QQueryOperations>
      titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<ComplianceRequestRecord, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<ComplianceRequestRecord, int, QQueryOperations>
      versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
