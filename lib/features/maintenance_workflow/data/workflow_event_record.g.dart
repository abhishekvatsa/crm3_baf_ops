// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_event_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkflowEventRecordCollection on Isar {
  IsarCollection<WorkflowEventRecord> get workflowEventRecords =>
      this.collection();
}

const WorkflowEventRecordSchema = CollectionSchema(
  name: r'WorkflowEventRecord',
  id: 6515852830889447935,
  properties: {
    r'actorName': PropertySchema(
      id: 0,
      name: r'actorName',
      type: IsarType.string,
    ),
    r'actorRolesJson': PropertySchema(
      id: 1,
      name: r'actorRolesJson',
      type: IsarType.string,
    ),
    r'actorUid': PropertySchema(
      id: 2,
      name: r'actorUid',
      type: IsarType.string,
    ),
    r'aggregateId': PropertySchema(
      id: 3,
      name: r'aggregateId',
      type: IsarType.string,
    ),
    r'commandId': PropertySchema(
      id: 4,
      name: r'commandId',
      type: IsarType.string,
    ),
    r'eventTypeKey': PropertySchema(
      id: 5,
      name: r'eventTypeKey',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 6,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(
      id: 7,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'laneKey': PropertySchema(
      id: 8,
      name: r'laneKey',
      type: IsarType.string,
    ),
    r'occurredAt': PropertySchema(
      id: 9,
      name: r'occurredAt',
      type: IsarType.dateTime,
    ),
    r'payloadJson': PropertySchema(
      id: 10,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'representedLaneKey': PropertySchema(
      id: 11,
      name: r'representedLaneKey',
      type: IsarType.string,
    )
  },
  estimateSize: _workflowEventRecordEstimateSize,
  serialize: _workflowEventRecordSerialize,
  deserialize: _workflowEventRecordDeserialize,
  deserializeProp: _workflowEventRecordDeserializeProp,
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
    r'aggregateId': IndexSchema(
      id: -4286146723201826268,
      name: r'aggregateId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'aggregateId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'eventTypeKey': IndexSchema(
      id: -2477441241664942377,
      name: r'eventTypeKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'eventTypeKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'occurredAt': IndexSchema(
      id: 1229694562040044173,
      name: r'occurredAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'occurredAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _workflowEventRecordGetId,
  getLinks: _workflowEventRecordGetLinks,
  attach: _workflowEventRecordAttach,
  version: '3.1.0+1',
);

int _workflowEventRecordEstimateSize(
  WorkflowEventRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.actorName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.actorRolesJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.actorUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.aggregateId.length * 3;
  {
    final value = object.commandId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.eventTypeKey.length * 3;
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.laneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.payloadJson.length * 3;
  {
    final value = object.representedLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _workflowEventRecordSerialize(
  WorkflowEventRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.actorName);
  writer.writeString(offsets[1], object.actorRolesJson);
  writer.writeString(offsets[2], object.actorUid);
  writer.writeString(offsets[3], object.aggregateId);
  writer.writeString(offsets[4], object.commandId);
  writer.writeString(offsets[5], object.eventTypeKey);
  writer.writeString(offsets[6], object.firestoreId);
  writer.writeBool(offsets[7], object.isSynced);
  writer.writeString(offsets[8], object.laneKey);
  writer.writeDateTime(offsets[9], object.occurredAt);
  writer.writeString(offsets[10], object.payloadJson);
  writer.writeString(offsets[11], object.representedLaneKey);
}

WorkflowEventRecord _workflowEventRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkflowEventRecord();
  object.actorName = reader.readStringOrNull(offsets[0]);
  object.actorRolesJson = reader.readStringOrNull(offsets[1]);
  object.actorUid = reader.readStringOrNull(offsets[2]);
  object.aggregateId = reader.readString(offsets[3]);
  object.commandId = reader.readStringOrNull(offsets[4]);
  object.eventTypeKey = reader.readString(offsets[5]);
  object.firestoreId = reader.readStringOrNull(offsets[6]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[7]);
  object.laneKey = reader.readStringOrNull(offsets[8]);
  object.occurredAt = reader.readDateTime(offsets[9]);
  object.payloadJson = reader.readString(offsets[10]);
  object.representedLaneKey = reader.readStringOrNull(offsets[11]);
  return object;
}

P _workflowEventRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workflowEventRecordGetId(WorkflowEventRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workflowEventRecordGetLinks(
    WorkflowEventRecord object) {
  return [];
}

void _workflowEventRecordAttach(
    IsarCollection<dynamic> col, Id id, WorkflowEventRecord object) {
  object.id = id;
}

extension WorkflowEventRecordByIndex on IsarCollection<WorkflowEventRecord> {
  Future<WorkflowEventRecord?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  WorkflowEventRecord? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<WorkflowEventRecord?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<WorkflowEventRecord?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(WorkflowEventRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(WorkflowEventRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<WorkflowEventRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<WorkflowEventRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension WorkflowEventRecordQueryWhereSort
    on QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QWhere> {
  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhere>
      anyOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'occurredAt'),
      );
    });
  }
}

extension WorkflowEventRecordQueryWhere
    on QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QWhereClause> {
  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      aggregateIdEqualTo(String aggregateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'aggregateId',
        value: [aggregateId],
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      aggregateIdNotEqualTo(String aggregateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'aggregateId',
              lower: [],
              upper: [aggregateId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'aggregateId',
              lower: [aggregateId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'aggregateId',
              lower: [aggregateId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'aggregateId',
              lower: [],
              upper: [aggregateId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      eventTypeKeyEqualTo(String eventTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'eventTypeKey',
        value: [eventTypeKey],
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      eventTypeKeyNotEqualTo(String eventTypeKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventTypeKey',
              lower: [],
              upper: [eventTypeKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventTypeKey',
              lower: [eventTypeKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventTypeKey',
              lower: [eventTypeKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eventTypeKey',
              lower: [],
              upper: [eventTypeKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      occurredAtEqualTo(DateTime occurredAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'occurredAt',
        value: [occurredAt],
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      occurredAtNotEqualTo(DateTime occurredAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'occurredAt',
              lower: [],
              upper: [occurredAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'occurredAt',
              lower: [occurredAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'occurredAt',
              lower: [occurredAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'occurredAt',
              lower: [],
              upper: [occurredAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      occurredAtGreaterThan(
    DateTime occurredAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'occurredAt',
        lower: [occurredAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      occurredAtLessThan(
    DateTime occurredAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'occurredAt',
        lower: [],
        upper: [occurredAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterWhereClause>
      occurredAtBetween(
    DateTime lowerOccurredAt,
    DateTime upperOccurredAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'occurredAt',
        lower: [lowerOccurredAt],
        includeLower: includeLower,
        upper: [upperOccurredAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension WorkflowEventRecordQueryFilter on QueryBuilder<WorkflowEventRecord,
    WorkflowEventRecord, QFilterCondition> {
  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'actorName',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'actorName',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actorName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actorName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actorName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorName',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actorName',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'actorRolesJson',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'actorRolesJson',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorRolesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actorRolesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actorRolesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actorRolesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actorRolesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actorRolesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actorRolesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actorRolesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorRolesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorRolesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actorRolesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'actorUid',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'actorUid',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actorUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actorUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actorUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actorUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actorUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actorUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actorUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorUid',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      actorUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actorUid',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aggregateId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aggregateId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      aggregateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'commandId',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'commandId',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'commandId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'commandId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commandId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      commandIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'commandId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eventTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eventTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eventTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eventTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      eventTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eventTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneKey',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneKey',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyEqualTo(
    String? value, {
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyGreaterThan(
    String? value, {
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyLessThan(
    String? value, {
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      laneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      occurredAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'occurredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      occurredAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'occurredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      occurredAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'occurredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      occurredAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'occurredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'payloadJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payloadJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payloadJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      representedLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'representedLaneKey',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      representedLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'representedLaneKey',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
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

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      representedLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'representedLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      representedLaneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'representedLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      representedLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'representedLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterFilterCondition>
      representedLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'representedLaneKey',
        value: '',
      ));
    });
  }
}

extension WorkflowEventRecordQueryObject on QueryBuilder<WorkflowEventRecord,
    WorkflowEventRecord, QFilterCondition> {}

extension WorkflowEventRecordQueryLinks on QueryBuilder<WorkflowEventRecord,
    WorkflowEventRecord, QFilterCondition> {}

extension WorkflowEventRecordQuerySortBy
    on QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QSortBy> {
  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByActorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorName', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByActorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorName', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByActorRolesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorRolesJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByActorRolesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorRolesJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByActorUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByActorUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByCommandId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByCommandIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByEventTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventTypeKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByEventTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventTypeKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByOccurredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByRepresentedLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      sortByRepresentedLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.desc);
    });
  }
}

extension WorkflowEventRecordQuerySortThenBy
    on QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QSortThenBy> {
  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByActorName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorName', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByActorNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorName', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByActorRolesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorRolesJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByActorRolesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorRolesJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByActorUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByActorUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByCommandId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByCommandIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByEventTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventTypeKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByEventTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventTypeKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByOccurredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByRepresentedLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QAfterSortBy>
      thenByRepresentedLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'representedLaneKey', Sort.desc);
    });
  }
}

extension WorkflowEventRecordQueryWhereDistinct
    on QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct> {
  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByActorName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actorName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByActorRolesJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actorRolesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByActorUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actorUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByAggregateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aggregateId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByCommandId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'commandId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByEventTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventTypeKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'occurredAt');
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QDistinct>
      distinctByRepresentedLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'representedLaneKey',
          caseSensitive: caseSensitive);
    });
  }
}

extension WorkflowEventRecordQueryProperty
    on QueryBuilder<WorkflowEventRecord, WorkflowEventRecord, QQueryProperty> {
  QueryBuilder<WorkflowEventRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      actorNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actorName');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      actorRolesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actorRolesJson');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      actorUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actorUid');
    });
  }

  QueryBuilder<WorkflowEventRecord, String, QQueryOperations>
      aggregateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aggregateId');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      commandIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'commandId');
    });
  }

  QueryBuilder<WorkflowEventRecord, String, QQueryOperations>
      eventTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventTypeKey');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<WorkflowEventRecord, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      laneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneKey');
    });
  }

  QueryBuilder<WorkflowEventRecord, DateTime, QQueryOperations>
      occurredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'occurredAt');
    });
  }

  QueryBuilder<WorkflowEventRecord, String, QQueryOperations>
      payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<WorkflowEventRecord, String?, QQueryOperations>
      representedLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'representedLaneKey');
    });
  }
}
