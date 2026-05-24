// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'abnormality_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAbnormalityTypeCollection on Isar {
  IsarCollection<AbnormalityType> get abnormalityTypes => this.collection();
}

const AbnormalityTypeSchema = CollectionSchema(
  name: r'AbnormalityType',
  id: 8484628406258702188,
  properties: {
    r'applicableAssetTypeIndexes': PropertySchema(
      id: 0,
      name: r'applicableAssetTypeIndexes',
      type: IsarType.longList,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.byte,
      enumMap: _AbnormalityTypecategoryEnumValueMap,
    ),
    r'code': PropertySchema(
      id: 2,
      name: r'code',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdByName': PropertySchema(
      id: 4,
      name: r'createdByName',
      type: IsarType.string,
    ),
    r'createdByUid': PropertySchema(
      id: 5,
      name: r'createdByUid',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 6,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 7,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 8,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 9,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 10,
      name: r'description',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 11,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isActive': PropertySchema(
      id: 12,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 13,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 14,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'lastEditedByName': PropertySchema(
      id: 15,
      name: r'lastEditedByName',
      type: IsarType.string,
    ),
    r'lastEditedByUid': PropertySchema(
      id: 16,
      name: r'lastEditedByUid',
      type: IsarType.string,
    ),
    r'severity': PropertySchema(
      id: 17,
      name: r'severity',
      type: IsarType.byte,
      enumMap: _AbnormalityTypeseverityEnumValueMap,
    ),
    r'suggestsReannealing': PropertySchema(
      id: 18,
      name: r'suggestsReannealing',
      type: IsarType.bool,
    ),
    r'title': PropertySchema(
      id: 19,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 20,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 21,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _abnormalityTypeEstimateSize,
  serialize: _abnormalityTypeSerialize,
  deserialize: _abnormalityTypeDeserialize,
  deserializeProp: _abnormalityTypeDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'code': IndexSchema(
      id: 329780482934683790,
      name: r'code',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'code',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'title': IndexSchema(
      id: -7636685945352118059,
      name: r'title',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'title',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'isActive': IndexSchema(
      id: 8092228061260947457,
      name: r'isActive',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isActive',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isDeleted': IndexSchema(
      id: -786475870904832312,
      name: r'isDeleted',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isDeleted',
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
  getId: _abnormalityTypeGetId,
  getLinks: _abnormalityTypeGetLinks,
  attach: _abnormalityTypeAttach,
  version: '3.1.0+1',
);

int _abnormalityTypeEstimateSize(
  AbnormalityType object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.applicableAssetTypeIndexes.length * 8;
  bytesCount += 3 + object.code.length * 3;
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
    final value = object.description;
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
    final value = object.lastEditedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastEditedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _abnormalityTypeSerialize(
  AbnormalityType object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLongList(offsets[0], object.applicableAssetTypeIndexes);
  writer.writeByte(offsets[1], object.category.index);
  writer.writeString(offsets[2], object.code);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.createdByName);
  writer.writeString(offsets[5], object.createdByUid);
  writer.writeString(offsets[6], object.deleteReason);
  writer.writeDateTime(offsets[7], object.deletedAt);
  writer.writeString(offsets[8], object.deletedByName);
  writer.writeString(offsets[9], object.deletedByUid);
  writer.writeString(offsets[10], object.description);
  writer.writeString(offsets[11], object.firestoreId);
  writer.writeBool(offsets[12], object.isActive);
  writer.writeBool(offsets[13], object.isDeleted);
  writer.writeBool(offsets[14], object.isSynced);
  writer.writeString(offsets[15], object.lastEditedByName);
  writer.writeString(offsets[16], object.lastEditedByUid);
  writer.writeByte(offsets[17], object.severity.index);
  writer.writeBool(offsets[18], object.suggestsReannealing);
  writer.writeString(offsets[19], object.title);
  writer.writeDateTime(offsets[20], object.updatedAt);
  writer.writeLong(offsets[21], object.version);
}

AbnormalityType _abnormalityTypeDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AbnormalityType();
  object.applicableAssetTypeIndexes = reader.readLongList(offsets[0]) ?? [];
  object.category =
      _AbnormalityTypecategoryValueEnumMap[reader.readByteOrNull(offsets[1])] ??
          AbnormalityCategory.process;
  object.code = reader.readString(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.createdByName = reader.readStringOrNull(offsets[4]);
  object.createdByUid = reader.readStringOrNull(offsets[5]);
  object.deleteReason = reader.readStringOrNull(offsets[6]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[7]);
  object.deletedByName = reader.readStringOrNull(offsets[8]);
  object.deletedByUid = reader.readStringOrNull(offsets[9]);
  object.description = reader.readStringOrNull(offsets[10]);
  object.firestoreId = reader.readStringOrNull(offsets[11]);
  object.id = id;
  object.isActive = reader.readBool(offsets[12]);
  object.isDeleted = reader.readBool(offsets[13]);
  object.isSynced = reader.readBool(offsets[14]);
  object.lastEditedByName = reader.readStringOrNull(offsets[15]);
  object.lastEditedByUid = reader.readStringOrNull(offsets[16]);
  object.severity = _AbnormalityTypeseverityValueEnumMap[
          reader.readByteOrNull(offsets[17])] ??
      AbnormalitySeverity.low;
  object.suggestsReannealing = reader.readBool(offsets[18]);
  object.title = reader.readString(offsets[19]);
  object.updatedAt = reader.readDateTime(offsets[20]);
  object.version = reader.readLong(offsets[21]);
  return object;
}

P _abnormalityTypeDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongList(offset) ?? []) as P;
    case 1:
      return (_AbnormalityTypecategoryValueEnumMap[
              reader.readByteOrNull(offset)] ??
          AbnormalityCategory.process) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (_AbnormalityTypeseverityValueEnumMap[
              reader.readByteOrNull(offset)] ??
          AbnormalitySeverity.low) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readDateTime(offset)) as P;
    case 21:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _AbnormalityTypecategoryEnumValueMap = {
  'process': 0,
  'equipment': 1,
  'resultQuality': 2,
  'reannealing': 3,
  'other': 4,
};
const _AbnormalityTypecategoryValueEnumMap = {
  0: AbnormalityCategory.process,
  1: AbnormalityCategory.equipment,
  2: AbnormalityCategory.resultQuality,
  3: AbnormalityCategory.reannealing,
  4: AbnormalityCategory.other,
};
const _AbnormalityTypeseverityEnumValueMap = {
  'low': 0,
  'medium': 1,
  'high': 2,
  'critical': 3,
};
const _AbnormalityTypeseverityValueEnumMap = {
  0: AbnormalitySeverity.low,
  1: AbnormalitySeverity.medium,
  2: AbnormalitySeverity.high,
  3: AbnormalitySeverity.critical,
};

Id _abnormalityTypeGetId(AbnormalityType object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _abnormalityTypeGetLinks(AbnormalityType object) {
  return [];
}

void _abnormalityTypeAttach(
    IsarCollection<dynamic> col, Id id, AbnormalityType object) {
  object.id = id;
}

extension AbnormalityTypeByIndex on IsarCollection<AbnormalityType> {
  Future<AbnormalityType?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  AbnormalityType? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<AbnormalityType?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<AbnormalityType?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(AbnormalityType object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(AbnormalityType object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<AbnormalityType> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<AbnormalityType> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension AbnormalityTypeQueryWhereSort
    on QueryBuilder<AbnormalityType, AbnormalityType, QWhere> {
  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhere> anyIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isActive'),
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhere> anyIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isDeleted'),
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension AbnormalityTypeQueryWhere
    on QueryBuilder<AbnormalityType, AbnormalityType, QWhereClause> {
  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause> idBetween(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause> codeEqualTo(
      String code) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'code',
        value: [code],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      codeNotEqualTo(String code) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'code',
              lower: [],
              upper: [code],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'code',
              lower: [code],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'code',
              lower: [code],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'code',
              lower: [],
              upper: [code],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      titleEqualTo(String title) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'title',
        value: [title],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      titleNotEqualTo(String title) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [],
              upper: [title],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [title],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [title],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [],
              upper: [title],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      isActiveEqualTo(bool isActive) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isActive',
        value: [isActive],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      isActiveNotEqualTo(bool isActive) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [],
              upper: [isActive],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [isActive],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [isActive],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isActive',
              lower: [],
              upper: [isActive],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      isDeletedEqualTo(bool isDeleted) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isDeleted',
        value: [isDeleted],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      isDeletedNotEqualTo(bool isDeleted) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [],
              upper: [isDeleted],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [isDeleted],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [isDeleted],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [],
              upper: [isDeleted],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
      updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterWhereClause>
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

extension AbnormalityTypeQueryFilter
    on QueryBuilder<AbnormalityType, AbnormalityType, QFilterCondition> {
  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'applicableAssetTypeIndexes',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'applicableAssetTypeIndexes',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'applicableAssetTypeIndexes',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'applicableAssetTypeIndexes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'applicableAssetTypeIndexes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'applicableAssetTypeIndexes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'applicableAssetTypeIndexes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'applicableAssetTypeIndexes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'applicableAssetTypeIndexes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      applicableAssetTypeIndexesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'applicableAssetTypeIndexes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      categoryEqualTo(AbnormalityCategory value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      categoryGreaterThan(
    AbnormalityCategory value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      categoryLessThan(
    AbnormalityCategory value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      categoryBetween(
    AbnormalityCategory lower,
    AbnormalityCategory upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'code',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'code',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'code',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      codeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'code',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastEditedByName',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastEditedByName',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEditedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastEditedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastEditedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastEditedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastEditedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastEditedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastEditedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastEditedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEditedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastEditedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastEditedByUid',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastEditedByUid',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEditedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastEditedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastEditedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastEditedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastEditedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastEditedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastEditedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastEditedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEditedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      lastEditedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastEditedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      severityEqualTo(AbnormalitySeverity value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'severity',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      severityGreaterThan(
    AbnormalitySeverity value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'severity',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      severityLessThan(
    AbnormalitySeverity value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'severity',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      severityBetween(
    AbnormalitySeverity lower,
    AbnormalitySeverity upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'severity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      suggestsReannealingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'suggestsReannealing',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleEqualTo(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleGreaterThan(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleLessThan(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleBetween(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleStartsWith(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleEndsWith(
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterFilterCondition>
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
}

extension AbnormalityTypeQueryObject
    on QueryBuilder<AbnormalityType, AbnormalityType, QFilterCondition> {}

extension AbnormalityTypeQueryLinks
    on QueryBuilder<AbnormalityType, AbnormalityType, QFilterCondition> {}

extension AbnormalityTypeQuerySortBy
    on QueryBuilder<AbnormalityType, AbnormalityType, QSortBy> {
  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> sortByCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByLastEditedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByName', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByLastEditedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByName', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByLastEditedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByUid', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByLastEditedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByUid', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortBySuggestsReannealing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestsReannealing', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortBySuggestsReannealingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestsReannealing', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension AbnormalityTypeQuerySortThenBy
    on QueryBuilder<AbnormalityType, AbnormalityType, QSortThenBy> {
  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> thenByCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByLastEditedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByName', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByLastEditedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByName', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByLastEditedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByUid', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByLastEditedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditedByUid', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenBySuggestsReannealing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestsReannealing', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenBySuggestsReannealingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestsReannealing', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension AbnormalityTypeQueryWhereDistinct
    on QueryBuilder<AbnormalityType, AbnormalityType, QDistinct> {
  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByApplicableAssetTypeIndexes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'applicableAssetTypeIndexes');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct> distinctByCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'code', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByCreatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByCreatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByLastEditedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastEditedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByLastEditedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastEditedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'severity');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctBySuggestsReannealing() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'suggestsReannealing');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityType, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension AbnormalityTypeQueryProperty
    on QueryBuilder<AbnormalityType, AbnormalityType, QQueryProperty> {
  QueryBuilder<AbnormalityType, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AbnormalityType, List<int>, QQueryOperations>
      applicableAssetTypeIndexesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'applicableAssetTypeIndexes');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalityCategory, QQueryOperations>
      categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<AbnormalityType, String, QQueryOperations> codeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'code');
    });
  }

  QueryBuilder<AbnormalityType, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<AbnormalityType, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<AbnormalityType, bool, QQueryOperations> isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<AbnormalityType, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<AbnormalityType, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      lastEditedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastEditedByName');
    });
  }

  QueryBuilder<AbnormalityType, String?, QQueryOperations>
      lastEditedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastEditedByUid');
    });
  }

  QueryBuilder<AbnormalityType, AbnormalitySeverity, QQueryOperations>
      severityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'severity');
    });
  }

  QueryBuilder<AbnormalityType, bool, QQueryOperations>
      suggestsReannealingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'suggestsReannealing');
    });
  }

  QueryBuilder<AbnormalityType, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<AbnormalityType, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<AbnormalityType, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChargeAbnormalityCollection on Isar {
  IsarCollection<ChargeAbnormality> get chargeAbnormalitys => this.collection();
}

