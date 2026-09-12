// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'durable_submission_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDurableSubmissionRecordCollection on Isar {
  IsarCollection<DurableSubmissionRecord> get durableSubmissionRecords =>
      this.collection();
}

const DurableSubmissionRecordSchema = CollectionSchema(
  name: r'DurableSubmissionRecord',
  id: 7587045010620386682,
  properties: {
    r'acceptedAt': PropertySchema(
      id: 0,
      name: r'acceptedAt',
      type: IsarType.dateTime,
    ),
    r'actorUid': PropertySchema(
      id: 1,
      name: r'actorUid',
      type: IsarType.string,
    ),
    r'attemptCount': PropertySchema(
      id: 2,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'claimExpiresAt': PropertySchema(
      id: 3,
      name: r'claimExpiresAt',
      type: IsarType.dateTime,
    ),
    r'claimToken': PropertySchema(
      id: 4,
      name: r'claimToken',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 5,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'immutableJson': PropertySchema(
      id: 6,
      name: r'immutableJson',
      type: IsarType.string,
    ),
    r'immutableSha256': PropertySchema(
      id: 7,
      name: r'immutableSha256',
      type: IsarType.string,
    ),
    r'lastErrorCode': PropertySchema(
      id: 8,
      name: r'lastErrorCode',
      type: IsarType.string,
    ),
    r'lastErrorMessage': PropertySchema(
      id: 9,
      name: r'lastErrorMessage',
      type: IsarType.string,
    ),
    r'nextRetryAt': PropertySchema(
      id: 10,
      name: r'nextRetryAt',
      type: IsarType.dateTime,
    ),
    r'receiptJson': PropertySchema(
      id: 11,
      name: r'receiptJson',
      type: IsarType.string,
    ),
    r'receiptSha256': PropertySchema(
      id: 12,
      name: r'receiptSha256',
      type: IsarType.string,
    ),
    r'reconciledAt': PropertySchema(
      id: 13,
      name: r'reconciledAt',
      type: IsarType.dateTime,
    ),
    r'requestKey': PropertySchema(
      id: 14,
      name: r'requestKey',
      type: IsarType.string,
    ),
    r'resourceKey': PropertySchema(
      id: 15,
      name: r'resourceKey',
      type: IsarType.string,
    ),
    r'stateKey': PropertySchema(
      id: 16,
      name: r'stateKey',
      type: IsarType.string,
    ),
    r'submissionId': PropertySchema(
      id: 17,
      name: r'submissionId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 18,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _durableSubmissionRecordEstimateSize,
  serialize: _durableSubmissionRecordSerialize,
  deserialize: _durableSubmissionRecordDeserialize,
  deserializeProp: _durableSubmissionRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'submissionId': IndexSchema(
      id: -2892912531548707009,
      name: r'submissionId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'submissionId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'requestKey': IndexSchema(
      id: 4828138959217314811,
      name: r'requestKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'requestKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'resourceKey': IndexSchema(
      id: 8701471516144682442,
      name: r'resourceKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'resourceKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'actorUid': IndexSchema(
      id: 2911305686087963256,
      name: r'actorUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'actorUid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _durableSubmissionRecordGetId,
  getLinks: _durableSubmissionRecordGetLinks,
  attach: _durableSubmissionRecordAttach,
  version: '3.3.2',
);

int _durableSubmissionRecordEstimateSize(
  DurableSubmissionRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.actorUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.claimToken;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.immutableJson.length * 3;
  bytesCount += 3 + object.immutableSha256.length * 3;
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
  {
    final value = object.receiptJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.receiptSha256;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.requestKey.length * 3;
  bytesCount += 3 + object.resourceKey.length * 3;
  bytesCount += 3 + object.stateKey.length * 3;
  bytesCount += 3 + object.submissionId.length * 3;
  return bytesCount;
}

void _durableSubmissionRecordSerialize(
  DurableSubmissionRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acceptedAt);
  writer.writeString(offsets[1], object.actorUid);
  writer.writeLong(offsets[2], object.attemptCount);
  writer.writeDateTime(offsets[3], object.claimExpiresAt);
  writer.writeString(offsets[4], object.claimToken);
  writer.writeDateTime(offsets[5], object.createdAt);
  writer.writeString(offsets[6], object.immutableJson);
  writer.writeString(offsets[7], object.immutableSha256);
  writer.writeString(offsets[8], object.lastErrorCode);
  writer.writeString(offsets[9], object.lastErrorMessage);
  writer.writeDateTime(offsets[10], object.nextRetryAt);
  writer.writeString(offsets[11], object.receiptJson);
  writer.writeString(offsets[12], object.receiptSha256);
  writer.writeDateTime(offsets[13], object.reconciledAt);
  writer.writeString(offsets[14], object.requestKey);
  writer.writeString(offsets[15], object.resourceKey);
  writer.writeString(offsets[16], object.stateKey);
  writer.writeString(offsets[17], object.submissionId);
  writer.writeDateTime(offsets[18], object.updatedAt);
}

DurableSubmissionRecord _durableSubmissionRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DurableSubmissionRecord();
  object.acceptedAt = reader.readDateTimeOrNull(offsets[0]);
  object.actorUid = reader.readStringOrNull(offsets[1]);
  object.attemptCount = reader.readLong(offsets[2]);
  object.claimExpiresAt = reader.readDateTimeOrNull(offsets[3]);
  object.claimToken = reader.readStringOrNull(offsets[4]);
  object.createdAt = reader.readDateTime(offsets[5]);
  object.id = id;
  object.immutableJson = reader.readString(offsets[6]);
  object.immutableSha256 = reader.readString(offsets[7]);
  object.lastErrorCode = reader.readStringOrNull(offsets[8]);
  object.lastErrorMessage = reader.readStringOrNull(offsets[9]);
  object.nextRetryAt = reader.readDateTimeOrNull(offsets[10]);
  object.receiptJson = reader.readStringOrNull(offsets[11]);
  object.receiptSha256 = reader.readStringOrNull(offsets[12]);
  object.reconciledAt = reader.readDateTimeOrNull(offsets[13]);
  object.requestKey = reader.readString(offsets[14]);
  object.resourceKey = reader.readString(offsets[15]);
  object.stateKey = reader.readString(offsets[16]);
  object.submissionId = reader.readString(offsets[17]);
  object.updatedAt = reader.readDateTime(offsets[18]);
  return object;
}

P _durableSubmissionRecordDeserializeProp<P>(
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
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _durableSubmissionRecordGetId(DurableSubmissionRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _durableSubmissionRecordGetLinks(
  DurableSubmissionRecord object,
) {
  return [];
}

void _durableSubmissionRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  DurableSubmissionRecord object,
) {
  object.id = id;
}

extension DurableSubmissionRecordByIndex
    on IsarCollection<DurableSubmissionRecord> {
  Future<DurableSubmissionRecord?> getBySubmissionId(String submissionId) {
    return getByIndex(r'submissionId', [submissionId]);
  }

  DurableSubmissionRecord? getBySubmissionIdSync(String submissionId) {
    return getByIndexSync(r'submissionId', [submissionId]);
  }

  Future<bool> deleteBySubmissionId(String submissionId) {
    return deleteByIndex(r'submissionId', [submissionId]);
  }

  bool deleteBySubmissionIdSync(String submissionId) {
    return deleteByIndexSync(r'submissionId', [submissionId]);
  }

  Future<List<DurableSubmissionRecord?>> getAllBySubmissionId(
    List<String> submissionIdValues,
  ) {
    final values = submissionIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'submissionId', values);
  }

  List<DurableSubmissionRecord?> getAllBySubmissionIdSync(
    List<String> submissionIdValues,
  ) {
    final values = submissionIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'submissionId', values);
  }

  Future<int> deleteAllBySubmissionId(List<String> submissionIdValues) {
    final values = submissionIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'submissionId', values);
  }

  int deleteAllBySubmissionIdSync(List<String> submissionIdValues) {
    final values = submissionIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'submissionId', values);
  }

  Future<Id> putBySubmissionId(DurableSubmissionRecord object) {
    return putByIndex(r'submissionId', object);
  }

  Id putBySubmissionIdSync(
    DurableSubmissionRecord object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'submissionId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySubmissionId(List<DurableSubmissionRecord> objects) {
    return putAllByIndex(r'submissionId', objects);
  }

  List<Id> putAllBySubmissionIdSync(
    List<DurableSubmissionRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'submissionId', objects, saveLinks: saveLinks);
  }

  Future<DurableSubmissionRecord?> getByRequestKey(String requestKey) {
    return getByIndex(r'requestKey', [requestKey]);
  }

  DurableSubmissionRecord? getByRequestKeySync(String requestKey) {
    return getByIndexSync(r'requestKey', [requestKey]);
  }

  Future<bool> deleteByRequestKey(String requestKey) {
    return deleteByIndex(r'requestKey', [requestKey]);
  }

  bool deleteByRequestKeySync(String requestKey) {
    return deleteByIndexSync(r'requestKey', [requestKey]);
  }

  Future<List<DurableSubmissionRecord?>> getAllByRequestKey(
    List<String> requestKeyValues,
  ) {
    final values = requestKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'requestKey', values);
  }

  List<DurableSubmissionRecord?> getAllByRequestKeySync(
    List<String> requestKeyValues,
  ) {
    final values = requestKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'requestKey', values);
  }

  Future<int> deleteAllByRequestKey(List<String> requestKeyValues) {
    final values = requestKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'requestKey', values);
  }

  int deleteAllByRequestKeySync(List<String> requestKeyValues) {
    final values = requestKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'requestKey', values);
  }

  Future<Id> putByRequestKey(DurableSubmissionRecord object) {
    return putByIndex(r'requestKey', object);
  }

  Id putByRequestKeySync(
    DurableSubmissionRecord object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'requestKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByRequestKey(List<DurableSubmissionRecord> objects) {
    return putAllByIndex(r'requestKey', objects);
  }

  List<Id> putAllByRequestKeySync(
    List<DurableSubmissionRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'requestKey', objects, saveLinks: saveLinks);
  }
}

