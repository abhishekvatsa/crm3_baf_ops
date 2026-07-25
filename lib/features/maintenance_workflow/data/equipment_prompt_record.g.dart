// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_prompt_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEquipmentPromptRecordCollection on Isar {
  IsarCollection<EquipmentPromptRecord> get equipmentPromptRecords =>
      this.collection();
}

const EquipmentPromptRecordSchema = CollectionSchema(
  name: r'EquipmentPromptRecord',
  id: 8988375989586032090,
  properties: {
    r'active': PropertySchema(
      id: 0,
      name: r'active',
      type: IsarType.bool,
    ),
    r'appliesWhenLaneKey': PropertySchema(
      id: 1,
      name: r'appliesWhenLaneKey',
      type: IsarType.string,
    ),
    r'assetTypeKey': PropertySchema(
      id: 2,
      name: r'assetTypeKey',
      type: IsarType.string,
    ),
    r'complianceTargetLaneKey': PropertySchema(
      id: 3,
      name: r'complianceTargetLaneKey',
      type: IsarType.string,
    ),
    r'complianceTitleTemplate': PropertySchema(
      id: 4,
      name: r'complianceTitleTemplate',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 5,
      name: r'createdAt',
      type: IsarType.dateTime,
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
    r'metadataJson': PropertySchema(
      id: 8,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'promptKey': PropertySchema(
      id: 9,
      name: r'promptKey',
      type: IsarType.string,
    ),
    r'promptTypeKey': PropertySchema(
      id: 10,
      name: r'promptTypeKey',
      type: IsarType.string,
    ),
    r'question': PropertySchema(
      id: 11,
      name: r'question',
      type: IsarType.string,
    ),
    r'successorTemplateContentHash': PropertySchema(
      id: 12,
      name: r'successorTemplateContentHash',
      type: IsarType.string,
    ),
    r'successorTemplatePackageId': PropertySchema(
      id: 13,
      name: r'successorTemplatePackageId',
      type: IsarType.string,
    ),
    r'successorTemplateVersionId': PropertySchema(
      id: 14,
      name: r'successorTemplateVersionId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 15,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 16,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _equipmentPromptRecordEstimateSize,
  serialize: _equipmentPromptRecordSerialize,
  deserialize: _equipmentPromptRecordDeserialize,
  deserializeProp: _equipmentPromptRecordDeserializeProp,
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
    r'promptKey': IndexSchema(
      id: 8758523191915280328,
      name: r'promptKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'promptKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _equipmentPromptRecordGetId,
  getLinks: _equipmentPromptRecordGetLinks,
  attach: _equipmentPromptRecordAttach,
  version: '3.1.0+1',
);

int _equipmentPromptRecordEstimateSize(
  EquipmentPromptRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.appliesWhenLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.assetTypeKey.length * 3;
  {
    final value = object.complianceTargetLaneKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.complianceTitleTemplate;
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
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.promptKey.length * 3;
  bytesCount += 3 + object.promptTypeKey.length * 3;
  {
    final value = object.question;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.successorTemplateContentHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.successorTemplatePackageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.successorTemplateVersionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _equipmentPromptRecordSerialize(
  EquipmentPromptRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.active);
  writer.writeString(offsets[1], object.appliesWhenLaneKey);
  writer.writeString(offsets[2], object.assetTypeKey);
  writer.writeString(offsets[3], object.complianceTargetLaneKey);
  writer.writeString(offsets[4], object.complianceTitleTemplate);
  writer.writeDateTime(offsets[5], object.createdAt);
  writer.writeString(offsets[6], object.firestoreId);
  writer.writeBool(offsets[7], object.isSynced);
  writer.writeString(offsets[8], object.metadataJson);
  writer.writeString(offsets[9], object.promptKey);
  writer.writeString(offsets[10], object.promptTypeKey);
  writer.writeString(offsets[11], object.question);
  writer.writeString(offsets[12], object.successorTemplateContentHash);
  writer.writeString(offsets[13], object.successorTemplatePackageId);
  writer.writeString(offsets[14], object.successorTemplateVersionId);
  writer.writeDateTime(offsets[15], object.updatedAt);
  writer.writeLong(offsets[16], object.version);
}

EquipmentPromptRecord _equipmentPromptRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EquipmentPromptRecord();
  object.active = reader.readBool(offsets[0]);
  object.appliesWhenLaneKey = reader.readStringOrNull(offsets[1]);
  object.assetTypeKey = reader.readString(offsets[2]);
  object.complianceTargetLaneKey = reader.readStringOrNull(offsets[3]);
  object.complianceTitleTemplate = reader.readStringOrNull(offsets[4]);
  object.createdAt = reader.readDateTime(offsets[5]);
  object.firestoreId = reader.readStringOrNull(offsets[6]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[7]);
  object.metadataJson = reader.readStringOrNull(offsets[8]);
  object.promptKey = reader.readString(offsets[9]);
  object.promptTypeKey = reader.readString(offsets[10]);
  object.question = reader.readStringOrNull(offsets[11]);
  object.successorTemplateContentHash = reader.readStringOrNull(offsets[12]);
  object.successorTemplatePackageId = reader.readStringOrNull(offsets[13]);
  object.successorTemplateVersionId = reader.readStringOrNull(offsets[14]);
  object.updatedAt = reader.readDateTime(offsets[15]);
  object.version = reader.readLong(offsets[16]);
  return object;
}

P _equipmentPromptRecordDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readDateTime(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _equipmentPromptRecordGetId(EquipmentPromptRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _equipmentPromptRecordGetLinks(
    EquipmentPromptRecord object) {
  return [];
}

void _equipmentPromptRecordAttach(
    IsarCollection<dynamic> col, Id id, EquipmentPromptRecord object) {
  object.id = id;
}

extension EquipmentPromptRecordByIndex
    on IsarCollection<EquipmentPromptRecord> {
  Future<EquipmentPromptRecord?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  EquipmentPromptRecord? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<EquipmentPromptRecord?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<EquipmentPromptRecord?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(EquipmentPromptRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(EquipmentPromptRecord object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<EquipmentPromptRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<EquipmentPromptRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension EquipmentPromptRecordQueryWhereSort
    on QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QWhere> {
  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }
}

extension EquipmentPromptRecordQueryWhere on QueryBuilder<EquipmentPromptRecord,
    EquipmentPromptRecord, QWhereClause> {
  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      assetTypeKeyEqualTo(String assetTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetTypeKey',
        value: [assetTypeKey],
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      promptKeyEqualTo(String promptKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'promptKey',
        value: [promptKey],
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterWhereClause>
      promptKeyNotEqualTo(String promptKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'promptKey',
              lower: [],
              upper: [promptKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'promptKey',
              lower: [promptKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'promptKey',
              lower: [promptKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'promptKey',
              lower: [],
              upper: [promptKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension EquipmentPromptRecordQueryFilter on QueryBuilder<
    EquipmentPromptRecord, EquipmentPromptRecord, QFilterCondition> {
  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> activeEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'active',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'appliesWhenLaneKey',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'appliesWhenLaneKey',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appliesWhenLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appliesWhenLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appliesWhenLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appliesWhenLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'appliesWhenLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'appliesWhenLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      appliesWhenLaneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'appliesWhenLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      appliesWhenLaneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'appliesWhenLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appliesWhenLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> appliesWhenLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'appliesWhenLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> assetTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> assetTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'complianceTargetLaneKey',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'complianceTargetLaneKey',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'complianceTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'complianceTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'complianceTargetLaneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'complianceTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'complianceTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      complianceTargetLaneKeyContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'complianceTargetLaneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      complianceTargetLaneKeyMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'complianceTargetLaneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceTargetLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTargetLaneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'complianceTargetLaneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'complianceTitleTemplate',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'complianceTitleTemplate',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceTitleTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'complianceTitleTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'complianceTitleTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'complianceTitleTemplate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'complianceTitleTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'complianceTitleTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      complianceTitleTemplateContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'complianceTitleTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      complianceTitleTemplateMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'complianceTitleTemplate',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'complianceTitleTemplate',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> complianceTitleTemplateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'complianceTitleTemplate',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'promptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'promptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'promptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'promptKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'promptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'promptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      promptKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'promptKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      promptKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'promptKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'promptKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'promptKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'promptTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'promptTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'promptTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'promptTypeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'promptTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'promptTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      promptTypeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'promptTypeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      promptTypeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'promptTypeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'promptTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> promptTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'promptTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'question',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'question',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'question',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      questionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      questionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'question',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'question',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> questionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'question',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'successorTemplateContentHash',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'successorTemplateContentHash',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'successorTemplateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'successorTemplateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'successorTemplateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'successorTemplateContentHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'successorTemplateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'successorTemplateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      successorTemplateContentHashContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'successorTemplateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      successorTemplateContentHashMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'successorTemplateContentHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'successorTemplateContentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateContentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'successorTemplateContentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'successorTemplatePackageId',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'successorTemplatePackageId',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'successorTemplatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'successorTemplatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'successorTemplatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'successorTemplatePackageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'successorTemplatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'successorTemplatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      successorTemplatePackageIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'successorTemplatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      successorTemplatePackageIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'successorTemplatePackageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'successorTemplatePackageId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplatePackageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'successorTemplatePackageId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'successorTemplateVersionId',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'successorTemplateVersionId',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'successorTemplateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'successorTemplateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'successorTemplateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'successorTemplateVersionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'successorTemplateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'successorTemplateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      successorTemplateVersionIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'successorTemplateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
          QAfterFilterCondition>
      successorTemplateVersionIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'successorTemplateVersionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'successorTemplateVersionId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> successorTemplateVersionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'successorTemplateVersionId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord,
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

extension EquipmentPromptRecordQueryObject on QueryBuilder<
    EquipmentPromptRecord, EquipmentPromptRecord, QFilterCondition> {}

extension EquipmentPromptRecordQueryLinks on QueryBuilder<EquipmentPromptRecord,
    EquipmentPromptRecord, QFilterCondition> {}

extension EquipmentPromptRecordQuerySortBy
    on QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QSortBy> {
  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByAppliesWhenLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliesWhenLaneKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByAppliesWhenLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliesWhenLaneKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByComplianceTargetLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTargetLaneKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByComplianceTargetLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTargetLaneKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByComplianceTitleTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTitleTemplate', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByComplianceTitleTemplateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTitleTemplate', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByPromptKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByPromptKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByPromptTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptTypeKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByPromptTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptTypeKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByQuestion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'question', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByQuestionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'question', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortBySuccessorTemplateContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateContentHash', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortBySuccessorTemplateContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateContentHash', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortBySuccessorTemplatePackageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplatePackageId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortBySuccessorTemplatePackageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplatePackageId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortBySuccessorTemplateVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateVersionId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortBySuccessorTemplateVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateVersionId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension EquipmentPromptRecordQuerySortThenBy
    on QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QSortThenBy> {
  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'active', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByAppliesWhenLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliesWhenLaneKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByAppliesWhenLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliesWhenLaneKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByComplianceTargetLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTargetLaneKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByComplianceTargetLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTargetLaneKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByComplianceTitleTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTitleTemplate', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByComplianceTitleTemplateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'complianceTitleTemplate', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByPromptKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByPromptKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByPromptTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptTypeKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByPromptTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'promptTypeKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByQuestion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'question', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByQuestionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'question', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenBySuccessorTemplateContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateContentHash', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenBySuccessorTemplateContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateContentHash', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenBySuccessorTemplatePackageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplatePackageId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenBySuccessorTemplatePackageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplatePackageId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenBySuccessorTemplateVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateVersionId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenBySuccessorTemplateVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'successorTemplateVersionId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension EquipmentPromptRecordQueryWhereDistinct
    on QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct> {
  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'active');
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByAppliesWhenLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appliesWhenLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByAssetTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetTypeKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByComplianceTargetLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'complianceTargetLaneKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByComplianceTitleTemplate({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'complianceTitleTemplate',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByPromptKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'promptKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByPromptTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'promptTypeKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByQuestion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'question', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctBySuccessorTemplateContentHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'successorTemplateContentHash',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctBySuccessorTemplatePackageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'successorTemplatePackageId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctBySuccessorTemplateVersionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'successorTemplateVersionId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<EquipmentPromptRecord, EquipmentPromptRecord, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension EquipmentPromptRecordQueryProperty on QueryBuilder<
    EquipmentPromptRecord, EquipmentPromptRecord, QQueryProperty> {
  QueryBuilder<EquipmentPromptRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EquipmentPromptRecord, bool, QQueryOperations> activeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'active');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      appliesWhenLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appliesWhenLaneKey');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String, QQueryOperations>
      assetTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetTypeKey');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      complianceTargetLaneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'complianceTargetLaneKey');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      complianceTitleTemplateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'complianceTitleTemplate');
    });
  }

  QueryBuilder<EquipmentPromptRecord, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<EquipmentPromptRecord, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String, QQueryOperations>
      promptKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'promptKey');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String, QQueryOperations>
      promptTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'promptTypeKey');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      questionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'question');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      successorTemplateContentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'successorTemplateContentHash');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      successorTemplatePackageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'successorTemplatePackageId');
    });
  }

  QueryBuilder<EquipmentPromptRecord, String?, QQueryOperations>
      successorTemplateVersionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'successorTemplateVersionId');
    });
  }

  QueryBuilder<EquipmentPromptRecord, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<EquipmentPromptRecord, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
