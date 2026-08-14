// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_aggregate_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkflowAggregateRecordCollection on Isar {
  IsarCollection<WorkflowAggregateRecord> get workflowAggregateRecords =>
      this.collection();
}

const WorkflowAggregateRecordSchema = CollectionSchema(
  name: r'WorkflowAggregateRecord',
  id: 6318900776569381757,
  properties: {
    r'activeRedWork': PropertySchema(
      id: 0,
      name: r'activeRedWork',
      type: IsarType.bool,
    ),
    r'assetClassId': PropertySchema(
      id: 1,
      name: r'assetClassId',
      type: IsarType.string,
    ),
    r'assetInstanceId': PropertySchema(
      id: 2,
      name: r'assetInstanceId',
      type: IsarType.string,
    ),
    r'assetNumber': PropertySchema(
      id: 3,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetTypeKey': PropertySchema(
      id: 4,
      name: r'assetTypeKey',
      type: IsarType.string,
    ),
    r'awaitingPreparation': PropertySchema(
      id: 5,
      name: r'awaitingPreparation',
      type: IsarType.bool,
    ),
    r'cancelled': PropertySchema(
      id: 6,
      name: r'cancelled',
      type: IsarType.bool,
    ),
    r'completedAt': PropertySchema(
      id: 7,
      name: r'completedAt',
      type: IsarType.dateTime,
    ),
    r'createdAt': PropertySchema(
      id: 8,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'firestoreId': PropertySchema(
      id: 9,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'jobExecutionFirestoreId': PropertySchema(
      id: 10,
      name: r'jobExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'laneSetFinalizedAt': PropertySchema(
      id: 11,
      name: r'laneSetFinalizedAt',
      type: IsarType.dateTime,
    ),
    r'laneSetFinalizedByName': PropertySchema(
      id: 12,
      name: r'laneSetFinalizedByName',
      type: IsarType.string,
    ),
    r'laneSetFinalizedByUid': PropertySchema(
      id: 13,
      name: r'laneSetFinalizedByUid',
      type: IsarType.string,
    ),
    r'laneSetVersion': PropertySchema(
      id: 14,
      name: r'laneSetVersion',
      type: IsarType.long,
    ),
    r'metadataJson': PropertySchema(
      id: 15,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'statusKey': PropertySchema(
      id: 16,
      name: r'statusKey',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 17,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 18,
      name: r'version',
      type: IsarType.long,
    ),
    r'workflowSchemaVersion': PropertySchema(
      id: 19,
      name: r'workflowSchemaVersion',
      type: IsarType.long,
    )
  },
  estimateSize: _workflowAggregateRecordEstimateSize,
  serialize: _workflowAggregateRecordSerialize,
  deserialize: _workflowAggregateRecordDeserialize,
  deserializeProp: _workflowAggregateRecordDeserializeProp,
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
    ),
    r'assetClassId': IndexSchema(
      id: 8014201351234624830,
      name: r'assetClassId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetClassId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'assetInstanceId': IndexSchema(
      id: -1321462710229363228,
      name: r'assetInstanceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetInstanceId',
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
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _workflowAggregateRecordGetId,
  getLinks: _workflowAggregateRecordGetLinks,
  attach: _workflowAggregateRecordAttach,
  version: '3.1.0+1',
);

int _workflowAggregateRecordEstimateSize(
  WorkflowAggregateRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.assetClassId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.assetInstanceId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.assetTypeKey.length * 3;
  bytesCount += 3 + object.firestoreId.length * 3;
  bytesCount += 3 + object.jobExecutionFirestoreId.length * 3;
  {
    final value = object.laneSetFinalizedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.laneSetFinalizedByUid;
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
  bytesCount += 3 + object.statusKey.length * 3;
  return bytesCount;
}

void _workflowAggregateRecordSerialize(
  WorkflowAggregateRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.activeRedWork);
  writer.writeString(offsets[1], object.assetClassId);
  writer.writeString(offsets[2], object.assetInstanceId);
  writer.writeLong(offsets[3], object.assetNumber);
  writer.writeString(offsets[4], object.assetTypeKey);
  writer.writeBool(offsets[5], object.awaitingPreparation);
  writer.writeBool(offsets[6], object.cancelled);
  writer.writeDateTime(offsets[7], object.completedAt);
  writer.writeDateTime(offsets[8], object.createdAt);
  writer.writeString(offsets[9], object.firestoreId);
  writer.writeString(offsets[10], object.jobExecutionFirestoreId);
  writer.writeDateTime(offsets[11], object.laneSetFinalizedAt);
  writer.writeString(offsets[12], object.laneSetFinalizedByName);
  writer.writeString(offsets[13], object.laneSetFinalizedByUid);
  writer.writeLong(offsets[14], object.laneSetVersion);
  writer.writeString(offsets[15], object.metadataJson);
  writer.writeString(offsets[16], object.statusKey);
  writer.writeDateTime(offsets[17], object.updatedAt);
  writer.writeLong(offsets[18], object.version);
  writer.writeLong(offsets[19], object.workflowSchemaVersion);
}

WorkflowAggregateRecord _workflowAggregateRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkflowAggregateRecord();
  object.activeRedWork = reader.readBool(offsets[0]);
  object.assetClassId = reader.readStringOrNull(offsets[1]);
  object.assetInstanceId = reader.readStringOrNull(offsets[2]);
  object.assetNumber = reader.readLong(offsets[3]);
  object.assetTypeKey = reader.readString(offsets[4]);
  object.awaitingPreparation = reader.readBool(offsets[5]);
  object.cancelled = reader.readBool(offsets[6]);
  object.completedAt = reader.readDateTimeOrNull(offsets[7]);
  object.createdAt = reader.readDateTime(offsets[8]);
  object.firestoreId = reader.readString(offsets[9]);
  object.id = id;
  object.jobExecutionFirestoreId = reader.readString(offsets[10]);
  object.laneSetFinalizedAt = reader.readDateTimeOrNull(offsets[11]);
  object.laneSetFinalizedByName = reader.readStringOrNull(offsets[12]);
  object.laneSetFinalizedByUid = reader.readStringOrNull(offsets[13]);
  object.laneSetVersion = reader.readLong(offsets[14]);
  object.metadataJson = reader.readStringOrNull(offsets[15]);
  object.statusKey = reader.readString(offsets[16]);
  object.updatedAt = reader.readDateTime(offsets[17]);
  object.version = reader.readLong(offsets[18]);
  object.workflowSchemaVersion = reader.readLong(offsets[19]);
  return object;
}

P _workflowAggregateRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readDateTime(offset)) as P;
    case 18:
      return (reader.readLong(offset)) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workflowAggregateRecordGetId(WorkflowAggregateRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workflowAggregateRecordGetLinks(
    WorkflowAggregateRecord object) {
  return [];
}

void _workflowAggregateRecordAttach(
    IsarCollection<dynamic> col, Id id, WorkflowAggregateRecord object) {
  object.id = id;
}

extension WorkflowAggregateRecordByIndex
    on IsarCollection<WorkflowAggregateRecord> {
  Future<WorkflowAggregateRecord?> getByFirestoreId(String firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  WorkflowAggregateRecord? getByFirestoreIdSync(String firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<WorkflowAggregateRecord?>> getAllByFirestoreId(
      List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<WorkflowAggregateRecord?> getAllByFirestoreIdSync(
      List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'firestoreId', values);
  }

  Future<int> deleteAllByFirestoreId(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'firestoreId', values);
  }

  int deleteAllByFirestoreIdSync(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'firestoreId', values);
  }

  Future<Id> putByFirestoreId(WorkflowAggregateRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(WorkflowAggregateRecord object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<WorkflowAggregateRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<WorkflowAggregateRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension WorkflowAggregateRecordQueryWhereSort
    on QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QWhere> {
  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterWhere>
      anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }
}

extension WorkflowAggregateRecordQueryWhere on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QWhereClause> {
  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> firestoreIdEqualTo(String firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> firestoreIdNotEqualTo(String firestoreId) {
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterWhereClause>
      jobExecutionFirestoreIdEqualTo(String jobExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionFirestoreId',
        value: [jobExecutionFirestoreId],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterWhereClause>
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetTypeKeyEqualTo(String assetTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetTypeKey',
        value: [assetTypeKey],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetClassIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetClassId',
        value: [null],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetClassIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetClassId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetClassIdEqualTo(String? assetClassId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetClassId',
        value: [assetClassId],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetClassIdNotEqualTo(String? assetClassId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetClassId',
              lower: [],
              upper: [assetClassId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetClassId',
              lower: [assetClassId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetClassId',
              lower: [assetClassId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetClassId',
              lower: [],
              upper: [assetClassId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetInstanceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetInstanceId',
        value: [null],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetInstanceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetInstanceId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetInstanceIdEqualTo(String? assetInstanceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetInstanceId',
        value: [assetInstanceId],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> assetInstanceIdNotEqualTo(String? assetInstanceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetInstanceId',
              lower: [],
              upper: [assetInstanceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetInstanceId',
              lower: [assetInstanceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetInstanceId',
              lower: [assetInstanceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetInstanceId',
              lower: [],
              upper: [assetInstanceId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterWhereClause> statusKeyEqualTo(String statusKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'statusKey',
        value: [statusKey],
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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
}

extension WorkflowAggregateRecordQueryFilter on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QFilterCondition> {
  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> activeRedWorkEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeRedWork',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetClassId',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetClassId',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetClassId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetClassId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetClassId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetClassId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetClassId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetClassId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      assetClassIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetClassId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      assetClassIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetClassId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetClassId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetClassIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetClassId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetInstanceId',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetInstanceId',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetInstanceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetInstanceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetInstanceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetInstanceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetInstanceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetInstanceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      assetInstanceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetInstanceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      assetInstanceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetInstanceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetInstanceId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetInstanceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetInstanceId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> assetTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> awaitingPreparationEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'awaitingPreparation',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> cancelledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancelled',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> completedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedAt',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> completedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedAt',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> completedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> completedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> completedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> completedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> firestoreIdEqualTo(
    String value, {
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> firestoreIdGreaterThan(
    String value, {
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> firestoreIdLessThan(
    String value, {
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> firestoreIdBetween(
    String lower,
    String upper, {
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdEqualTo(
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdGreaterThan(
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdLessThan(
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdBetween(
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdStartsWith(
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdEndsWith(
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> jobExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneSetFinalizedAt',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneSetFinalizedAt',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetFinalizedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetFinalizedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetFinalizedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneSetFinalizedByName',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneSetFinalizedByName',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetFinalizedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      laneSetFinalizedByNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      laneSetFinalizedByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneSetFinalizedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneSetFinalizedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneSetFinalizedByUid',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneSetFinalizedByUid',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetFinalizedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      laneSetFinalizedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
          QAfterFilterCondition>
      laneSetFinalizedByUidMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneSetFinalizedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetFinalizedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneSetFinalizedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> laneSetVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> statusKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'statusKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> statusKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'statusKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
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

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> workflowSchemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> workflowSchemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> workflowSchemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord,
      QAfterFilterCondition> workflowSchemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowSchemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension WorkflowAggregateRecordQueryObject on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QFilterCondition> {}

extension WorkflowAggregateRecordQueryLinks on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QFilterCondition> {}

extension WorkflowAggregateRecordQuerySortBy
    on QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QSortBy> {
  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByActiveRedWork() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeRedWork', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByActiveRedWorkDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeRedWork', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetClassId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetClassIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetInstanceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetInstanceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAwaitingPreparation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparation', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByAwaitingPreparationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparation', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelled', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByCancelledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelled', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetFinalizedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetFinalizedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetFinalizedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetFinalizedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetFinalizedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetFinalizedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByLaneSetVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByStatusKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByStatusKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByWorkflowSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      sortByWorkflowSchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.desc);
    });
  }
}

extension WorkflowAggregateRecordQuerySortThenBy on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QSortThenBy> {
  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByActiveRedWork() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeRedWork', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByActiveRedWorkDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeRedWork', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetClassId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetClassIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetInstanceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetInstanceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAwaitingPreparation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparation', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByAwaitingPreparationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparation', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelled', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByCancelledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelled', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetFinalizedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetFinalizedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetFinalizedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetFinalizedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetFinalizedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetFinalizedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByLaneSetVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByStatusKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByStatusKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByWorkflowSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QAfterSortBy>
      thenByWorkflowSchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.desc);
    });
  }
}

extension WorkflowAggregateRecordQueryWhereDistinct on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct> {
  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByActiveRedWork() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activeRedWork');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByAssetClassId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetClassId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByAssetInstanceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetInstanceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByAssetTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetTypeKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByAwaitingPreparation() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'awaitingPreparation');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cancelled');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByJobExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByLaneSetFinalizedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalizedAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByLaneSetFinalizedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalizedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByLaneSetFinalizedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalizedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByLaneSetVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetVersion');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByStatusKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, WorkflowAggregateRecord, QDistinct>
      distinctByWorkflowSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowSchemaVersion');
    });
  }
}

extension WorkflowAggregateRecordQueryProperty on QueryBuilder<
    WorkflowAggregateRecord, WorkflowAggregateRecord, QQueryProperty> {
  QueryBuilder<WorkflowAggregateRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, bool, QQueryOperations>
      activeRedWorkProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activeRedWork');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String?, QQueryOperations>
      assetClassIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetClassId');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String?, QQueryOperations>
      assetInstanceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetInstanceId');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, int, QQueryOperations>
      assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String, QQueryOperations>
      assetTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetTypeKey');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, bool, QQueryOperations>
      awaitingPreparationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'awaitingPreparation');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, bool, QQueryOperations>
      cancelledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cancelled');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, DateTime?, QQueryOperations>
      completedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String, QQueryOperations>
      jobExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionFirestoreId');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, DateTime?, QQueryOperations>
      laneSetFinalizedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalizedAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String?, QQueryOperations>
      laneSetFinalizedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalizedByName');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String?, QQueryOperations>
      laneSetFinalizedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalizedByUid');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, int, QQueryOperations>
      laneSetVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetVersion');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, String, QQueryOperations>
      statusKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusKey');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, int, QQueryOperations>
      versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<WorkflowAggregateRecord, int, QQueryOperations>
      workflowSchemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowSchemaVersion');
    });
  }
}
