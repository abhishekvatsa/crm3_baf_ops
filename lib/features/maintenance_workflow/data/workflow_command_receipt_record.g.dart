// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_command_receipt_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkflowCommandReceiptRecordCollection on Isar {
  IsarCollection<WorkflowCommandReceiptRecord>
      get workflowCommandReceiptRecords => this.collection();
}

const WorkflowCommandReceiptRecordSchema = CollectionSchema(
  name: r'WorkflowCommandReceiptRecord',
  id: 961740083596463899,
  properties: {
    r'aggregateId': PropertySchema(
      id: 0,
      name: r'aggregateId',
      type: IsarType.string,
    ),
    r'aggregateVersion': PropertySchema(
      id: 1,
      name: r'aggregateVersion',
      type: IsarType.long,
    ),
    r'appliedAt': PropertySchema(
      id: 2,
      name: r'appliedAt',
      type: IsarType.dateTime,
    ),
    r'commandId': PropertySchema(
      id: 3,
      name: r'commandId',
      type: IsarType.string,
    ),
    r'resultJson': PropertySchema(
      id: 4,
      name: r'resultJson',
      type: IsarType.string,
    ),
    r'resultKey': PropertySchema(
      id: 5,
      name: r'resultKey',
      type: IsarType.string,
    )
  },
  estimateSize: _workflowCommandReceiptRecordEstimateSize,
  serialize: _workflowCommandReceiptRecordSerialize,
  deserialize: _workflowCommandReceiptRecordDeserialize,
  deserializeProp: _workflowCommandReceiptRecordDeserializeProp,
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
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _workflowCommandReceiptRecordGetId,
  getLinks: _workflowCommandReceiptRecordGetLinks,
  attach: _workflowCommandReceiptRecordAttach,
  version: '3.1.0+1',
);

int _workflowCommandReceiptRecordEstimateSize(
  WorkflowCommandReceiptRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.aggregateId.length * 3;
  bytesCount += 3 + object.commandId.length * 3;
  bytesCount += 3 + object.resultJson.length * 3;
  bytesCount += 3 + object.resultKey.length * 3;
  return bytesCount;
}

void _workflowCommandReceiptRecordSerialize(
  WorkflowCommandReceiptRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.aggregateId);
  writer.writeLong(offsets[1], object.aggregateVersion);
  writer.writeDateTime(offsets[2], object.appliedAt);
  writer.writeString(offsets[3], object.commandId);
  writer.writeString(offsets[4], object.resultJson);
  writer.writeString(offsets[5], object.resultKey);
}

WorkflowCommandReceiptRecord _workflowCommandReceiptRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkflowCommandReceiptRecord();
  object.aggregateId = reader.readString(offsets[0]);
  object.aggregateVersion = reader.readLong(offsets[1]);
  object.appliedAt = reader.readDateTime(offsets[2]);
  object.commandId = reader.readString(offsets[3]);
  object.id = id;
  object.resultJson = reader.readString(offsets[4]);
  object.resultKey = reader.readString(offsets[5]);
  return object;
}

