// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_event_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAuditEventCollection on Isar {
  IsarCollection<AuditEvent> get auditEvents => this.collection();
}

const AuditEventSchema = CollectionSchema(
  name: r'AuditEvent',
  id: -228283108298215510,
  properties: {
    r'action': PropertySchema(
      id: 0,
      name: r'action',
      type: IsarType.string,
      enumMap: _AuditEventactionEnumValueMap,
    ),
    r'afterJson': PropertySchema(
      id: 1,
      name: r'afterJson',
      type: IsarType.string,
    ),
    r'beforeJson': PropertySchema(
      id: 2,
      name: r'beforeJson',
      type: IsarType.string,
    ),
    r'entityId': PropertySchema(
      id: 3,
      name: r'entityId',
      type: IsarType.string,
    ),
    r'entityType': PropertySchema(
      id: 4,
      name: r'entityType',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(
      id: 5,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'performedByName': PropertySchema(
      id: 6,
      name: r'performedByName',
      type: IsarType.string,
    ),
    r'performedByUid': PropertySchema(
      id: 7,
      name: r'performedByUid',
      type: IsarType.string,
    ),
    r'reason': PropertySchema(
      id: 8,
      name: r'reason',
      type: IsarType.string,
      enumMap: _AuditEventreasonEnumValueMap,
    ),
    r'reasonNotes': PropertySchema(
      id: 9,
      name: r'reasonNotes',
      type: IsarType.string,
    ),
    r'severity': PropertySchema(
      id: 10,
      name: r'severity',
      type: IsarType.string,
      enumMap: _AuditEventseverityEnumValueMap,
    ),
    r'summary': PropertySchema(
      id: 11,
      name: r'summary',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 12,
      name: r'timestamp',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _auditEventEstimateSize,
  serialize: _auditEventSerialize,
  deserialize: _auditEventDeserialize,
  deserializeProp: _auditEventDeserializeProp,
  idName: r'id',
  indexes: {
    r'entityType': IndexSchema(
      id: -5109706325448941117,
      name: r'entityType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'entityType',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'entityId': IndexSchema(
      id: 745355021660786263,
      name: r'entityId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'entityId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'performedByUid': IndexSchema(
      id: 8878460126732729237,
      name: r'performedByUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'performedByUid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _auditEventGetId,
  getLinks: _auditEventGetLinks,
  attach: _auditEventAttach,
  version: '3.1.0+1',
);

int _auditEventEstimateSize(
  AuditEvent object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.action.name.length * 3;
  {
    final value = object.afterJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.beforeJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.entityId.length * 3;
  bytesCount += 3 + object.entityType.length * 3;
  {
    final value = object.performedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.performedByUid.length * 3;
  {
    final value = object.reason;
    if (value != null) {
      bytesCount += 3 + value.name.length * 3;
    }
  }
  {
    final value = object.reasonNotes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.severity.name.length * 3;
  {
    final value = object.summary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _auditEventSerialize(
  AuditEvent object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.action.name);
  writer.writeString(offsets[1], object.afterJson);
  writer.writeString(offsets[2], object.beforeJson);
  writer.writeString(offsets[3], object.entityId);
  writer.writeString(offsets[4], object.entityType);
  writer.writeBool(offsets[5], object.isSynced);
  writer.writeString(offsets[6], object.performedByName);
  writer.writeString(offsets[7], object.performedByUid);
  writer.writeString(offsets[8], object.reason?.name);
  writer.writeString(offsets[9], object.reasonNotes);
  writer.writeString(offsets[10], object.severity.name);
  writer.writeString(offsets[11], object.summary);
  writer.writeDateTime(offsets[12], object.timestamp);
}

AuditEvent _auditEventDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AuditEvent(
    action:
        _AuditEventactionValueEnumMap[reader.readStringOrNull(offsets[0])] ??
            AuditAction.create,
    entityId: reader.readString(offsets[3]),
    entityType: reader.readString(offsets[4]),
    performedByName: reader.readStringOrNull(offsets[6]),
    performedByUid: reader.readString(offsets[7]),
    reason: _AuditEventreasonValueEnumMap[reader.readStringOrNull(offsets[8])],
    reasonNotes: reader.readStringOrNull(offsets[9]),
    severity:
        _AuditEventseverityValueEnumMap[reader.readStringOrNull(offsets[10])] ??
            AuditSeverity.low,
    summary: reader.readStringOrNull(offsets[11]),
  );
  object.afterJson = reader.readStringOrNull(offsets[1]);
  object.beforeJson = reader.readStringOrNull(offsets[2]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[5]);
  object.timestamp = reader.readDateTime(offsets[12]);
  return object;
}

P _auditEventDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (_AuditEventactionValueEnumMap[reader.readStringOrNull(offset)] ??
          AuditAction.create) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (_AuditEventreasonValueEnumMap[reader.readStringOrNull(offset)])
          as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (_AuditEventseverityValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AuditSeverity.low) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _AuditEventactionEnumValueMap = {
  r'create': r'create',
  r'update': r'update',
  r'resolve': r'resolve',
  r'reopen': r'reopen',
  r'delete': r'delete',
};
const _AuditEventactionValueEnumMap = {
  r'create': AuditAction.create,
  r'update': AuditAction.update,
  r'resolve': AuditAction.resolve,
  r'reopen': AuditAction.reopen,
  r'delete': AuditAction.delete,
};
const _AuditEventreasonEnumValueMap = {
  r'duplicate': r'duplicate',
  r'incorrectEntry': r'incorrectEntry',
  r'merged': r'merged',
  r'invalid': r'invalid',
  r'manualOverride': r'manualOverride',
  r'other': r'other',
};
const _AuditEventreasonValueEnumMap = {
  r'duplicate': AuditReason.duplicate,
  r'incorrectEntry': AuditReason.incorrectEntry,
  r'merged': AuditReason.merged,
  r'invalid': AuditReason.invalid,
  r'manualOverride': AuditReason.manualOverride,
  r'other': AuditReason.other,
};
const _AuditEventseverityEnumValueMap = {
  r'low': r'low',
  r'medium': r'medium',
  r'high': r'high',
};
const _AuditEventseverityValueEnumMap = {
  r'low': AuditSeverity.low,
  r'medium': AuditSeverity.medium,
  r'high': AuditSeverity.high,
};

Id _auditEventGetId(AuditEvent object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _auditEventGetLinks(AuditEvent object) {
  return [];
}

void _auditEventAttach(IsarCollection<dynamic> col, Id id, AuditEvent object) {
  object.id = id;
}

extension AuditEventQueryWhereSort
    on QueryBuilder<AuditEvent, AuditEvent, QWhere> {
  QueryBuilder<AuditEvent, AuditEvent, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension AuditEventQueryWhere
    on QueryBuilder<AuditEvent, AuditEvent, QWhereClause> {
  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> idBetween(
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

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> entityTypeEqualTo(
      String entityType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entityType',
        value: [entityType],
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> entityTypeNotEqualTo(
      String entityType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [],
              upper: [entityType],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [entityType],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [entityType],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [],
              upper: [entityType],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> entityIdEqualTo(
      String entityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entityId',
        value: [entityId],
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> entityIdNotEqualTo(
      String entityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [],
              upper: [entityId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [entityId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [entityId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [],
              upper: [entityId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> performedByUidEqualTo(
      String performedByUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'performedByUid',
        value: [performedByUid],
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause>
      performedByUidNotEqualTo(String performedByUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedByUid',
              lower: [],
              upper: [performedByUid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedByUid',
              lower: [performedByUid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedByUid',
              lower: [performedByUid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedByUid',
              lower: [],
              upper: [performedByUid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> timestampEqualTo(
      DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'timestamp',
        value: [timestamp],
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> timestampNotEqualTo(
      DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> timestampGreaterThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [timestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> timestampLessThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [],
        upper: [timestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterWhereClause> timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [lowerTimestamp],
        includeLower: includeLower,
        upper: [upperTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AuditEventQueryFilter
    on QueryBuilder<AuditEvent, AuditEvent, QFilterCondition> {
  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionEqualTo(
    AuditAction value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionGreaterThan(
    AuditAction value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionLessThan(
    AuditAction value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionBetween(
    AuditAction lower,
    AuditAction upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'action',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'action',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> actionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'action',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      actionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'action',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      afterJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'afterJson',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      afterJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'afterJson',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> afterJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'afterJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      afterJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'afterJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> afterJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'afterJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> afterJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'afterJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      afterJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'afterJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> afterJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'afterJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> afterJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'afterJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> afterJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'afterJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      afterJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'afterJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      afterJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'afterJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'beforeJson',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'beforeJson',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> beforeJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'beforeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'beforeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'beforeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> beforeJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'beforeJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'beforeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'beforeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'beforeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> beforeJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'beforeJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'beforeJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      beforeJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'beforeJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entityId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entityId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityId',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entityId',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entityType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> entityTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entityType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityType',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      entityTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entityType',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> idBetween(
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

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> isSyncedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'performedByName',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'performedByName',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'performedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'performedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'performedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'performedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'performedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      performedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'performedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reason',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reason',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonEqualTo(
    AuditReason? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonGreaterThan(
    AuditReason? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonLessThan(
    AuditReason? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonBetween(
    AuditReason? lower,
    AuditReason? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> reasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reasonNotes',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reasonNotes',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reasonNotes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reasonNotes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reasonNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      reasonNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reasonNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> severityEqualTo(
    AuditSeverity value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      severityGreaterThan(
    AuditSeverity value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> severityLessThan(
    AuditSeverity value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> severityBetween(
    AuditSeverity lower,
    AuditSeverity upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'severity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      severityStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> severityEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> severityContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> severityMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'severity',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      severityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'severity',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      severityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'severity',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'summary',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      summaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'summary',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      summaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'summary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'summary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> summaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      summaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> timestampEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterFilterCondition> timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AuditEventQueryObject
    on QueryBuilder<AuditEvent, AuditEvent, QFilterCondition> {}

extension AuditEventQueryLinks
    on QueryBuilder<AuditEvent, AuditEvent, QFilterCondition> {}

extension AuditEventQuerySortBy
    on QueryBuilder<AuditEvent, AuditEvent, QSortBy> {
  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByAfterJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterJson', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByAfterJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterJson', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByBeforeJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeJson', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByBeforeJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeJson', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByEntityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByEntityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByEntityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByEntityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByPerformedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy>
      sortByPerformedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByPerformedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy>
      sortByPerformedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByReasonNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reasonNotes', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByReasonNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reasonNotes', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension AuditEventQuerySortThenBy
    on QueryBuilder<AuditEvent, AuditEvent, QSortThenBy> {
  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByAfterJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterJson', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByAfterJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterJson', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByBeforeJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeJson', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByBeforeJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeJson', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByEntityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByEntityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByEntityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByEntityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByPerformedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy>
      thenByPerformedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByPerformedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy>
      thenByPerformedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByReasonNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reasonNotes', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByReasonNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reasonNotes', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension AuditEventQueryWhereDistinct
    on QueryBuilder<AuditEvent, AuditEvent, QDistinct> {
  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByAction(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'action', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByAfterJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'afterJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByBeforeJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'beforeJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByEntityId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByEntityType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entityType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByPerformedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'performedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByPerformedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'performedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByReasonNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reasonNotes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctBySeverity(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'severity', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctBySummary(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summary', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AuditEvent, AuditEvent, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension AuditEventQueryProperty
    on QueryBuilder<AuditEvent, AuditEvent, QQueryProperty> {
  QueryBuilder<AuditEvent, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AuditEvent, AuditAction, QQueryOperations> actionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'action');
    });
  }

  QueryBuilder<AuditEvent, String?, QQueryOperations> afterJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'afterJson');
    });
  }

  QueryBuilder<AuditEvent, String?, QQueryOperations> beforeJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'beforeJson');
    });
  }

  QueryBuilder<AuditEvent, String, QQueryOperations> entityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entityId');
    });
  }

  QueryBuilder<AuditEvent, String, QQueryOperations> entityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entityType');
    });
  }

  QueryBuilder<AuditEvent, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<AuditEvent, String?, QQueryOperations>
      performedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'performedByName');
    });
  }

  QueryBuilder<AuditEvent, String, QQueryOperations> performedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'performedByUid');
    });
  }

  QueryBuilder<AuditEvent, AuditReason?, QQueryOperations> reasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reason');
    });
  }

  QueryBuilder<AuditEvent, String?, QQueryOperations> reasonNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reasonNotes');
    });
  }

  QueryBuilder<AuditEvent, AuditSeverity, QQueryOperations> severityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'severity');
    });
  }

  QueryBuilder<AuditEvent, String?, QQueryOperations> summaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summary');
    });
  }

  QueryBuilder<AuditEvent, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSyncRejectionCollection on Isar {
  IsarCollection<SyncRejection> get syncRejections => this.collection();
}

const SyncRejectionSchema = CollectionSchema(
  name: r'SyncRejection',
  id: -7653774813178690174,
  properties: {
    r'attemptCount': PropertySchema(
      id: 0,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'entityId': PropertySchema(
      id: 1,
      name: r'entityId',
      type: IsarType.string,
    ),
    r'entityType': PropertySchema(
      id: 2,
      name: r'entityType',
      type: IsarType.string,
    ),
    r'errorCode': PropertySchema(
      id: 3,
      name: r'errorCode',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 4,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'firstSeenAt': PropertySchema(
      id: 5,
      name: r'firstSeenAt',
      type: IsarType.dateTime,
    ),
    r'isLikelyPermanent': PropertySchema(
      id: 6,
      name: r'isLikelyPermanent',
      type: IsarType.bool,
    ),
    r'isResolved': PropertySchema(
      id: 7,
      name: r'isResolved',
      type: IsarType.bool,
    ),
    r'lastSeenAt': PropertySchema(
      id: 8,
      name: r'lastSeenAt',
      type: IsarType.dateTime,
    ),
    r'message': PropertySchema(
      id: 9,
      name: r'message',
      type: IsarType.string,
    ),
    r'originatingUid': PropertySchema(
      id: 10,
      name: r'originatingUid',
      type: IsarType.string,
    ),
    r'resolutionNotes': PropertySchema(
      id: 11,
      name: r'resolutionNotes',
      type: IsarType.string,
    ),
    r'resolvedAt': PropertySchema(
      id: 12,
      name: r'resolvedAt',
      type: IsarType.dateTime,
    ),
    r'resolvedByName': PropertySchema(
      id: 13,
      name: r'resolvedByName',
      type: IsarType.string,
    ),
    r'resolvedByUid': PropertySchema(
      id: 14,
      name: r'resolvedByUid',
      type: IsarType.string,
    )
  },
  estimateSize: _syncRejectionEstimateSize,
  serialize: _syncRejectionSerialize,
  deserialize: _syncRejectionDeserialize,
  deserializeProp: _syncRejectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'entityType': IndexSchema(
      id: -5109706325448941117,
      name: r'entityType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'entityType',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'entityId': IndexSchema(
      id: 745355021660786263,
      name: r'entityId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'entityId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'originatingUid': IndexSchema(
      id: 1416198761860305116,
      name: r'originatingUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'originatingUid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'firstSeenAt': IndexSchema(
      id: -786460824994226473,
      name: r'firstSeenAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'firstSeenAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'lastSeenAt': IndexSchema(
      id: 2370550265182114383,
      name: r'lastSeenAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lastSeenAt',
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
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _syncRejectionGetId,
  getLinks: _syncRejectionGetLinks,
  attach: _syncRejectionAttach,
  version: '3.1.0+1',
);

int _syncRejectionEstimateSize(
  SyncRejection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.entityId.length * 3;
  bytesCount += 3 + object.entityType.length * 3;
  {
    final value = object.errorCode;
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
  bytesCount += 3 + object.message.length * 3;
  {
    final value = object.originatingUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolutionNotes;
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
  return bytesCount;
}

void _syncRejectionSerialize(
  SyncRejection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attemptCount);
  writer.writeString(offsets[1], object.entityId);
  writer.writeString(offsets[2], object.entityType);
  writer.writeString(offsets[3], object.errorCode);
  writer.writeString(offsets[4], object.firestoreId);
  writer.writeDateTime(offsets[5], object.firstSeenAt);
  writer.writeBool(offsets[6], object.isLikelyPermanent);
  writer.writeBool(offsets[7], object.isResolved);
  writer.writeDateTime(offsets[8], object.lastSeenAt);
  writer.writeString(offsets[9], object.message);
  writer.writeString(offsets[10], object.originatingUid);
  writer.writeString(offsets[11], object.resolutionNotes);
  writer.writeDateTime(offsets[12], object.resolvedAt);
  writer.writeString(offsets[13], object.resolvedByName);
  writer.writeString(offsets[14], object.resolvedByUid);
}

SyncRejection _syncRejectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncRejection();
  object.attemptCount = reader.readLong(offsets[0]);
  object.entityId = reader.readString(offsets[1]);
  object.entityType = reader.readString(offsets[2]);
  object.errorCode = reader.readStringOrNull(offsets[3]);
  object.firestoreId = reader.readStringOrNull(offsets[4]);
  object.firstSeenAt = reader.readDateTime(offsets[5]);
  object.id = id;
  object.isLikelyPermanent = reader.readBool(offsets[6]);
  object.isResolved = reader.readBool(offsets[7]);
  object.lastSeenAt = reader.readDateTime(offsets[8]);
  object.message = reader.readString(offsets[9]);
  object.originatingUid = reader.readStringOrNull(offsets[10]);
  object.resolutionNotes = reader.readStringOrNull(offsets[11]);
  object.resolvedAt = reader.readDateTimeOrNull(offsets[12]);
  object.resolvedByName = reader.readStringOrNull(offsets[13]);
  object.resolvedByUid = reader.readStringOrNull(offsets[14]);
  return object;
}

P _syncRejectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncRejectionGetId(SyncRejection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _syncRejectionGetLinks(SyncRejection object) {
  return [];
}

void _syncRejectionAttach(
    IsarCollection<dynamic> col, Id id, SyncRejection object) {
  object.id = id;
}

extension SyncRejectionQueryWhereSort
    on QueryBuilder<SyncRejection, SyncRejection, QWhere> {
  QueryBuilder<SyncRejection, SyncRejection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhere> anyFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'firstSeenAt'),
      );
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhere> anyLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lastSeenAt'),
      );
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhere> anyIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isResolved'),
      );
    });
  }
}

extension SyncRejectionQueryWhere
    on QueryBuilder<SyncRejection, SyncRejection, QWhereClause> {
  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause> idBetween(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      entityTypeEqualTo(String entityType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entityType',
        value: [entityType],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      entityTypeNotEqualTo(String entityType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [],
              upper: [entityType],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [entityType],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [entityType],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityType',
              lower: [],
              upper: [entityType],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause> entityIdEqualTo(
      String entityId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entityId',
        value: [entityId],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      entityIdNotEqualTo(String entityId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [],
              upper: [entityId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [entityId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [entityId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entityId',
              lower: [],
              upper: [entityId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      originatingUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'originatingUid',
        value: [null],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      originatingUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'originatingUid',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      originatingUidEqualTo(String? originatingUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'originatingUid',
        value: [originatingUid],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      originatingUidNotEqualTo(String? originatingUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'originatingUid',
              lower: [],
              upper: [originatingUid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'originatingUid',
              lower: [originatingUid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'originatingUid',
              lower: [originatingUid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'originatingUid',
              lower: [],
              upper: [originatingUid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      firstSeenAtEqualTo(DateTime firstSeenAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firstSeenAt',
        value: [firstSeenAt],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      firstSeenAtNotEqualTo(DateTime firstSeenAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firstSeenAt',
              lower: [],
              upper: [firstSeenAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firstSeenAt',
              lower: [firstSeenAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firstSeenAt',
              lower: [firstSeenAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'firstSeenAt',
              lower: [],
              upper: [firstSeenAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      firstSeenAtGreaterThan(
    DateTime firstSeenAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'firstSeenAt',
        lower: [firstSeenAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      firstSeenAtLessThan(
    DateTime firstSeenAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'firstSeenAt',
        lower: [],
        upper: [firstSeenAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      firstSeenAtBetween(
    DateTime lowerFirstSeenAt,
    DateTime upperFirstSeenAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'firstSeenAt',
        lower: [lowerFirstSeenAt],
        includeLower: includeLower,
        upper: [upperFirstSeenAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      lastSeenAtEqualTo(DateTime lastSeenAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lastSeenAt',
        value: [lastSeenAt],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      lastSeenAtNotEqualTo(DateTime lastSeenAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastSeenAt',
              lower: [],
              upper: [lastSeenAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastSeenAt',
              lower: [lastSeenAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastSeenAt',
              lower: [lastSeenAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastSeenAt',
              lower: [],
              upper: [lastSeenAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      lastSeenAtGreaterThan(
    DateTime lastSeenAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lastSeenAt',
        lower: [lastSeenAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      lastSeenAtLessThan(
    DateTime lastSeenAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lastSeenAt',
        lower: [],
        upper: [lastSeenAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      lastSeenAtBetween(
    DateTime lowerLastSeenAt,
    DateTime upperLastSeenAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lastSeenAt',
        lower: [lowerLastSeenAt],
        includeLower: includeLower,
        upper: [upperLastSeenAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
      isResolvedEqualTo(bool isResolved) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isResolved',
        value: [isResolved],
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterWhereClause>
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
}

extension SyncRejectionQueryFilter
    on QueryBuilder<SyncRejection, SyncRejection, QFilterCondition> {
  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      attemptCountGreaterThan(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      attemptCountLessThan(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      attemptCountBetween(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entityId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entityId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entityId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entityId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entityType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entityType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entityType',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      entityTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entityType',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'errorCode',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'errorCode',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'errorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'errorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'errorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'errorCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'errorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'errorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'errorCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'errorCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'errorCode',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      errorCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'errorCode',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firstSeenAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firstSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firstSeenAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'firstSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firstSeenAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'firstSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      firstSeenAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'firstSeenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      isLikelyPermanentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLikelyPermanent',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      isResolvedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isResolved',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      lastSeenAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      lastSeenAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      lastSeenAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      lastSeenAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSeenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'message',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'message',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'message',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      messageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'message',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'originatingUid',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'originatingUid',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originatingUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originatingUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originatingUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originatingUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originatingUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originatingUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originatingUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originatingUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originatingUid',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      originatingUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originatingUid',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolutionNotes',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolutionNotes',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolutionNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolutionNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolutionNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolutionNotes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolutionNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolutionNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolutionNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolutionNotes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolutionNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolutionNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolutionNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedAt',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedAt',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedByName',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedByName',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolvedByUid',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolvedByUid',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
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

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterFilterCondition>
      resolvedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedByUid',
        value: '',
      ));
    });
  }
}

extension SyncRejectionQueryObject
    on QueryBuilder<SyncRejection, SyncRejection, QFilterCondition> {}

extension SyncRejectionQueryLinks
    on QueryBuilder<SyncRejection, SyncRejection, QFilterCondition> {}

extension SyncRejectionQuerySortBy
    on QueryBuilder<SyncRejection, SyncRejection, QSortBy> {
  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByEntityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByEntityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByEntityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByEntityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeenAt', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByFirstSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeenAt', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByIsLikelyPermanent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLikelyPermanent', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByIsLikelyPermanentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLikelyPermanent', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByIsResolvedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByOriginatingUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originatingUid', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByOriginatingUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originatingUid', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolutionNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionNotes', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolutionNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionNotes', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> sortByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolvedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByName', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolvedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByName', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolvedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByUid', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      sortByResolvedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByUid', Sort.desc);
    });
  }
}

extension SyncRejectionQuerySortThenBy
    on QueryBuilder<SyncRejection, SyncRejection, QSortThenBy> {
  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByEntityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByEntityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityId', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByEntityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByEntityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entityType', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeenAt', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByFirstSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeenAt', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByIsLikelyPermanent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLikelyPermanent', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByIsLikelyPermanentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLikelyPermanent', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByIsResolvedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isResolved', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByOriginatingUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originatingUid', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByOriginatingUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originatingUid', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolutionNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionNotes', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolutionNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionNotes', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy> thenByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolvedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByName', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolvedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByName', Sort.desc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolvedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByUid', Sort.asc);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QAfterSortBy>
      thenByResolvedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedByUid', Sort.desc);
    });
  }
}

extension SyncRejectionQueryWhereDistinct
    on QueryBuilder<SyncRejection, SyncRejection, QDistinct> {
  QueryBuilder<SyncRejection, SyncRejection, QDistinct>
      distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByEntityId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByEntityType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entityType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByErrorCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByFirestoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct>
      distinctByFirstSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firstSeenAt');
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct>
      distinctByIsLikelyPermanent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLikelyPermanent');
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByIsResolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isResolved');
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeenAt');
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByMessage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct>
      distinctByOriginatingUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originatingUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct>
      distinctByResolutionNotes({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolutionNotes',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedAt');
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct>
      distinctByResolvedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRejection, SyncRejection, QDistinct> distinctByResolvedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedByUid',
          caseSensitive: caseSensitive);
    });
  }
}

extension SyncRejectionQueryProperty
    on QueryBuilder<SyncRejection, SyncRejection, QQueryProperty> {
  QueryBuilder<SyncRejection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SyncRejection, int, QQueryOperations> attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<SyncRejection, String, QQueryOperations> entityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entityId');
    });
  }

  QueryBuilder<SyncRejection, String, QQueryOperations> entityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entityType');
    });
  }

  QueryBuilder<SyncRejection, String?, QQueryOperations> errorCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorCode');
    });
  }

  QueryBuilder<SyncRejection, String?, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<SyncRejection, DateTime, QQueryOperations>
      firstSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firstSeenAt');
    });
  }

  QueryBuilder<SyncRejection, bool, QQueryOperations>
      isLikelyPermanentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLikelyPermanent');
    });
  }

  QueryBuilder<SyncRejection, bool, QQueryOperations> isResolvedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isResolved');
    });
  }

  QueryBuilder<SyncRejection, DateTime, QQueryOperations> lastSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeenAt');
    });
  }

  QueryBuilder<SyncRejection, String, QQueryOperations> messageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message');
    });
  }

  QueryBuilder<SyncRejection, String?, QQueryOperations>
      originatingUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originatingUid');
    });
  }

  QueryBuilder<SyncRejection, String?, QQueryOperations>
      resolutionNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolutionNotes');
    });
  }

  QueryBuilder<SyncRejection, DateTime?, QQueryOperations>
      resolvedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedAt');
    });
  }

  QueryBuilder<SyncRejection, String?, QQueryOperations>
      resolvedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedByName');
    });
  }

  QueryBuilder<SyncRejection, String?, QQueryOperations>
      resolvedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedByUid');
    });
  }
}