extension DurableSubmissionRecordQueryWhereSort
    on QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QWhere> {
  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DurableSubmissionRecordQueryWhere
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QWhereClause
        > {
  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
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

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  submissionIdEqualTo(String submissionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'submissionId',
          value: [submissionId],
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  submissionIdNotEqualTo(String submissionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'submissionId',
                lower: [],
                upper: [submissionId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'submissionId',
                lower: [submissionId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'submissionId',
                lower: [submissionId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'submissionId',
                lower: [],
                upper: [submissionId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  requestKeyEqualTo(String requestKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'requestKey', value: [requestKey]),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  requestKeyNotEqualTo(String requestKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestKey',
                lower: [],
                upper: [requestKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestKey',
                lower: [requestKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestKey',
                lower: [requestKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestKey',
                lower: [],
                upper: [requestKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  resourceKeyEqualTo(String resourceKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'resourceKey',
          value: [resourceKey],
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  resourceKeyNotEqualTo(String resourceKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'resourceKey',
                lower: [],
                upper: [resourceKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'resourceKey',
                lower: [resourceKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'resourceKey',
                lower: [resourceKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'resourceKey',
                lower: [],
                upper: [resourceKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  actorUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'actorUid', value: [null]),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  actorUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'actorUid',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  actorUidEqualTo(String? actorUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'actorUid', value: [actorUid]),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterWhereClause
  >
  actorUidNotEqualTo(String? actorUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'actorUid',
                lower: [],
                upper: [actorUid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'actorUid',
                lower: [actorUid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'actorUid',
                lower: [actorUid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'actorUid',
                lower: [],
                upper: [actorUid],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension DurableSubmissionRecordQueryFilter
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QFilterCondition
        > {
  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  acceptedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'acceptedAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  acceptedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'acceptedAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  acceptedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'acceptedAt', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  acceptedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'acceptedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  acceptedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'acceptedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  acceptedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'acceptedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'actorUid'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'actorUid'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'actorUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'actorUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'actorUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'actorUid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'actorUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'actorUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'actorUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'actorUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'actorUid', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  actorUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'actorUid', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attemptCount', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  attemptCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attemptCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  attemptCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attemptCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  attemptCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attemptCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimExpiresAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'claimExpiresAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimExpiresAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'claimExpiresAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimExpiresAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'claimExpiresAt', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimExpiresAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'claimExpiresAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimExpiresAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'claimExpiresAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimExpiresAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'claimExpiresAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'claimToken'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'claimToken'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'claimToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'claimToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'claimToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'claimToken',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'claimToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'claimToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'claimToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'claimToken',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'claimToken', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  claimTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'claimToken', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'immutableJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'immutableJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'immutableJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'immutableJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'immutableJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'immutableJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'immutableJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'immutableJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'immutableJson', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'immutableJson', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256EqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'immutableSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256GreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'immutableSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256LessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'immutableSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256Between(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'immutableSha256',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256StartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'immutableSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256EndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'immutableSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'immutableSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'immutableSha256',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'immutableSha256', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  immutableSha256IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'immutableSha256', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastErrorCode'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastErrorCode'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastErrorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastErrorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastErrorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastErrorCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastErrorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastErrorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastErrorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastErrorCode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastErrorCode', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastErrorCode', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastErrorMessage'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastErrorMessage'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastErrorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastErrorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastErrorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastErrorMessage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastErrorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastErrorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastErrorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastErrorMessage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastErrorMessage', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  lastErrorMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastErrorMessage', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  nextRetryAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'nextRetryAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  nextRetryAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'nextRetryAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  nextRetryAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nextRetryAt', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  nextRetryAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nextRetryAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  nextRetryAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nextRetryAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  nextRetryAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nextRetryAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'receiptJson'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'receiptJson'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'receiptJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'receiptJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'receiptJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'receiptJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'receiptJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'receiptJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'receiptJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'receiptJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'receiptJson', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'receiptJson', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'receiptSha256'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'receiptSha256'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256EqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'receiptSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256GreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'receiptSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256LessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'receiptSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256Between(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'receiptSha256',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256StartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'receiptSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256EndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'receiptSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'receiptSha256',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'receiptSha256',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'receiptSha256', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  receiptSha256IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'receiptSha256', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  reconciledAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'reconciledAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  reconciledAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'reconciledAt'),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  reconciledAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reconciledAt', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  reconciledAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reconciledAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  reconciledAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reconciledAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  reconciledAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reconciledAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'requestKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'requestKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'requestKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'requestKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'requestKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'requestKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'requestKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'requestKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'requestKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  requestKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'requestKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'resourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'resourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'resourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'resourceKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'resourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'resourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'resourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'resourceKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'resourceKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  resourceKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'resourceKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'stateKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'stateKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stateKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  stateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'stateKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'submissionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'submissionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'submissionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'submissionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'submissionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'submissionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'submissionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'submissionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'submissionId', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  submissionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'submissionId', value: ''),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DurableSubmissionRecord,
    DurableSubmissionRecord,
    QAfterFilterCondition
  >
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension DurableSubmissionRecordQueryObject
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QFilterCondition
        > {}

extension DurableSubmissionRecordQueryLinks
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QFilterCondition
        > {}

extension DurableSubmissionRecordQuerySortBy
    on QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QSortBy> {
  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByActorUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByActorUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByClaimExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimExpiresAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByClaimExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimExpiresAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByClaimToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimToken', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByClaimTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimToken', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByImmutableJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableJson', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByImmutableJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableJson', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByImmutableSha256() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableSha256', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByImmutableSha256Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableSha256', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByLastErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByLastErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByLastErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByLastErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByNextRetryAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByReceiptJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByReceiptJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByReceiptSha256() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptSha256', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByReceiptSha256Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptSha256', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByReconciledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reconciledAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByReconciledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reconciledAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByRequestKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestKey', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByRequestKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestKey', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByResourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resourceKey', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByResourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resourceKey', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortBySubmissionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionId', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortBySubmissionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionId', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DurableSubmissionRecordQuerySortThenBy
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QSortThenBy
        > {
  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByActorUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByActorUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorUid', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByClaimExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimExpiresAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByClaimExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimExpiresAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByClaimToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimToken', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByClaimTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimToken', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByImmutableJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableJson', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByImmutableJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableJson', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByImmutableSha256() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableSha256', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByImmutableSha256Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'immutableSha256', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByLastErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByLastErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorCode', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByLastErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByLastErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorMessage', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByNextRetryAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByReceiptJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByReceiptJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptJson', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByReceiptSha256() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptSha256', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByReceiptSha256Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptSha256', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByReconciledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reconciledAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByReconciledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reconciledAt', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByRequestKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestKey', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByRequestKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestKey', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByResourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resourceKey', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByResourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resourceKey', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenBySubmissionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionId', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenBySubmissionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionId', Sort.desc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DurableSubmissionRecordQueryWhereDistinct
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QDistinct
        > {
  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByActorUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actorUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByClaimExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'claimExpiresAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByClaimToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'claimToken', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByImmutableJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'immutableJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByImmutableSha256({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'immutableSha256',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByLastErrorCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastErrorCode',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByLastErrorMessage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastErrorMessage',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextRetryAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByReceiptJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiptJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByReceiptSha256({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'receiptSha256',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByReconciledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reconciledAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByRequestKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requestKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByResourceKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resourceKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByStateKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctBySubmissionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'submissionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DurableSubmissionRecord, DurableSubmissionRecord, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension DurableSubmissionRecordQueryProperty
    on
        QueryBuilder<
          DurableSubmissionRecord,
          DurableSubmissionRecord,
          QQueryProperty
        > {
  QueryBuilder<DurableSubmissionRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DateTime?, QQueryOperations>
  acceptedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String?, QQueryOperations>
  actorUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actorUid');
    });
  }

  QueryBuilder<DurableSubmissionRecord, int, QQueryOperations>
  attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DateTime?, QQueryOperations>
  claimExpiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'claimExpiresAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String?, QQueryOperations>
  claimTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'claimToken');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String, QQueryOperations>
  immutableJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'immutableJson');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String, QQueryOperations>
  immutableSha256Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'immutableSha256');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String?, QQueryOperations>
  lastErrorCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastErrorCode');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String?, QQueryOperations>
  lastErrorMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastErrorMessage');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DateTime?, QQueryOperations>
  nextRetryAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextRetryAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String?, QQueryOperations>
  receiptJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiptJson');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String?, QQueryOperations>
  receiptSha256Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiptSha256');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DateTime?, QQueryOperations>
  reconciledAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reconciledAt');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String, QQueryOperations>
  requestKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requestKey');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String, QQueryOperations>
  resourceKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resourceKey');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String, QQueryOperations>
  stateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateKey');
    });
  }

  QueryBuilder<DurableSubmissionRecord, String, QQueryOperations>
  submissionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'submissionId');
    });
  }

  QueryBuilder<DurableSubmissionRecord, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