P _workflowCommandReceiptRecordDeserializeProp<P>(
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
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workflowCommandReceiptRecordGetId(WorkflowCommandReceiptRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workflowCommandReceiptRecordGetLinks(
    WorkflowCommandReceiptRecord object) {
  return [];
}

void _workflowCommandReceiptRecordAttach(
    IsarCollection<dynamic> col, Id id, WorkflowCommandReceiptRecord object) {
  object.id = id;
}

extension WorkflowCommandReceiptRecordByIndex
    on IsarCollection<WorkflowCommandReceiptRecord> {
  Future<WorkflowCommandReceiptRecord?> getByCommandId(String commandId) {
    return getByIndex(r'commandId', [commandId]);
  }

  WorkflowCommandReceiptRecord? getByCommandIdSync(String commandId) {
    return getByIndexSync(r'commandId', [commandId]);
  }

  Future<bool> deleteByCommandId(String commandId) {
    return deleteByIndex(r'commandId', [commandId]);
  }

  bool deleteByCommandIdSync(String commandId) {
    return deleteByIndexSync(r'commandId', [commandId]);
  }

  Future<List<WorkflowCommandReceiptRecord?>> getAllByCommandId(
      List<String> commandIdValues) {
    final values = commandIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'commandId', values);
  }

  List<WorkflowCommandReceiptRecord?> getAllByCommandIdSync(
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

  Future<Id> putByCommandId(WorkflowCommandReceiptRecord object) {
    return putByIndex(r'commandId', object);
  }

  Id putByCommandIdSync(WorkflowCommandReceiptRecord object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'commandId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCommandId(
      List<WorkflowCommandReceiptRecord> objects) {
    return putAllByIndex(r'commandId', objects);
  }

  List<Id> putAllByCommandIdSync(List<WorkflowCommandReceiptRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'commandId', objects, saveLinks: saveLinks);
  }
}

extension WorkflowCommandReceiptRecordQueryWhereSort on QueryBuilder<
    WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord, QWhere> {
  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WorkflowCommandReceiptRecordQueryWhere on QueryBuilder<
    WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord, QWhereClause> {
  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> commandIdEqualTo(String commandId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'commandId',
        value: [commandId],
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> commandIdNotEqualTo(String commandId) {
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> aggregateIdEqualTo(String aggregateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'aggregateId',
        value: [aggregateId],
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterWhereClause> aggregateIdNotEqualTo(String aggregateId) {
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
}

extension WorkflowCommandReceiptRecordQueryFilter on QueryBuilder<
    WorkflowCommandReceiptRecord,
    WorkflowCommandReceiptRecord,
    QFilterCondition> {
  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> aggregateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> aggregateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aggregateId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> aggregateVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aggregateVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> aggregateVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aggregateVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> aggregateVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aggregateVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> aggregateVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aggregateVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> appliedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> appliedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> appliedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> appliedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appliedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> commandIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'commandId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> commandIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'commandId',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
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

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resultJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resultJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resultJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resultJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resultJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resultJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
          QAfterFilterCondition>
      resultJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resultJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
          QAfterFilterCondition>
      resultJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resultJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resultJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resultJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resultKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resultKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resultKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resultKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resultKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resultKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
          QAfterFilterCondition>
      resultKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resultKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
          QAfterFilterCondition>
      resultKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resultKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resultKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterFilterCondition> resultKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resultKey',
        value: '',
      ));
    });
  }
}

extension WorkflowCommandReceiptRecordQueryObject on QueryBuilder<
    WorkflowCommandReceiptRecord,
    WorkflowCommandReceiptRecord,
    QFilterCondition> {}

extension WorkflowCommandReceiptRecordQueryLinks on QueryBuilder<
    WorkflowCommandReceiptRecord,
    WorkflowCommandReceiptRecord,
    QFilterCondition> {}

extension WorkflowCommandReceiptRecordQuerySortBy on QueryBuilder<
    WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord, QSortBy> {
  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByAggregateVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByAggregateVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateVersion', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByCommandId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByCommandIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByResultJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByResultJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByResultKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> sortByResultKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultKey', Sort.desc);
    });
  }
}

extension WorkflowCommandReceiptRecordQuerySortThenBy on QueryBuilder<
    WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord, QSortThenBy> {
  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByAggregateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByAggregateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByAggregateVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateVersion', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByAggregateVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aggregateVersion', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByCommandId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByCommandIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'commandId', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByResultJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultJson', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByResultJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultJson', Sort.desc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByResultKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultKey', Sort.asc);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QAfterSortBy> thenByResultKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resultKey', Sort.desc);
    });
  }
}

extension WorkflowCommandReceiptRecordQueryWhereDistinct on QueryBuilder<
    WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord, QDistinct> {
  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QDistinct> distinctByAggregateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aggregateId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QDistinct> distinctByAggregateVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aggregateVersion');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QDistinct> distinctByAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appliedAt');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QDistinct> distinctByCommandId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'commandId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QDistinct> distinctByResultJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resultJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, WorkflowCommandReceiptRecord,
      QDistinct> distinctByResultKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resultKey', caseSensitive: caseSensitive);
    });
  }
}

extension WorkflowCommandReceiptRecordQueryProperty on QueryBuilder<
    WorkflowCommandReceiptRecord,
    WorkflowCommandReceiptRecord,
    QQueryProperty> {
  QueryBuilder<WorkflowCommandReceiptRecord, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, String, QQueryOperations>
      aggregateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aggregateId');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, int, QQueryOperations>
      aggregateVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aggregateVersion');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, DateTime, QQueryOperations>
      appliedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appliedAt');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, String, QQueryOperations>
      commandIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'commandId');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, String, QQueryOperations>
      resultJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resultJson');
    });
  }

  QueryBuilder<WorkflowCommandReceiptRecord, String, QQueryOperations>
      resultKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resultKey');
    });
  }
}
