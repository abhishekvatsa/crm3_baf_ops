// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_command_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkflowCommandRecordCollection on Isar {
  IsarCollection<WorkflowCommandRecord> get workflowCommandRecords =>
      this.collection();
}

const WorkflowCommandRecordSchema = CollectionSchema(
  name: r'WorkflowCommandRecord',
  id: 8453650901252088456,
  properties: {
    r'aggregateId': PropertySchema(
      id: 0,
      name: r'aggregateId',
      type: IsarType.string,
    ),
    r'attemptCount': PropertySchema(
      id: 1,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'commandId': PropertySchema(
      id: 2,
      name: r'commandId',
      type: IsarType.string,
    ),
    r'commandTypeKey': PropertySchema(
      id: 3,
      name: r'commandTypeKey',
      type: IsarType.string,
    ),
    r'createdLocallyAt': PropertySchema(
      id: 4,
      name: r'createdLocallyAt',
      type: IsarType.dateTime,
    ),
    r'expectedVersion': PropertySchema(
      id: 5,
      name: r'expectedVersion',
      type: IsarType.long,
    ),
    r'lastAttemptAt': PropertySchema(
      id: 6,
      name: r'lastAttemptAt',
      type: IsarType.dateTime,
    ),
    r'lastErrorCode': PropertySchema(
      id: 7,
      name: r'lastErrorCode',
      type: IsarType.string,
    ),
    r'lastErrorMessage': PropertySchema(
      id: 8,
      name: r'lastErrorMessage',
      type: IsarType.string,
    ),
    r'nextRetryAt': PropertySchema(
      id: 9,
      name: r'nextRetryAt',
      type: IsarType.dateTime,
    ),
    r'payloadJson': PropertySchema(
      id: 10,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'receiptJson': PropertySchema(
      id: 11,
      name: r'receiptJson',
      type: IsarType.string,
    ),
    r'stateKey': PropertySchema(
      id: 12,
      name: r'stateKey',
      type: IsarType.string,
    )
  },
  estimateSize: _workflowCommandRecordEstimateSize,
  serialize: _workflowCommandRecordSerialize,
  deserialize: _workflowCommandRecordDeserialize,
  deserializeProp: _workflowCommandRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'commandId': IndexSchema(
      id: -4064098501468219660,
      name: r'commandId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'commandId',
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
    r'commandTypeKey': IndexSchema(
      id: 1173766371450244632,
      name: r'commandTypeKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'commandTypeKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'stateKey': IndexSchema(
      id: 535423888346486579,
      name: r'stateKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'stateKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _workflowCommandRecordGetId,
  getLinks: _workflowCommandRecordGetLinks,
  attach: _workflowCommandRecordAttach,
  version: '3.1.0+1',
);

int _workflowCommandRecordEstimateSize(
  WorkflowCommandRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.aggregateId.length * 3;
  bytesCount += 3 + object.commandId.length * 3;
  bytesCount += 3 + object.commandTypeKey.length * 3;
  {
    final value = object.lastErrorCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastErrorMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.payloadJson.length * 3;
  {
    final value = object.receiptJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.stateKey.length * 3;
  return bytesCount;
}

void _workflowCommandRecordSerialize(
  WorkflowCommandRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.aggregateId);
  writer.writeLong(offsets[1], object.attemptCount);
  writer.writeString(offsets[2], object.commandId);
  writer.writeString(offsets[3], object.commandTypeKey);
  writer.writeDateTime(offsets[4], object.createdLocallyAt);
  writer.writeLong(offsets[5], object.expectedVersion);
  writer.writeDateTime(offsets[6], object.lastAttemptAt);
  writer.writeString(offsets[7], object.lastErrorCode);
  writer.writeString(offsets[8], object.lastErrorMessage);
  writer.writeDateTime(offsets[9], object.nextRetryAt);
  writer.writeString(offsets[10], object.payloadJson);
  writer.writeString(offsets[11], object.receiptJson);
  writer.writeString(offsets[12], object.stateKey);
}

WorkflowCommandRecord _workflowCommandRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkflowCommandRecord();
  object.aggregateId = reader.readString(offsets[0]);
  object.attemptCount = reader.readLong(offsets[1]);
  object.commandId = reader.readString(offsets[2]);
  object.commandTypeKey = reader.readString(offsets[3]);
  object.createdLocallyAt = reader.readDateTime(offsets[4]);
  object.expectedVersion = reader.readLong(offsets[5]);
  object.id = id;
  object.lastAttemptAt = reader.readDateTimeOrNull(offsets[6]);
  object.lastErrorCode = reader.readStringOrNull(offsets[7]);
  object.lastErrorMessage = reader.readStringOrNull(offsets[8]);
  object.nextRetryAt = reader.readDateTimeOrNull(offsets[9]);
  object.payloadJson = reader.readString(offsets[10]);
  object.receiptJson = reader.readStringOrNull(offsets[11]);
  object.stateKey = reader.readString(offsets[12]);
  return object;
}

P _workflowCommandRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workflowCommandRecordGetId(WorkflowCommandRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workflowCommandRecordGetLinks(
    WorkflowCommandRecord object) {
  return [];
}

void _workflowCommandRecordAttach(
    IsarCollection<dynamic> col, Id id, WorkflowCommandRecord object) {
  object.id = id;
}

extension WorkflowCommandRecordByIndex
    on IsarCollection<WorkflowCommandRecord> {
  Future<WorkflowCommandRecord?> getByCommandId(String commandId) {
    return getByIndex(r'commandId', [commandId]);
  }

  WorkflowCommandRecord? getByCommandIdSync(String commandId) {
    return getByIndexSync(r'commandId', [commandId]);
  }

  Future<bool> deleteByCommandId(String commandId) {
    return deleteByIndex(r'commandId', [commandId]);
  }

  bool deleteByCommandIdSync(String commandId) {
    return deleteByIndexSync(r'commandId', [commandId]);
  }

  Future<List<WorkflowCommandRecord?>> getAllByCommandId(
      List<String> commandIdValues) {
    final values = commandIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'commandId', values);
  }

  List<WorkflowCommandRecord?> getAllByCommandIdSync(
      List<String> commandIdValues) {
    final values = commandIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'commandId', values);
  }

  Future<int> deleteAllByCommandId(List<String> commandIdValues) {
    final values = commandIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'commandId', values);
  }

  int deleteAllByCommandIdSync(List<String> commandIdValues) {
    final values = commandIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'commandId', values);
  }

  Future<Id> putByCommandId(WorkflowCommandRecord object) {
    return putByIndex(r'commandId', object);
  }

  Id putByCommandIdSync(WorkflowCommandRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'commandId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCommandId(List<WorkflowCommandRecord> objects) {
    return putAllByIndex(r'commandId', objects);
  }

  List<Id> putAllByCommandIdSync(List<WorkflowCommandRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'commandId', objects, saveLinks: saveLinks);
  }
}

extension WorkflowCommandRecordQueryWhereSort
    on QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QWhere> {
  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WorkflowCommandRecordQueryWhere on QueryBuilder<WorkflowCommandRecord,
    WorkflowCommandRecord, QWhereClause> {
  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      commandIdEqualTo(String commandId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'commandId',
        value: [commandId],
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      commandIdNotEqualTo(String commandId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandId',
              lower: [],
              upper: [commandId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandId',
              lower: [commandId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandId',
              lower: [commandId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandId',
              lower: [],
              upper: [commandId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      aggregateIdEqualTo(String aggregateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'aggregateId',
        value: [aggregateId],
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      commandTypeKeyEqualTo(String commandTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'commandTypeKey',
        value: [commandTypeKey],
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      commandTypeKeyNotEqualTo(String commandTypeKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandTypeKey',
              lower: [],
              upper: [commandTypeKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandTypeKey',
              lower: [commandTypeKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandTypeKey',
              lower: [commandTypeKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'commandTypeKey',
              lower: [],
              upper: [commandTypeKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      stateKeyEqualTo(String stateKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'stateKey',
        value: [stateKey],
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterWhereClause>
      stateKeyNotEqualTo(String stateKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'stateKey',
              lower: [],
              upper: [stateKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'stateKey',
              lower: [stateKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'stateKey',
              lower: [stateKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'stateKey',
              lower: [],
              upper: [stateKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension WorkflowCommandRecordQueryFilter on QueryBuilder<
    WorkflowCommandRecord, WorkflowCommandRecord, QFilterCondition> {
  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdEqualTo(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdGreaterThan(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdLessThan(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdBetween(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdStartsWith(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdEndsWith(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      aggregateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aggregateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      aggregateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aggregateId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> aggregateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdEqualTo(
    String value, {
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdGreaterThan(
    String value, {
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdLessThan(
    String value, {
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdBetween(
    String lower,
    String upper, {
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdStartsWith(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdEndsWith(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      commandIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'commandId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      commandIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'commandId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commandId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'commandId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commandTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'commandTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'commandTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'commandTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'commandTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'commandTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      commandTypeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'commandTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      commandTypeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'commandTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commandTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> commandTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'commandTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> createdLocallyAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdLocallyAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> createdLocallyAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdLocallyAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> createdLocallyAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdLocallyAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> createdLocallyAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdLocallyAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> expectedVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expectedVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> expectedVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expectedVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> expectedVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expectedVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> expectedVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expectedVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastAttemptAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastAttemptAt',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastAttemptAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastAttemptAt',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastAttemptAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastAttemptAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastAttemptAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastAttemptAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastAttemptAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastAttemptAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastAttemptAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastAttemptAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastErrorCode',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastErrorCode',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastErrorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastErrorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastErrorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastErrorCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastErrorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastErrorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      lastErrorCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastErrorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      lastErrorCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastErrorCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastErrorCode',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastErrorCode',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastErrorMessage',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastErrorMessage',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastErrorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastErrorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastErrorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastErrorMessage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastErrorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastErrorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      lastErrorMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastErrorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      lastErrorMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastErrorMessage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastErrorMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> lastErrorMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastErrorMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> nextRetryAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'nextRetryAt',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> nextRetryAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'nextRetryAt',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> nextRetryAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nextRetryAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> nextRetryAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nextRetryAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> nextRetryAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nextRetryAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> nextRetryAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nextRetryAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonEqualTo(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonGreaterThan(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonLessThan(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonBetween(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonStartsWith(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonEndsWith(
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

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payloadJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payloadJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'receiptJson',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'receiptJson',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiptJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'receiptJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'receiptJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'receiptJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'receiptJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'receiptJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      receiptJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'receiptJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      receiptJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'receiptJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiptJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> receiptJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'receiptJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'stateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'stateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      stateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'stateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
          QAfterFilterCondition>
      stateKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'stateKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord,
      QAfterFilterCondition> stateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'stateKey',
        value: '',
      ));
    });
  }
}

extension WorkflowCommandRecordQueryObject on QueryBuilder<
    WorkflowCommandRecord, WorkflowCommandRecord, QFilterCondition> {}

extension WorkflowCommandRecordQueryLinks on QueryBuilder<WorkflowCommandRecord,
    WorkflowCommandRecord, QFilterCondition> {}

extension WorkflowCommandRecordQuerySortBy
    on QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QSortBy> {
  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByCommandId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByCommandIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByCommandTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandTypeKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByCommandTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandTypeKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByCreatedLocallyAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdLocallyAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByCreatedLocallyAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdLocallyAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByExpectedVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expectedVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByExpectedVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expectedVersion', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByLastAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByLastAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByLastErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByLastErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByLastErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByLastErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByNextRetryAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByReceiptJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByReceiptJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      sortByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }
}

extension WorkflowCommandRecordQuerySortThenBy
    on QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QSortThenBy> {
  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByCommandId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByCommandIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByCommandTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandTypeKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByCommandTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandTypeKey', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByCreatedLocallyAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdLocallyAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByCreatedLocallyAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdLocallyAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByExpectedVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expectedVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByExpectedVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expectedVersion', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByLastAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByLastAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByLastErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByLastErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByLastErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByLastErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByNextRetryAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByReceiptJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByReceiptJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QAfterSortBy>
      thenByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }
}

extension WorkflowCommandRecordQueryWhereDistinct
    on QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct> {
  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByAggregateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aggregateId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByCommandId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'commandId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByCommandTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'commandTypeKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByCreatedLocallyAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdLocallyAt');
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByExpectedVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expectedVersion');
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByLastAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAttemptAt');
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByLastErrorCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastErrorCode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByLastErrorMessage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastErrorMessage',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextRetryAt');
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByReceiptJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiptJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandRecord, WorkflowCommandRecord, QDistinct>
      distinctByStateKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateKey', caseSensitive: caseSensitive);
    });
  }
}

extension WorkflowCommandRecordQueryProperty on QueryBuilder<
    WorkflowCommandRecord, WorkflowCommandRecord, QQueryProperty> {
  QueryBuilder<WorkflowCommandRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String, QQueryOperations>
      aggregateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aggregateId');
    });
  }

  QueryBuilder<WorkflowCommandRecord, int, QQueryOperations>
      attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String, QQueryOperations>
      commandIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'commandId');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String, QQueryOperations>
      commandTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'commandTypeKey');
    });
  }

  QueryBuilder<WorkflowCommandRecord, DateTime, QQueryOperations>
      createdLocallyAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdLocallyAt');
    });
  }

  QueryBuilder<WorkflowCommandRecord, int, QQueryOperations>
      expectedVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expectedVersion');
    });
  }

  QueryBuilder<WorkflowCommandRecord, DateTime?, QQueryOperations>
      lastAttemptAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAttemptAt');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String?, QQueryOperations>
      lastErrorCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastErrorCode');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String?, QQueryOperations>
      lastErrorMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastErrorMessage');
    });
  }

  QueryBuilder<WorkflowCommandRecord, DateTime?, QQueryOperations>
      nextRetryAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextRetryAt');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String, QQueryOperations>
      payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String?, QQueryOperations>
      receiptJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiptJson');
    });
  }

  QueryBuilder<WorkflowCommandRecord, String, QQueryOperations>
      stateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateKey');
    });
  }
}
