// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_status_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEquipmentStatusRecordCollection on Isar {
  IsarCollection<EquipmentStatusRecord> get equipmentStatusRecords =>
      this.collection();
}

const EquipmentStatusRecordSchema = CollectionSchema(
  name: r'EquipmentStatusRecord',
  id: -3643468819914659581,
  properties: {
    r'activeExecutionIdsJson': PropertySchema(
      id: 0,
      name: r'activeExecutionIdsJson',
      type: IsarType.string,
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
    r'availableSince': PropertySchema(
      id: 5,
      name: r'availableSince',
      type: IsarType.dateTime,
    ),
    r'awaitingPreparationCount': PropertySchema(
      id: 6,
      name: r'awaitingPreparationCount',
      type: IsarType.long,
    ),
    r'firestoreId': PropertySchema(
      id: 7,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'inServiceSince': PropertySchema(
      id: 8,
      name: r'inServiceSince',
      type: IsarType.dateTime,
    ),
    r'isSynced': PropertySchema(
      id: 9,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'lastTransitionAt': PropertySchema(
      id: 10,
      name: r'lastTransitionAt',
      type: IsarType.dateTime,
    ),
    r'lastTransitionByName': PropertySchema(
      id: 11,
      name: r'lastTransitionByName',
      type: IsarType.string,
    ),
    r'lastTransitionByUid': PropertySchema(
      id: 12,
      name: r'lastTransitionByUid',
      type: IsarType.string,
    ),
    r'metadataJson': PropertySchema(
      id: 13,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'openMaintenanceCount': PropertySchema(
      id: 14,
      name: r'openMaintenanceCount',
      type: IsarType.long,
    ),
    r'openRedCount': PropertySchema(
      id: 15,
      name: r'openRedCount',
      type: IsarType.long,
    ),
    r'previousStateKey': PropertySchema(
      id: 16,
      name: r'previousStateKey',
      type: IsarType.string,
    ),
    r'stateKey': PropertySchema(
      id: 17,
      name: r'stateKey',
      type: IsarType.string,
    ),
    r'transitionTrigger': PropertySchema(
      id: 18,
      name: r'transitionTrigger',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 19,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 20,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _equipmentStatusRecordEstimateSize,
  serialize: _equipmentStatusRecordSerialize,
  deserialize: _equipmentStatusRecordDeserialize,
  deserializeProp: _equipmentStatusRecordDeserializeProp,
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
  getId: _equipmentStatusRecordGetId,
  getLinks: _equipmentStatusRecordGetLinks,
  attach: _equipmentStatusRecordAttach,
  version: '3.1.0+1',
);

int _equipmentStatusRecordEstimateSize(
  EquipmentStatusRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.activeExecutionIdsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastTransitionByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastTransitionByUid;
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
  bytesCount += 3 + object.previousStateKey.length * 3;
  bytesCount += 3 + object.stateKey.length * 3;
  {
    final value = object.transitionTrigger;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _equipmentStatusRecordSerialize(
  EquipmentStatusRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activeExecutionIdsJson);
  writer.writeString(offsets[1], object.assetClassId);
  writer.writeString(offsets[2], object.assetInstanceId);
  writer.writeLong(offsets[3], object.assetNumber);
  writer.writeString(offsets[4], object.assetTypeKey);
  writer.writeDateTime(offsets[5], object.availableSince);
  writer.writeLong(offsets[6], object.awaitingPreparationCount);
  writer.writeString(offsets[7], object.firestoreId);
  writer.writeDateTime(offsets[8], object.inServiceSince);
  writer.writeBool(offsets[9], object.isSynced);
  writer.writeDateTime(offsets[10], object.lastTransitionAt);
  writer.writeString(offsets[11], object.lastTransitionByName);
  writer.writeString(offsets[12], object.lastTransitionByUid);
  writer.writeString(offsets[13], object.metadataJson);
  writer.writeLong(offsets[14], object.openMaintenanceCount);
  writer.writeLong(offsets[15], object.openRedCount);
  writer.writeString(offsets[16], object.previousStateKey);
  writer.writeString(offsets[17], object.stateKey);
  writer.writeString(offsets[18], object.transitionTrigger);
  writer.writeDateTime(offsets[19], object.updatedAt);
  writer.writeLong(offsets[20], object.version);
}

EquipmentStatusRecord _equipmentStatusRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EquipmentStatusRecord();
  object.activeExecutionIdsJson = reader.readStringOrNull(offsets[0]);
  object.assetClassId = reader.readStringOrNull(offsets[1]);
  object.assetInstanceId = reader.readStringOrNull(offsets[2]);
  object.assetNumber = reader.readLong(offsets[3]);
  object.assetTypeKey = reader.readString(offsets[4]);
  object.availableSince = reader.readDateTimeOrNull(offsets[5]);
  object.awaitingPreparationCount = reader.readLong(offsets[6]);
  object.firestoreId = reader.readStringOrNull(offsets[7]);
  object.id = id;
  object.inServiceSince = reader.readDateTimeOrNull(offsets[8]);
  object.isSynced = reader.readBool(offsets[9]);
  object.lastTransitionAt = reader.readDateTimeOrNull(offsets[10]);
  object.lastTransitionByName = reader.readStringOrNull(offsets[11]);
  object.lastTransitionByUid = reader.readStringOrNull(offsets[12]);
  object.metadataJson = reader.readStringOrNull(offsets[13]);
  object.openMaintenanceCount = reader.readLong(offsets[14]);
  object.openRedCount = reader.readLong(offsets[15]);
  object.previousStateKey = reader.readString(offsets[16]);
  object.stateKey = reader.readString(offsets[17]);
  object.transitionTrigger = reader.readStringOrNull(offsets[18]);
  object.updatedAt = reader.readDateTime(offsets[19]);
  object.version = reader.readLong(offsets[20]);
  return object;
}

P _equipmentStatusRecordDeserializeProp<P>(
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
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readDateTime(offset)) as P;
    case 20:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _equipmentStatusRecordGetId(EquipmentStatusRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _equipmentStatusRecordGetLinks(
    EquipmentStatusRecord object) {
  return [];
}

void _equipmentStatusRecordAttach(
    IsarCollection<dynamic> col, Id id, EquipmentStatusRecord object) {
  object.id = id;
}

extension EquipmentStatusRecordByIndex
    on IsarCollection<EquipmentStatusRecord> {
  Future<EquipmentStatusRecord?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  EquipmentStatusRecord? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<EquipmentStatusRecord?>> getAllByFirestoreId(
      List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<EquipmentStatusRecord?> getAllByFirestoreIdSync(
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

  Future<Id> putByFirestoreId(EquipmentStatusRecord object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(EquipmentStatusRecord object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<EquipmentStatusRecord> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<EquipmentStatusRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension EquipmentStatusRecordQueryWhereSort
    on QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QWhere> {
  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhere>
      anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }
}

extension EquipmentStatusRecordQueryWhere on QueryBuilder<EquipmentStatusRecord,
    EquipmentStatusRecord, QWhereClause> {
  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetTypeKeyEqualTo(String assetTypeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetTypeKey',
        value: [assetTypeKey],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetNumberNotEqualTo(int assetNumber) {
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetNumberGreaterThan(
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetNumberLessThan(
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetNumberBetween(
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetClassIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetClassId',
        value: [null],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetClassIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetClassId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetClassIdEqualTo(String? assetClassId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetClassId',
        value: [assetClassId],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetClassIdNotEqualTo(String? assetClassId) {
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetInstanceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetInstanceId',
        value: [null],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetInstanceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetInstanceId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetInstanceIdEqualTo(String? assetInstanceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetInstanceId',
        value: [assetInstanceId],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      assetInstanceIdNotEqualTo(String? assetInstanceId) {
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
      stateKeyEqualTo(String stateKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'stateKey',
        value: [stateKey],
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterWhereClause>
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

extension EquipmentStatusRecordQueryFilter on QueryBuilder<
    EquipmentStatusRecord, EquipmentStatusRecord, QFilterCondition> {
  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'activeExecutionIdsJson',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'activeExecutionIdsJson',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeExecutionIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'activeExecutionIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'activeExecutionIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'activeExecutionIdsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'activeExecutionIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'activeExecutionIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      activeExecutionIdsJsonContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'activeExecutionIdsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      activeExecutionIdsJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'activeExecutionIdsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeExecutionIdsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> activeExecutionIdsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'activeExecutionIdsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetClassIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetClassId',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetClassIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetClassId',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetClassIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetClassId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetClassIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetClassId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetInstanceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetInstanceId',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetInstanceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetInstanceId',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetInstanceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetInstanceId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetInstanceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetInstanceId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetTypeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> assetTypeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetTypeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> availableSinceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'availableSince',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> availableSinceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'availableSince',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> availableSinceEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'availableSince',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> availableSinceGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'availableSince',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> availableSinceLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'availableSince',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> availableSinceBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'availableSince',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> awaitingPreparationCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'awaitingPreparationCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> awaitingPreparationCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'awaitingPreparationCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> awaitingPreparationCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'awaitingPreparationCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> awaitingPreparationCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'awaitingPreparationCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> inServiceSinceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'inServiceSince',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> inServiceSinceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'inServiceSince',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> inServiceSinceEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'inServiceSince',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> inServiceSinceGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'inServiceSince',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> inServiceSinceLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'inServiceSince',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> inServiceSinceBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'inServiceSince',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastTransitionAt',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastTransitionAt',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastTransitionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastTransitionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastTransitionAt',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastTransitionAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastTransitionByName',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastTransitionByName',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastTransitionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastTransitionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastTransitionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastTransitionByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastTransitionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastTransitionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      lastTransitionByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastTransitionByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      lastTransitionByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastTransitionByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastTransitionByName',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastTransitionByName',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastTransitionByUid',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastTransitionByUid',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastTransitionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastTransitionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastTransitionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastTransitionByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastTransitionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastTransitionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      lastTransitionByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastTransitionByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      lastTransitionByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastTransitionByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastTransitionByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> lastTransitionByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastTransitionByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openMaintenanceCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openMaintenanceCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openMaintenanceCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openMaintenanceCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openMaintenanceCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openMaintenanceCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openMaintenanceCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openMaintenanceCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openRedCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openRedCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openRedCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openRedCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openRedCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openRedCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> openRedCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openRedCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'previousStateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'previousStateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'previousStateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'previousStateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'previousStateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'previousStateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      previousStateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'previousStateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      previousStateKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'previousStateKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'previousStateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> previousStateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'previousStateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> stateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> stateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'stateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'transitionTrigger',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'transitionTrigger',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'transitionTrigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'transitionTrigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'transitionTrigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'transitionTrigger',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'transitionTrigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'transitionTrigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      transitionTriggerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'transitionTrigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
          QAfterFilterCondition>
      transitionTriggerMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'transitionTrigger',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'transitionTrigger',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> transitionTriggerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'transitionTrigger',
        value: '',
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord,
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

extension EquipmentStatusRecordQueryObject on QueryBuilder<
    EquipmentStatusRecord, EquipmentStatusRecord, QFilterCondition> {}

extension EquipmentStatusRecordQueryLinks on QueryBuilder<EquipmentStatusRecord,
    EquipmentStatusRecord, QFilterCondition> {}

extension EquipmentStatusRecordQuerySortBy
    on QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QSortBy> {
  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByActiveExecutionIdsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeExecutionIdsJson', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByActiveExecutionIdsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeExecutionIdsJson', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetClassId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetClassIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetInstanceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetInstanceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAvailableSince() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableSince', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAvailableSinceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableSince', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAwaitingPreparationCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparationCount', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByAwaitingPreparationCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparationCount', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByInServiceSince() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inServiceSince', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByInServiceSinceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inServiceSince', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByLastTransitionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByLastTransitionAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByLastTransitionByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByName', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByLastTransitionByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByName', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByLastTransitionByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByUid', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByLastTransitionByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByUid', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByOpenMaintenanceCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openMaintenanceCount', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByOpenMaintenanceCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openMaintenanceCount', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByOpenRedCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openRedCount', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByOpenRedCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openRedCount', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByPreviousStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousStateKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByPreviousStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousStateKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByTransitionTrigger() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transitionTrigger', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByTransitionTriggerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transitionTrigger', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension EquipmentStatusRecordQuerySortThenBy
    on QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QSortThenBy> {
  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByActiveExecutionIdsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeExecutionIdsJson', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByActiveExecutionIdsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeExecutionIdsJson', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetClassId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetClassIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetClassId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetInstanceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetInstanceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetInstanceId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetTypeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAssetTypeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetTypeKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAvailableSince() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableSince', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAvailableSinceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'availableSince', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAwaitingPreparationCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparationCount', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByAwaitingPreparationCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'awaitingPreparationCount', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByInServiceSince() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inServiceSince', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByInServiceSinceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inServiceSince', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByLastTransitionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByLastTransitionAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByLastTransitionByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByName', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByLastTransitionByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByName', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByLastTransitionByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByUid', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByLastTransitionByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastTransitionByUid', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByOpenMaintenanceCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openMaintenanceCount', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByOpenMaintenanceCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openMaintenanceCount', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByOpenRedCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openRedCount', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByOpenRedCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openRedCount', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByPreviousStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousStateKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByPreviousStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousStateKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByTransitionTrigger() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transitionTrigger', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByTransitionTriggerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transitionTrigger', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension EquipmentStatusRecordQueryWhereDistinct
    on QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct> {
  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByActiveExecutionIdsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activeExecutionIdsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByAssetClassId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetClassId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByAssetInstanceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetInstanceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByAssetTypeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetTypeKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByAvailableSince() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'availableSince');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByAwaitingPreparationCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'awaitingPreparationCount');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByInServiceSince() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inServiceSince');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByLastTransitionAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastTransitionAt');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByLastTransitionByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastTransitionByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByLastTransitionByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastTransitionByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByOpenMaintenanceCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openMaintenanceCount');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByOpenRedCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openRedCount');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByPreviousStateKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'previousStateKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByStateKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByTransitionTrigger({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'transitionTrigger',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<EquipmentStatusRecord, EquipmentStatusRecord, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension EquipmentStatusRecordQueryProperty on QueryBuilder<
    EquipmentStatusRecord, EquipmentStatusRecord, QQueryProperty> {
  QueryBuilder<EquipmentStatusRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      activeExecutionIdsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activeExecutionIdsJson');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      assetClassIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetClassId');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      assetInstanceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetInstanceId');
    });
  }

  QueryBuilder<EquipmentStatusRecord, int, QQueryOperations>
      assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String, QQueryOperations>
      assetTypeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetTypeKey');
    });
  }

  QueryBuilder<EquipmentStatusRecord, DateTime?, QQueryOperations>
      availableSinceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'availableSince');
    });
  }

  QueryBuilder<EquipmentStatusRecord, int, QQueryOperations>
      awaitingPreparationCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'awaitingPreparationCount');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<EquipmentStatusRecord, DateTime?, QQueryOperations>
      inServiceSinceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inServiceSince');
    });
  }

  QueryBuilder<EquipmentStatusRecord, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<EquipmentStatusRecord, DateTime?, QQueryOperations>
      lastTransitionAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastTransitionAt');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      lastTransitionByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastTransitionByName');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      lastTransitionByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastTransitionByUid');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<EquipmentStatusRecord, int, QQueryOperations>
      openMaintenanceCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openMaintenanceCount');
    });
  }

  QueryBuilder<EquipmentStatusRecord, int, QQueryOperations>
      openRedCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openRedCount');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String, QQueryOperations>
      previousStateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'previousStateKey');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String, QQueryOperations>
      stateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateKey');
    });
  }

  QueryBuilder<EquipmentStatusRecord, String?, QQueryOperations>
      transitionTriggerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transitionTrigger');
    });
  }

  QueryBuilder<EquipmentStatusRecord, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<EquipmentStatusRecord, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