const ChargeAbnormalitySchema = CollectionSchema(
  name: r'ChargeAbnormality',
  id: 4068838871833800476,
  properties: {
    r'abnormalityTypeCode': PropertySchema(
      id: 0,
      name: r'abnormalityTypeCode',
      type: IsarType.string,
    ),
    r'abnormalityTypeId': PropertySchema(
      id: 1,
      name: r'abnormalityTypeId',
      type: IsarType.string,
    ),
    r'abnormalityTypeTitle': PropertySchema(
      id: 2,
      name: r'abnormalityTypeTitle',
      type: IsarType.string,
    ),
    r'affectedAssetsJson': PropertySchema(
      id: 3,
      name: r'affectedAssetsJson',
      type: IsarType.string,
    ),
    r'category': PropertySchema(
      id: 4,
      name: r'category',
      type: IsarType.byte,
      enumMap: _ChargeAbnormalitycategoryEnumValueMap,
    ),
    r'component': PropertySchema(
      id: 5,
      name: r'component',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 6,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 7,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 8,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 9,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 10,
      name: r'description',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 11,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 12,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 13,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'linkedExecutionFirestoreId': PropertySchema(
      id: 14,
      name: r'linkedExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'linkedTicketFirestoreId': PropertySchema(
      id: 15,
      name: r'linkedTicketFirestoreId',
      type: IsarType.string,
    ),
    r'loggedAt': PropertySchema(
      id: 16,
      name: r'loggedAt',
      type: IsarType.dateTime,
    ),
    r'loggedByName': PropertySchema(
      id: 17,
      name: r'loggedByName',
      type: IsarType.string,
    ),
    r'loggedByUid': PropertySchema(
      id: 18,
      name: r'loggedByUid',
      type: IsarType.string,
    ),
    r'observedReason': PropertySchema(
      id: 19,
      name: r'observedReason',
      type: IsarType.string,
    ),
    r'possibleRootReasonCategory': PropertySchema(
      id: 20,
      name: r'possibleRootReasonCategory',
      type: IsarType.byte,
      enumMap: _ChargeAbnormalitypossibleRootReasonCategoryEnumValueMap,
    ),
    r'possibleRootReasonNotes': PropertySchema(
      id: 21,
      name: r'possibleRootReasonNotes',
      type: IsarType.string,
    ),
    r'reannealedToChargeNo': PropertySchema(
      id: 22,
      name: r'reannealedToChargeNo',
      type: IsarType.long,
    ),
    r'reannealingStatus': PropertySchema(
      id: 23,
      name: r'reannealingStatus',
      type: IsarType.byte,
      enumMap: _ChargeAbnormalityreannealingStatusEnumValueMap,
    ),
    r'severity': PropertySchema(
      id: 24,
      name: r'severity',
      type: IsarType.byte,
      enumMap: _ChargeAbnormalityseverityEnumValueMap,
    ),
    r'sourceChargeNo': PropertySchema(
      id: 25,
      name: r'sourceChargeNo',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 26,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 27,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 28,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 29,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _chargeAbnormalityEstimateSize,
  serialize: _chargeAbnormalitySerialize,
  deserialize: _chargeAbnormalityDeserialize,
  deserializeProp: _chargeAbnormalityDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'sourceChargeNo': IndexSchema(
      id: 161475910542428913,
      name: r'sourceChargeNo',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sourceChargeNo',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'abnormalityTypeId': IndexSchema(
      id: 7121084067232296849,
      name: r'abnormalityTypeId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'abnormalityTypeId',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'reannealedToChargeNo': IndexSchema(
      id: 8640027478758008908,
      name: r'reannealedToChargeNo',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'reannealedToChargeNo',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'loggedAt': IndexSchema(
      id: 1838198766103160564,
      name: r'loggedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'loggedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isDeleted': IndexSchema(
      id: -786475870904832312,
      name: r'isDeleted',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isDeleted',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chargeAbnormalityGetId,
  getLinks: _chargeAbnormalityGetLinks,
  attach: _chargeAbnormalityAttach,
  version: '3.1.0+1',
);

int _chargeAbnormalityEstimateSize(
  ChargeAbnormality object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.abnormalityTypeCode.length * 3;
  bytesCount += 3 + object.abnormalityTypeId.length * 3;
  bytesCount += 3 + object.abnormalityTypeTitle.length * 3;
  bytesCount += 3 + object.affectedAssetsJson.length * 3;
  {
    final value = object.component;
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
    final value = object.description;
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
    final value = object.linkedExecutionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.linkedTicketFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
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
  bytesCount += 3 + object.observedReason.length * 3;
  {
    final value = object.possibleRootReasonNotes;
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
  return bytesCount;
}

void _chargeAbnormalitySerialize(
  ChargeAbnormality object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.abnormalityTypeCode);
  writer.writeString(offsets[1], object.abnormalityTypeId);
  writer.writeString(offsets[2], object.abnormalityTypeTitle);
  writer.writeString(offsets[3], object.affectedAssetsJson);
  writer.writeByte(offsets[4], object.category.index);
  writer.writeString(offsets[5], object.component);
  writer.writeString(offsets[6], object.deleteReason);
  writer.writeDateTime(offsets[7], object.deletedAt);
  writer.writeString(offsets[8], object.deletedByName);
  writer.writeString(offsets[9], object.deletedByUid);
  writer.writeString(offsets[10], object.description);
  writer.writeString(offsets[11], object.firestoreId);
  writer.writeBool(offsets[12], object.isDeleted);
  writer.writeBool(offsets[13], object.isSynced);
  writer.writeString(offsets[14], object.linkedExecutionFirestoreId);
  writer.writeString(offsets[15], object.linkedTicketFirestoreId);
  writer.writeDateTime(offsets[16], object.loggedAt);
  writer.writeString(offsets[17], object.loggedByName);
  writer.writeString(offsets[18], object.loggedByUid);
  writer.writeString(offsets[19], object.observedReason);
  writer.writeByte(offsets[20], object.possibleRootReasonCategory.index);
  writer.writeString(offsets[21], object.possibleRootReasonNotes);
  writer.writeLong(offsets[22], object.reannealedToChargeNo);
  writer.writeByte(offsets[23], object.reannealingStatus.index);
  writer.writeByte(offsets[24], object.severity.index);
  writer.writeLong(offsets[25], object.sourceChargeNo);
  writer.writeDateTime(offsets[26], object.updatedAt);
  writer.writeString(offsets[27], object.updatedByName);
  writer.writeString(offsets[28], object.updatedByUid);
  writer.writeLong(offsets[29], object.version);
}

ChargeAbnormality _chargeAbnormalityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChargeAbnormality();
  object.abnormalityTypeCode = reader.readString(offsets[0]);
  object.abnormalityTypeId = reader.readString(offsets[1]);
  object.abnormalityTypeTitle = reader.readString(offsets[2]);
  object.affectedAssetsJson = reader.readString(offsets[3]);
  object.category = _ChargeAbnormalitycategoryValueEnumMap[
          reader.readByteOrNull(offsets[4])] ??
      AbnormalityCategory.process;
  object.component = reader.readStringOrNull(offsets[5]);
  object.deleteReason = reader.readStringOrNull(offsets[6]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[7]);
  object.deletedByName = reader.readStringOrNull(offsets[8]);
  object.deletedByUid = reader.readStringOrNull(offsets[9]);
  object.description = reader.readStringOrNull(offsets[10]);
  object.firestoreId = reader.readStringOrNull(offsets[11]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[12]);
  object.isSynced = reader.readBool(offsets[13]);
  object.linkedExecutionFirestoreId = reader.readStringOrNull(offsets[14]);
  object.linkedTicketFirestoreId = reader.readStringOrNull(offsets[15]);
  object.loggedAt = reader.readDateTime(offsets[16]);
  object.loggedByName = reader.readStringOrNull(offsets[17]);
  object.loggedByUid = reader.readStringOrNull(offsets[18]);
  object.observedReason = reader.readString(offsets[19]);
  object.possibleRootReasonCategory =
      _ChargeAbnormalitypossibleRootReasonCategoryValueEnumMap[
              reader.readByteOrNull(offsets[20])] ??
          RootReasonCategory.unknown;
  object.possibleRootReasonNotes = reader.readStringOrNull(offsets[21]);
  object.reannealedToChargeNo = reader.readLongOrNull(offsets[22]);
  object.reannealingStatus = _ChargeAbnormalityreannealingStatusValueEnumMap[
          reader.readByteOrNull(offsets[23])] ??
      ReannealingStatus.notApplicable;
  object.severity = _ChargeAbnormalityseverityValueEnumMap[
          reader.readByteOrNull(offsets[24])] ??
      AbnormalitySeverity.low;
  object.sourceChargeNo = reader.readLong(offsets[25]);
  object.updatedAt = reader.readDateTime(offsets[26]);
  object.updatedByName = reader.readStringOrNull(offsets[27]);
  object.updatedByUid = reader.readStringOrNull(offsets[28]);
  object.version = reader.readLong(offsets[29]);
  return object;
}

P _chargeAbnormalityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (_ChargeAbnormalitycategoryValueEnumMap[
              reader.readByteOrNull(offset)] ??
          AbnormalityCategory.process) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readDateTime(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (_ChargeAbnormalitypossibleRootReasonCategoryValueEnumMap[
              reader.readByteOrNull(offset)] ??
          RootReasonCategory.unknown) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readLongOrNull(offset)) as P;
    case 23:
      return (_ChargeAbnormalityreannealingStatusValueEnumMap[
              reader.readByteOrNull(offset)] ??
          ReannealingStatus.notApplicable) as P;
    case 24:
      return (_ChargeAbnormalityseverityValueEnumMap[
              reader.readByteOrNull(offset)] ??
          AbnormalitySeverity.low) as P;
    case 25:
      return (reader.readLong(offset)) as P;
    case 26:
      return (reader.readDateTime(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readStringOrNull(offset)) as P;
    case 29:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _ChargeAbnormalitycategoryEnumValueMap = {
  'process': 0,
  'equipment': 1,
  'resultQuality': 2,
  'reannealing': 3,
  'other': 4,
};
const _ChargeAbnormalitycategoryValueEnumMap = {
  0: AbnormalityCategory.process,
  1: AbnormalityCategory.equipment,
  2: AbnormalityCategory.resultQuality,
  3: AbnormalityCategory.reannealing,
  4: AbnormalityCategory.other,
};
const _ChargeAbnormalitypossibleRootReasonCategoryEnumValueMap = {
  'unknown': 0,
  'baseRelated': 1,
  'furnaceRelated': 2,
  'forceCoolerRelated': 3,
  'atmosphereRelated': 4,
  'thermocoupleTemperature': 5,
  'cycleInterruption': 6,
  'materialOrCoilCondition': 7,
  'operationsRelated': 8,
  'other': 9,
};
const _ChargeAbnormalitypossibleRootReasonCategoryValueEnumMap = {
  0: RootReasonCategory.unknown,
  1: RootReasonCategory.baseRelated,
  2: RootReasonCategory.furnaceRelated,
  3: RootReasonCategory.forceCoolerRelated,
  4: RootReasonCategory.atmosphereRelated,
  5: RootReasonCategory.thermocoupleTemperature,
  6: RootReasonCategory.cycleInterruption,
  7: RootReasonCategory.materialOrCoilCondition,
  8: RootReasonCategory.operationsRelated,
  9: RootReasonCategory.other,
};
const _ChargeAbnormalityreannealingStatusEnumValueMap = {
  'notApplicable': 0,
  'pendingDecision': 1,
  'required': 2,
  'notRequired': 3,
  'completed': 4,
};
const _ChargeAbnormalityreannealingStatusValueEnumMap = {
  0: ReannealingStatus.notApplicable,
  1: ReannealingStatus.pendingDecision,
  2: ReannealingStatus.required,
  3: ReannealingStatus.notRequired,
  4: ReannealingStatus.completed,
};
const _ChargeAbnormalityseverityEnumValueMap = {
  'low': 0,
  'medium': 1,
  'high': 2,
  'critical': 3,
};
const _ChargeAbnormalityseverityValueEnumMap = {
  0: AbnormalitySeverity.low,
  1: AbnormalitySeverity.medium,
  2: AbnormalitySeverity.high,
  3: AbnormalitySeverity.critical,
};

Id _chargeAbnormalityGetId(ChargeAbnormality object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chargeAbnormalityGetLinks(
    ChargeAbnormality object) {
  return [];
}

void _chargeAbnormalityAttach(
    IsarCollection<dynamic> col, Id id, ChargeAbnormality object) {
  object.id = id;
}

extension ChargeAbnormalityByIndex on IsarCollection<ChargeAbnormality> {
  Future<ChargeAbnormality?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  ChargeAbnormality? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<ChargeAbnormality?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<ChargeAbnormality?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(ChargeAbnormality object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(ChargeAbnormality object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<ChargeAbnormality> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<ChargeAbnormality> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension ChargeAbnormalityQueryWhereSort
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QWhere> {
  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhere>
      anySourceChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sourceChargeNo'),
      );
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhere>
      anyReannealedToChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'reannealedToChargeNo'),
      );
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhere>
      anyLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'loggedAt'),
      );
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhere>
      anyIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isDeleted'),
      );
    });
  }
}

extension ChargeAbnormalityQueryWhere
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QWhereClause> {
  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      sourceChargeNoEqualTo(int sourceChargeNo) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sourceChargeNo',
        value: [sourceChargeNo],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      sourceChargeNoNotEqualTo(int sourceChargeNo) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceChargeNo',
              lower: [],
              upper: [sourceChargeNo],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceChargeNo',
              lower: [sourceChargeNo],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceChargeNo',
              lower: [sourceChargeNo],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceChargeNo',
              lower: [],
              upper: [sourceChargeNo],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      sourceChargeNoGreaterThan(
    int sourceChargeNo, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceChargeNo',
        lower: [sourceChargeNo],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      sourceChargeNoLessThan(
    int sourceChargeNo, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceChargeNo',
        lower: [],
        upper: [sourceChargeNo],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      sourceChargeNoBetween(
    int lowerSourceChargeNo,
    int upperSourceChargeNo, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceChargeNo',
        lower: [lowerSourceChargeNo],
        includeLower: includeLower,
        upper: [upperSourceChargeNo],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      abnormalityTypeIdEqualTo(String abnormalityTypeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'abnormalityTypeId',
        value: [abnormalityTypeId],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      abnormalityTypeIdNotEqualTo(String abnormalityTypeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'abnormalityTypeId',
              lower: [],
              upper: [abnormalityTypeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'abnormalityTypeId',
              lower: [abnormalityTypeId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'abnormalityTypeId',
              lower: [abnormalityTypeId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'abnormalityTypeId',
              lower: [],
              upper: [abnormalityTypeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'reannealedToChargeNo',
        value: [null],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'reannealedToChargeNo',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoEqualTo(int? reannealedToChargeNo) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'reannealedToChargeNo',
        value: [reannealedToChargeNo],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoNotEqualTo(int? reannealedToChargeNo) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reannealedToChargeNo',
              lower: [],
              upper: [reannealedToChargeNo],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reannealedToChargeNo',
              lower: [reannealedToChargeNo],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reannealedToChargeNo',
              lower: [reannealedToChargeNo],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reannealedToChargeNo',
              lower: [],
              upper: [reannealedToChargeNo],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoGreaterThan(
    int? reannealedToChargeNo, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'reannealedToChargeNo',
        lower: [reannealedToChargeNo],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoLessThan(
    int? reannealedToChargeNo, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'reannealedToChargeNo',
        lower: [],
        upper: [reannealedToChargeNo],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      reannealedToChargeNoBetween(
    int? lowerReannealedToChargeNo,
    int? upperReannealedToChargeNo, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'reannealedToChargeNo',
        lower: [lowerReannealedToChargeNo],
        includeLower: includeLower,
        upper: [upperReannealedToChargeNo],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      loggedAtEqualTo(DateTime loggedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'loggedAt',
        value: [loggedAt],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      loggedAtNotEqualTo(DateTime loggedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedAt',
              lower: [],
              upper: [loggedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedAt',
              lower: [loggedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedAt',
              lower: [loggedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'loggedAt',
              lower: [],
              upper: [loggedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      loggedAtGreaterThan(
    DateTime loggedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'loggedAt',
        lower: [loggedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      loggedAtLessThan(
    DateTime loggedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'loggedAt',
        lower: [],
        upper: [loggedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      loggedAtBetween(
    DateTime lowerLoggedAt,
    DateTime upperLoggedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'loggedAt',
        lower: [lowerLoggedAt],
        includeLower: includeLower,
        upper: [upperLoggedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      isDeletedEqualTo(bool isDeleted) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isDeleted',
        value: [isDeleted],
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterWhereClause>
      isDeletedNotEqualTo(bool isDeleted) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [],
              upper: [isDeleted],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [isDeleted],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [isDeleted],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDeleted',
              lower: [],
              upper: [isDeleted],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChargeAbnormalityQueryFilter
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QFilterCondition> {
  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'abnormalityTypeCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'abnormalityTypeCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'abnormalityTypeCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'abnormalityTypeCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'abnormalityTypeCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'abnormalityTypeCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'abnormalityTypeCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'abnormalityTypeCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'abnormalityTypeCode',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'abnormalityTypeCode',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'abnormalityTypeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'abnormalityTypeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'abnormalityTypeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'abnormalityTypeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'abnormalityTypeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'abnormalityTypeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'abnormalityTypeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'abnormalityTypeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'abnormalityTypeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'abnormalityTypeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'abnormalityTypeTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'abnormalityTypeTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'abnormalityTypeTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'abnormalityTypeTitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'abnormalityTypeTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'abnormalityTypeTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'abnormalityTypeTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'abnormalityTypeTitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'abnormalityTypeTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      abnormalityTypeTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'abnormalityTypeTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'affectedAssetsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'affectedAssetsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'affectedAssetsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'affectedAssetsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'affectedAssetsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'affectedAssetsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'affectedAssetsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'affectedAssetsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'affectedAssetsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      affectedAssetsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'affectedAssetsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      categoryEqualTo(AbnormalityCategory value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      categoryGreaterThan(
    AbnormalityCategory value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      categoryLessThan(
    AbnormalityCategory value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      categoryBetween(
    AbnormalityCategory lower,
    AbnormalityCategory upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      componentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      componentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      componentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      componentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'component',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      componentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      componentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdEqualTo(
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdGreaterThan(
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdLessThan(
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdBetween(
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdStartsWith(
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdEndsWith(
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedTicketFirestoreId',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedTicketFirestoreId',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedTicketFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedTicketFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedTicketFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedTicketFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedTicketFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedTicketFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedTicketFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedTicketFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedTicketFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      linkedTicketFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedTicketFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'loggedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'loggedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'loggedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'loggedByName',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'loggedByName',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'loggedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'loggedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'loggedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'loggedByUid',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'loggedByUid',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'loggedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'loggedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loggedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      loggedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'loggedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'observedReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'observedReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'observedReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'observedReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'observedReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'observedReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'observedReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'observedReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'observedReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      observedReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'observedReason',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonCategoryEqualTo(RootReasonCategory value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'possibleRootReasonCategory',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonCategoryGreaterThan(
    RootReasonCategory value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'possibleRootReasonCategory',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonCategoryLessThan(
    RootReasonCategory value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'possibleRootReasonCategory',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonCategoryBetween(
    RootReasonCategory lower,
    RootReasonCategory upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'possibleRootReasonCategory',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'possibleRootReasonNotes',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'possibleRootReasonNotes',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'possibleRootReasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'possibleRootReasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'possibleRootReasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'possibleRootReasonNotes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'possibleRootReasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'possibleRootReasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'possibleRootReasonNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'possibleRootReasonNotes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'possibleRootReasonNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      possibleRootReasonNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'possibleRootReasonNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealedToChargeNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reannealedToChargeNo',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealedToChargeNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reannealedToChargeNo',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealedToChargeNoEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reannealedToChargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealedToChargeNoGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reannealedToChargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealedToChargeNoLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reannealedToChargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealedToChargeNoBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reannealedToChargeNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealingStatusEqualTo(ReannealingStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reannealingStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealingStatusGreaterThan(
    ReannealingStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reannealingStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealingStatusLessThan(
    ReannealingStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reannealingStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      reannealingStatusBetween(
    ReannealingStatus lower,
    ReannealingStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reannealingStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      severityEqualTo(AbnormalitySeverity value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'severity',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      severityGreaterThan(
    AbnormalitySeverity value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'severity',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      severityLessThan(
    AbnormalitySeverity value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'severity',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      severityBetween(
    AbnormalitySeverity lower,
    AbnormalitySeverity upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'severity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      sourceChargeNoEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceChargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      sourceChargeNoGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceChargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      sourceChargeNoLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceChargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      sourceChargeNoBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceChargeNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterFilterCondition>
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
}

extension ChargeAbnormalityQueryObject
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QFilterCondition> {}

extension ChargeAbnormalityQueryLinks
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QFilterCondition> {}

extension ChargeAbnormalityQuerySortBy
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QSortBy> {
  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAbnormalityTypeCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeCode', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAbnormalityTypeCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeCode', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAbnormalityTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAbnormalityTypeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAbnormalityTypeTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeTitle', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAbnormalityTypeTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeTitle', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAffectedAssetsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'affectedAssetsJson', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByAffectedAssetsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'affectedAssetsJson', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLinkedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLinkedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLinkedTicketFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedTicketFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLinkedTicketFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedTicketFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLoggedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLoggedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLoggedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLoggedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByLoggedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByObservedReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedReason', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByObservedReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedReason', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByPossibleRootReasonCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonCategory', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByPossibleRootReasonCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonCategory', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByPossibleRootReasonNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonNotes', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByPossibleRootReasonNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonNotes', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByReannealedToChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealedToChargeNo', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByReannealedToChargeNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealedToChargeNo', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByReannealingStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealingStatus', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByReannealingStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealingStatus', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortBySourceChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceChargeNo', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortBySourceChargeNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceChargeNo', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension ChargeAbnormalityQuerySortThenBy
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QSortThenBy> {
  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAbnormalityTypeCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeCode', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAbnormalityTypeCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeCode', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAbnormalityTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAbnormalityTypeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAbnormalityTypeTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeTitle', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAbnormalityTypeTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'abnormalityTypeTitle', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAffectedAssetsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'affectedAssetsJson', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByAffectedAssetsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'affectedAssetsJson', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLinkedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLinkedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLinkedTicketFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedTicketFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLinkedTicketFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedTicketFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLoggedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLoggedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLoggedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByName', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLoggedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByLoggedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedByUid', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByObservedReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedReason', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByObservedReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observedReason', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByPossibleRootReasonCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonCategory', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByPossibleRootReasonCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonCategory', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByPossibleRootReasonNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonNotes', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByPossibleRootReasonNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'possibleRootReasonNotes', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByReannealedToChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealedToChargeNo', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByReannealedToChargeNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealedToChargeNo', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByReannealingStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealingStatus', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByReannealingStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reannealingStatus', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenBySourceChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceChargeNo', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenBySourceChargeNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceChargeNo', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension ChargeAbnormalityQueryWhereDistinct
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct> {
  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByAbnormalityTypeCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'abnormalityTypeCode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByAbnormalityTypeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'abnormalityTypeId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByAbnormalityTypeTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'abnormalityTypeTitle',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByAffectedAssetsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'affectedAssetsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByComponent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'component', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByLinkedExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByLinkedTicketFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedTicketFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedAt');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByLoggedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByLoggedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByObservedReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'observedReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByPossibleRootReasonCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'possibleRootReasonCategory');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByPossibleRootReasonNotes({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'possibleRootReasonNotes',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByReannealedToChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reannealedToChargeNo');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByReannealingStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reannealingStatus');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'severity');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctBySourceChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceChargeNo');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByUpdatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByUpdatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChargeAbnormality, ChargeAbnormality, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension ChargeAbnormalityQueryProperty
    on QueryBuilder<ChargeAbnormality, ChargeAbnormality, QQueryProperty> {
  QueryBuilder<ChargeAbnormality, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChargeAbnormality, String, QQueryOperations>
      abnormalityTypeCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'abnormalityTypeCode');
    });
  }

  QueryBuilder<ChargeAbnormality, String, QQueryOperations>
      abnormalityTypeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'abnormalityTypeId');
    });
  }

  QueryBuilder<ChargeAbnormality, String, QQueryOperations>
      abnormalityTypeTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'abnormalityTypeTitle');
    });
  }

  QueryBuilder<ChargeAbnormality, String, QQueryOperations>
      affectedAssetsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'affectedAssetsJson');
    });
  }

  QueryBuilder<ChargeAbnormality, AbnormalityCategory, QQueryOperations>
      categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      componentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'component');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<ChargeAbnormality, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<ChargeAbnormality, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<ChargeAbnormality, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      linkedExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedExecutionFirestoreId');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      linkedTicketFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedTicketFirestoreId');
    });
  }

  QueryBuilder<ChargeAbnormality, DateTime, QQueryOperations>
      loggedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedAt');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      loggedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedByName');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      loggedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedByUid');
    });
  }

  QueryBuilder<ChargeAbnormality, String, QQueryOperations>
      observedReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'observedReason');
    });
  }

  QueryBuilder<ChargeAbnormality, RootReasonCategory, QQueryOperations>
      possibleRootReasonCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'possibleRootReasonCategory');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      possibleRootReasonNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'possibleRootReasonNotes');
    });
  }

  QueryBuilder<ChargeAbnormality, int?, QQueryOperations>
      reannealedToChargeNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reannealedToChargeNo');
    });
  }

  QueryBuilder<ChargeAbnormality, ReannealingStatus, QQueryOperations>
      reannealingStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reannealingStatus');
    });
  }

  QueryBuilder<ChargeAbnormality, AbnormalitySeverity, QQueryOperations>
      severityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'severity');
    });
  }

  QueryBuilder<ChargeAbnormality, int, QQueryOperations>
      sourceChargeNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceChargeNo');
    });
  }

  QueryBuilder<ChargeAbnormality, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<ChargeAbnormality, String?, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<ChargeAbnormality, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
