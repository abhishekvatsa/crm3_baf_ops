// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compliance_attempt_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetComplianceAttemptRecordCollection on Isar {
  IsarCollection<ComplianceAttemptRecord> get complianceAttemptRecords =>
      this.collection();
}

const ComplianceAttemptRecordSchema = CollectionSchema(
  name: r'ComplianceAttemptRecord',
  id: -2737743014038071799,
  properties: {
    r'accepted': PropertySchema(
      id: 0,
      name: r'accepted',
      type: IsarType.bool,
    ),
    r'acceptedAt': PropertySchema(
      id: 1,
      name: r'acceptedAt',
      type: IsarType.dateTime,
    ),
    r'acceptedByName': PropertySchema(
      id: 2,
      name: r'acceptedByName',
      type: IsarType.string,
    ),
    r'acceptedByUid': PropertySchema(
      id: 3,
      name: r'acceptedByUid',
      type: IsarType.string,
    ),
    r'attemptNumber': PropertySchema(
      id: 4,
      name: r'attemptNumber',
      type: IsarType.long,
    ),
    r'attemptedAt': PropertySchema(
      id: 5,
      name: r'attemptedAt',
      type: IsarType.dateTime,
    ),
    r'attemptedByName': PropertySchema(
      id: 6,
      name: r'attemptedByName',
      type: IsarType.string,
    ),
    r'attemptedByUid': PropertySchema(
      id: 7,
      name: r'attemptedByUid',
      type: IsarType.string,
    ),
    r'complianceRequestFirestoreId': PropertySchema(
      id: 8,
      name: r'complianceRequestFirestoreId',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 9,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(
      id: 10,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'note': PropertySchema(
      id: 11,
      name: r'note',
      type: IsarType.string,
    ),
    r'returnReason': PropertySchema(
      id: 12,
      name: r'returnReason',
      type: IsarType.string,
    ),
    r'returnedAt': PropertySchema(
      id: 13,
      name: r'returnedAt',
      type: IsarType.dateTime,
    ),
    r'returnedByName': PropertySchema(
      id: 14,
      name: r'returnedByName',
      type: IsarType.string,
    ),
    r'returnedByUid': PropertySchema(
      id: 15,
      name: r'returnedByUid',
      type: IsarType.string,
    )
  },
  estimateSize: _complianceAttemptRecordEstimateSize,
  serialize: _complianceAttemptRecordSerialize,
  deserialize: _complianceAttemptRecordDeserialize,
  deserializeProp: _complianceAttemptRecordDeserializeProp,
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
    r'complianceRequestFirestoreId': IndexSchema(
      id: 4618647446466106449,
      name: r'complianceRequestFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'complianceRequestFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _complianceAttemptRecordGetId,
  getLinks: _complianceAttemptRecordGetLinks,
  attach: _complianceAttemptRecordAttach,
  version: '3.1.0+1',
);

int _complianceAttemptRecordEstimateSize(
  ComplianceAttemptRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.acceptedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.acceptedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attemptedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.attemptedByUid.length * 3;
  bytesCount += 3 + object.complianceRequestFirestoreId.length * 3;
  bytesCount += 3 + object.firestoreId.length * 3;
  bytesCount += 3 + object.note.length * 3;
  {
    final value = object.returnReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.returnedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.returnedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _complianceAttemptRecordSerialize(
  ComplianceAttemptRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.accepted);
  writer.writeDateTime(offsets[1], object.acceptedAt);
  writer.writeString(offsets[2], object.acceptedByName);
  writer.writeString(offsets[3], object.acceptedByUid);
  writer.writeLong(offsets[4], object.attemptNumber);
  writer.writeDateTime(offsets[5], object.attemptedAt);
  writer.writeString(offsets[6], object.attemptedByName);
  writer.writeString(offsets[7], object.attemptedByUid);
  writer.writeString(offsets[8], object.complianceRequestFirestoreId);
  writer.writeString(offsets[9], object.firestoreId);
  writer.writeBool(offsets[10], object.isSynced);
  writer.writeString(offsets[11], object.note);
  writer.writeString(offsets[12], object.returnReason);
  writer.writeDateTime(offsets[13], object.returnedAt);
  writer.writeString(offsets[14], object.returnedByName);
  writer.writeString(offsets[15], object.returnedByUid);
}

ComplianceAttemptRecord _complianceAttemptRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ComplianceAttemptRecord();
  object.accepted = reader.readBool(offsets[0]);
  object.acceptedAt = reader.readDateTimeOrNull(offsets[1]);
  object.acceptedByName = reader.readStringOrNull(offsets[2]);
  object.acceptedByUid = reader.readStringOrNull(offsets[3]);
  object.attemptNumber = reader.readLong(offsets[4]);
  object.attemptedAt = reader.readDateTime(offsets[5]);
  object.attemptedByName = reader.readStringOrNull(offsets[6]);
  object.attemptedByUid = reader.readString(offsets[7]);
  object.complianceRequestFirestoreId = reader.readString(offsets[8]);
  object.firestoreId = reader.readString(offsets[9]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[10]);
  object.note = reader.readString(offsets[11]);
  object.returnReason = reader.readStringOrNull(offsets[12]);
  object.returnedAt = reader.readDateTimeOrNull(offsets[13]);
  object.returnedByName = reader.readStringOrNull(offsets[14]);
  object.returnedByUid = reader.readStringOrNull(offsets[15]);
  return object;
}

P _complianceAttemptRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _complianceAttemptRecordGetId(ComplianceAttemptRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _complianceAttemptRecordGetLinks(
    ComplianceAttemptRecord object) {
  return [];
}

void _complianceAttemptRecordAttach(
    IsarCollection<dynamic> col, Id id, ComplianceAttemptRecord object) {
  object.id = id;
}

extension ComplianceAttemptRecordByIndex
    on IsarCollection<ComplianceAttemptRecord> {
  Future<ComplianceAttemptRecord?> getByFirestoreId(String firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  ComplianceAttemptRecord? getByFirestoreIdSync(String firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<ComplianceAttemptRecord?>> getAllByFirestoreId(
      List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<ComplianceAttemptRecord?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(ComplianceAttemptRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(ComplianceAttemptRecord object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<ComplianceAttemptRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<ComplianceAttemptRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension ComplianceAttemptRecordQueryWhereSort
    on QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QWhere> {
  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ComplianceAttemptRecordQueryWhere on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QWhereClause> {
  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterWhereClause> firestoreIdEqualTo(String firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterWhereClause>
      complianceRequestFirestoreIdEqualTo(String complianceRequestFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'complianceRequestFirestoreId',
        value: [complianceRequestFirestoreId],
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterWhereClause>
      complianceRequestFirestoreIdNotEqualTo(
          String complianceRequestFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'complianceRequestFirestoreId',
              lower: [],
              upper: [complianceRequestFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'complianceRequestFirestoreId',
              lower: [complianceRequestFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'complianceRequestFirestoreId',
              lower: [complianceRequestFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'complianceRequestFirestoreId',
              lower: [],
              upper: [complianceRequestFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ComplianceAttemptRecordQueryFilter on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QFilterCondition> {
  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accepted',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptedAt',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptedAt',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptedByName',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptedByName',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      acceptedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      acceptedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acceptedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acceptedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      acceptedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      acceptedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acceptedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> acceptedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acceptedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptNumberGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptNumberLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'attemptedByName',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'attemptedByName',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attemptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attemptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      attemptedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attemptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      attemptedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attemptedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attemptedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attemptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attemptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      attemptedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attemptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      attemptedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attemptedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> attemptedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attemptedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceRequestFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'complianceRequestFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'complianceRequestFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'complianceRequestFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'complianceRequestFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'complianceRequestFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      complianceRequestFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'complianceRequestFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      complianceRequestFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'complianceRequestFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceRequestFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> complianceRequestFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'complianceRequestFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
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

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'returnReason',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'returnReason',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'returnReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'returnReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'returnReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'returnReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'returnReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      returnReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'returnReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      returnReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'returnReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'returnReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'returnedAt',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'returnedAt',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'returnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'returnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'returnedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'returnedByName',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'returnedByName',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'returnedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'returnedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'returnedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'returnedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'returnedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      returnedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'returnedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      returnedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'returnedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'returnedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'returnedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'returnedByUid',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'returnedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'returnedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'returnedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'returnedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'returnedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      returnedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'returnedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
          QAfterFilterCondition>
      returnedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'returnedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'returnedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord,
      QAfterFilterCondition> returnedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'returnedByUid',
        value: '',
      ));
    });
  }
}

extension ComplianceAttemptRecordQueryObject on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QFilterCondition> {}

extension ComplianceAttemptRecordQueryLinks on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QFilterCondition> {}

extension ComplianceAttemptRecordQuerySortBy
    on QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QSortBy> {
  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAccepted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accepted', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accepted', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAcceptedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByAttemptedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByComplianceRequestFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceRequestFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByComplianceRequestFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceRequestFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      sortByReturnedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByUid', Sort.desc);
    });
  }
}

extension ComplianceAttemptRecordQuerySortThenBy on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QSortThenBy> {
  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAccepted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accepted', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accepted', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAcceptedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByAttemptedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptedByUid', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByComplianceRequestFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceRequestFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByComplianceRequestFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceRequestFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnReason', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedAt', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedAt', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByName', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByName', Sort.desc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByUid', Sort.asc);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QAfterSortBy>
      thenByReturnedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'returnedByUid', Sort.desc);
    });
  }
}

extension ComplianceAttemptRecordQueryWhereDistinct on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct> {
  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAccepted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accepted');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedAt');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAcceptedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAcceptedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAttemptNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptNumber');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAttemptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptedAt');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAttemptedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByAttemptedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByComplianceRequestFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'complianceRequestFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByReturnReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByReturnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnedAt');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByReturnedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ComplianceAttemptRecord, ComplianceAttemptRecord, QDistinct>
      distinctByReturnedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'returnedByUid',
          caseSensitive: caseSensitive);
    });
  }
}

extension ComplianceAttemptRecordQueryProperty on QueryBuilder<
    ComplianceAttemptRecord, ComplianceAttemptRecord, QQueryProperty> {
  QueryBuilder<ComplianceAttemptRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, bool, QQueryOperations>
      acceptedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accepted');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, DateTime?, QQueryOperations>
      acceptedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedAt');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String?, QQueryOperations>
      acceptedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedByName');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String?, QQueryOperations>
      acceptedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedByUid');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, int, QQueryOperations>
      attemptNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptNumber');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, DateTime, QQueryOperations>
      attemptedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptedAt');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String?, QQueryOperations>
      attemptedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptedByName');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String, QQueryOperations>
      attemptedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptedByUid');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String, QQueryOperations>
      complianceRequestFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'complianceRequestFirestoreId');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String, QQueryOperations>
      noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String?, QQueryOperations>
      returnReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnReason');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, DateTime?, QQueryOperations>
      returnedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnedAt');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String?, QQueryOperations>
      returnedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnedByName');
    });
  }

  QueryBuilder<ComplianceAttemptRecord, String?, QQueryOperations>
      returnedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'returnedByUid');
    });
  }
}
