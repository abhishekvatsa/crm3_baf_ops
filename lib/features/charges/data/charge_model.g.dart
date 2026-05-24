// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'charge_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChargeCollection on Isar {
  IsarCollection<Charge> get charges => this.collection();
}

const ChargeSchema = CollectionSchema(
  name: r'Charge',
  id: 1755725158846388127,
  properties: {
    r'baseNo': PropertySchema(
      id: 0,
      name: r'baseNo',
      type: IsarType.long,
    ),
    r'buildMode': PropertySchema(
      id: 1,
      name: r'buildMode',
      type: IsarType.string,
      enumMap: _ChargebuildModeEnumValueMap,
    ),
    r'builtDate': PropertySchema(
      id: 2,
      name: r'builtDate',
      type: IsarType.dateTime,
    ),
    r'chargeNo': PropertySchema(
      id: 3,
      name: r'chargeNo',
      type: IsarType.long,
    ),
    r'coilsInBase': PropertySchema(
      id: 4,
      name: r'coilsInBase',
      type: IsarType.long,
    ),
    r'coldDate': PropertySchema(
      id: 5,
      name: r'coldDate',
      type: IsarType.dateTime,
    ),
    r'coolDate': PropertySchema(
      id: 6,
      name: r'coolDate',
      type: IsarType.dateTime,
    ),
    r'createdAt': PropertySchema(
      id: 7,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'cycleType': PropertySchema(
      id: 8,
      name: r'cycleType',
      type: IsarType.string,
    ),
    r'fireDate': PropertySchema(
      id: 9,
      name: r'fireDate',
      type: IsarType.dateTime,
    ),
    r'firestoreId': PropertySchema(
      id: 10,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'forceCoolerNo': PropertySchema(
      id: 11,
      name: r'forceCoolerNo',
      type: IsarType.long,
    ),
    r'furnaceNo': PropertySchema(
      id: 12,
      name: r'furnaceNo',
      type: IsarType.long,
    ),
    r'hasAbnormal': PropertySchema(
      id: 13,
      name: r'hasAbnormal',
      type: IsarType.bool,
    ),
    r'heatNo': PropertySchema(
      id: 14,
      name: r'heatNo',
      type: IsarType.long,
    ),
    r'innerCoverNo': PropertySchema(
      id: 15,
      name: r'innerCoverNo',
      type: IsarType.long,
    ),
    r'isSynced': PropertySchema(
      id: 16,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'loadedDate': PropertySchema(
      id: 17,
      name: r'loadedDate',
      type: IsarType.dateTime,
    ),
    r'numberOfCoils': PropertySchema(
      id: 18,
      name: r'numberOfCoils',
      type: IsarType.long,
    ),
    r'offDate': PropertySchema(
      id: 19,
      name: r'offDate',
      type: IsarType.dateTime,
    ),
    r'predCoolTime': PropertySchema(
      id: 20,
      name: r'predCoolTime',
      type: IsarType.long,
    ),
    r'predHeatTime': PropertySchema(
      id: 21,
      name: r'predHeatTime',
      type: IsarType.long,
    ),
    r'purgeDate': PropertySchema(
      id: 22,
      name: r'purgeDate',
      type: IsarType.dateTime,
    ),
    r'rawTelemetry': PropertySchema(
      id: 23,
      name: r'rawTelemetry',
      type: IsarType.string,
    ),
    r'revCoolTime': PropertySchema(
      id: 24,
      name: r'revCoolTime',
      type: IsarType.long,
    ),
    r'revHeatTime': PropertySchema(
      id: 25,
      name: r'revHeatTime',
      type: IsarType.long,
    ),
    r'standbyDate': PropertySchema(
      id: 26,
      name: r'standbyDate',
      type: IsarType.dateTime,
    ),
    r'status': PropertySchema(
      id: 27,
      name: r'status',
      type: IsarType.string,
      enumMap: _ChargestatusEnumValueMap,
    ),
    r'unloadedDate': PropertySchema(
      id: 28,
      name: r'unloadedDate',
      type: IsarType.dateTime,
    ),
    r'updatedAt': PropertySchema(
      id: 29,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedBy': PropertySchema(
      id: 30,
      name: r'updatedBy',
      type: IsarType.string,
    ),
    r'updatedDate': PropertySchema(
      id: 31,
      name: r'updatedDate',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _chargeEstimateSize,
  serialize: _chargeSerialize,
  deserialize: _chargeDeserialize,
  deserializeProp: _chargeDeserializeProp,
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
    r'chargeNo': IndexSchema(
      id: 5518030252574082299,
      name: r'chargeNo',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'chargeNo',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chargeGetId,
  getLinks: _chargeGetLinks,
  attach: _chargeAttach,
  version: '3.1.0+1',
);

int _chargeEstimateSize(
  Charge object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.buildMode.name.length * 3;
  {
    final value = object.cycleType;
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
  bytesCount += 3 + object.rawTelemetry.length * 3;
  bytesCount += 3 + object.status.name.length * 3;
  {
    final value = object.updatedBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _chargeSerialize(
  Charge object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.baseNo);
  writer.writeString(offsets[1], object.buildMode.name);
  writer.writeDateTime(offsets[2], object.builtDate);
  writer.writeLong(offsets[3], object.chargeNo);
  writer.writeLong(offsets[4], object.coilsInBase);
  writer.writeDateTime(offsets[5], object.coldDate);
  writer.writeDateTime(offsets[6], object.coolDate);
  writer.writeDateTime(offsets[7], object.createdAt);
  writer.writeString(offsets[8], object.cycleType);
  writer.writeDateTime(offsets[9], object.fireDate);
  writer.writeString(offsets[10], object.firestoreId);
  writer.writeLong(offsets[11], object.forceCoolerNo);
  writer.writeLong(offsets[12], object.furnaceNo);
  writer.writeBool(offsets[13], object.hasAbnormal);
  writer.writeLong(offsets[14], object.heatNo);
  writer.writeLong(offsets[15], object.innerCoverNo);
  writer.writeBool(offsets[16], object.isSynced);
  writer.writeDateTime(offsets[17], object.loadedDate);
  writer.writeLong(offsets[18], object.numberOfCoils);
  writer.writeDateTime(offsets[19], object.offDate);
  writer.writeLong(offsets[20], object.predCoolTime);
  writer.writeLong(offsets[21], object.predHeatTime);
  writer.writeDateTime(offsets[22], object.purgeDate);
  writer.writeString(offsets[23], object.rawTelemetry);
  writer.writeLong(offsets[24], object.revCoolTime);
  writer.writeLong(offsets[25], object.revHeatTime);
  writer.writeDateTime(offsets[26], object.standbyDate);
  writer.writeString(offsets[27], object.status.name);
  writer.writeDateTime(offsets[28], object.unloadedDate);
  writer.writeDateTime(offsets[29], object.updatedAt);
  writer.writeString(offsets[30], object.updatedBy);
  writer.writeDateTime(offsets[31], object.updatedDate);
}

Charge _chargeDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Charge();
  object.baseNo = reader.readLongOrNull(offsets[0]);
  object.buildMode =
      _ChargebuildModeValueEnumMap[reader.readStringOrNull(offsets[1])] ??
          BuildMode.manual;
  object.builtDate = reader.readDateTimeOrNull(offsets[2]);
  object.chargeNo = reader.readLong(offsets[3]);
  object.coilsInBase = reader.readLongOrNull(offsets[4]);
  object.coldDate = reader.readDateTimeOrNull(offsets[5]);
  object.coolDate = reader.readDateTimeOrNull(offsets[6]);
  object.createdAt = reader.readDateTime(offsets[7]);
  object.cycleType = reader.readStringOrNull(offsets[8]);
  object.fireDate = reader.readDateTimeOrNull(offsets[9]);
  object.firestoreId = reader.readStringOrNull(offsets[10]);
  object.forceCoolerNo = reader.readLongOrNull(offsets[11]);
  object.furnaceNo = reader.readLongOrNull(offsets[12]);
  object.hasAbnormal = reader.readBool(offsets[13]);
  object.heatNo = reader.readLongOrNull(offsets[14]);
  object.id = id;
  object.innerCoverNo = reader.readLongOrNull(offsets[15]);
  object.isSynced = reader.readBool(offsets[16]);
  object.loadedDate = reader.readDateTimeOrNull(offsets[17]);
  object.numberOfCoils = reader.readLongOrNull(offsets[18]);
  object.offDate = reader.readDateTimeOrNull(offsets[19]);
  object.predCoolTime = reader.readLongOrNull(offsets[20]);
  object.predHeatTime = reader.readLongOrNull(offsets[21]);
  object.purgeDate = reader.readDateTimeOrNull(offsets[22]);
  object.rawTelemetry = reader.readString(offsets[23]);
  object.revCoolTime = reader.readLongOrNull(offsets[24]);
  object.revHeatTime = reader.readLongOrNull(offsets[25]);
  object.standbyDate = reader.readDateTimeOrNull(offsets[26]);
  object.status =
      _ChargestatusValueEnumMap[reader.readStringOrNull(offsets[27])] ??
          ChargeStatus.loaded;
  object.unloadedDate = reader.readDateTimeOrNull(offsets[28]);
  object.updatedAt = reader.readDateTime(offsets[29]);
  object.updatedBy = reader.readStringOrNull(offsets[30]);
  object.updatedDate = reader.readDateTimeOrNull(offsets[31]);
  return object;
}

P _chargeDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (_ChargebuildModeValueEnumMap[reader.readStringOrNull(offset)] ??
          BuildMode.manual) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 18:
      return (reader.readLongOrNull(offset)) as P;
    case 19:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 20:
      return (reader.readLongOrNull(offset)) as P;
    case 21:
      return (reader.readLongOrNull(offset)) as P;
    case 22:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 23:
      return (reader.readString(offset)) as P;
    case 24:
      return (reader.readLongOrNull(offset)) as P;
    case 25:
      return (reader.readLongOrNull(offset)) as P;
    case 26:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 27:
      return (_ChargestatusValueEnumMap[reader.readStringOrNull(offset)] ??
          ChargeStatus.loaded) as P;
    case 28:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 29:
      return (reader.readDateTime(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _ChargebuildModeEnumValueMap = {
  r'manual': r'manual',
  r'auto': r'auto',
};
const _ChargebuildModeValueEnumMap = {
  r'manual': BuildMode.manual,
  r'auto': BuildMode.auto,
};
const _ChargestatusEnumValueMap = {
  r'loaded': r'loaded',
  r'heat': r'heat',
  r'cool': r'cool',
  r'done': r'done',
  r'complete': r'complete',
  r'deleted': r'deleted',
};
const _ChargestatusValueEnumMap = {
  r'loaded': ChargeStatus.loaded,
  r'heat': ChargeStatus.heat,
  r'cool': ChargeStatus.cool,
  r'done': ChargeStatus.done,
  r'complete': ChargeStatus.complete,
  r'deleted': ChargeStatus.deleted,
};

Id _chargeGetId(Charge object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chargeGetLinks(Charge object) {
  return [];
}

void _chargeAttach(IsarCollection<dynamic> col, Id id, Charge object) {
  object.id = id;
}

extension ChargeByIndex on IsarCollection<Charge> {
  Future<Charge?> getByFirestoreId(String? firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  Charge? getByFirestoreIdSync(String? firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String? firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String? firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<Charge?>> getAllByFirestoreId(List<String?> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<Charge?> getAllByFirestoreIdSync(List<String?> firestoreIdValues) {
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

  Future<Id> putByFirestoreId(Charge object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(Charge object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<Charge> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(List<Charge> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }

  Future<Charge?> getByChargeNo(int chargeNo) {
    return getByIndex(r'chargeNo', [chargeNo]);
  }

  Charge? getByChargeNoSync(int chargeNo) {
    return getByIndexSync(r'chargeNo', [chargeNo]);
  }

  Future<bool> deleteByChargeNo(int chargeNo) {
    return deleteByIndex(r'chargeNo', [chargeNo]);
  }

  bool deleteByChargeNoSync(int chargeNo) {
    return deleteByIndexSync(r'chargeNo', [chargeNo]);
  }

  Future<List<Charge?>> getAllByChargeNo(List<int> chargeNoValues) {
    final values = chargeNoValues.map((e) => [e]).toList();
    return getAllByIndex(r'chargeNo', values);
  }

  List<Charge?> getAllByChargeNoSync(List<int> chargeNoValues) {
    final values = chargeNoValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'chargeNo', values);
  }

  Future<int> deleteAllByChargeNo(List<int> chargeNoValues) {
    final values = chargeNoValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'chargeNo', values);
  }

  int deleteAllByChargeNoSync(List<int> chargeNoValues) {
    final values = chargeNoValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'chargeNo', values);
  }

  Future<Id> putByChargeNo(Charge object) {
    return putByIndex(r'chargeNo', object);
  }

  Id putByChargeNoSync(Charge object, {bool saveLinks = true}) {
    return putByIndexSync(r'chargeNo', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByChargeNo(List<Charge> objects) {
    return putAllByIndex(r'chargeNo', objects);
  }

  List<Id> putAllByChargeNoSync(List<Charge> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'chargeNo', objects, saveLinks: saveLinks);
  }
}

extension ChargeQueryWhereSort on QueryBuilder<Charge, Charge, QWhere> {
  QueryBuilder<Charge, Charge, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhere> anyChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'chargeNo'),
      );
    });
  }
}

extension ChargeQueryWhere on QueryBuilder<Charge, Charge, QWhereClause> {
  QueryBuilder<Charge, Charge, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Charge, Charge, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> idBetween(
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

  QueryBuilder<Charge, Charge, QAfterWhereClause> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'firestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> firestoreIdEqualTo(
      String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> firestoreIdNotEqualTo(
      String? firestoreId) {
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

  QueryBuilder<Charge, Charge, QAfterWhereClause> chargeNoEqualTo(
      int chargeNo) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chargeNo',
        value: [chargeNo],
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> chargeNoNotEqualTo(
      int chargeNo) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chargeNo',
              lower: [],
              upper: [chargeNo],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chargeNo',
              lower: [chargeNo],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chargeNo',
              lower: [chargeNo],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chargeNo',
              lower: [],
              upper: [chargeNo],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> chargeNoGreaterThan(
    int chargeNo, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'chargeNo',
        lower: [chargeNo],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> chargeNoLessThan(
    int chargeNo, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'chargeNo',
        lower: [],
        upper: [chargeNo],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterWhereClause> chargeNoBetween(
    int lowerChargeNo,
    int upperChargeNo, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'chargeNo',
        lower: [lowerChargeNo],
        includeLower: includeLower,
        upper: [upperChargeNo],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChargeQueryFilter on QueryBuilder<Charge, Charge, QFilterCondition> {
  QueryBuilder<Charge, Charge, QAfterFilterCondition> baseNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'baseNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> baseNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'baseNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> baseNoEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'baseNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> baseNoGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'baseNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> baseNoLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'baseNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> baseNoBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'baseNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeEqualTo(
    BuildMode value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'buildMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeGreaterThan(
    BuildMode value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'buildMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeLessThan(
    BuildMode value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'buildMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeBetween(
    BuildMode lower,
    BuildMode upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'buildMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'buildMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'buildMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'buildMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'buildMode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'buildMode',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> buildModeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'buildMode',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> builtDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'builtDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> builtDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'builtDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> builtDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'builtDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> builtDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'builtDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> builtDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'builtDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> builtDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'builtDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> chargeNoEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> chargeNoGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> chargeNoLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chargeNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> chargeNoBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chargeNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coilsInBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coilsInBase',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coilsInBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coilsInBase',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coilsInBaseEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coilsInBase',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coilsInBaseGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coilsInBase',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coilsInBaseLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coilsInBase',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coilsInBaseBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coilsInBase',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coldDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coldDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coldDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coldDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coldDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coldDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coldDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coldDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coldDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coldDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coldDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coldDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coolDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'coolDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coolDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'coolDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coolDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coolDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coolDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coolDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coolDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coolDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> coolDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coolDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cycleType',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cycleType',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cycleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cycleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cycleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cycleType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cycleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cycleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cycleType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cycleType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cycleType',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> cycleTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cycleType',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> fireDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'fireDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> fireDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'fireDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> fireDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fireDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> fireDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fireDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> fireDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fireDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> fireDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fireDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdEqualTo(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdGreaterThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdLessThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdBetween(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdStartsWith(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdEndsWith(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> forceCoolerNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'forceCoolerNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> forceCoolerNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'forceCoolerNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> forceCoolerNoEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'forceCoolerNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> forceCoolerNoGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'forceCoolerNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> forceCoolerNoLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'forceCoolerNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> forceCoolerNoBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'forceCoolerNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> furnaceNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'furnaceNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> furnaceNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'furnaceNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> furnaceNoEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'furnaceNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> furnaceNoGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'furnaceNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> furnaceNoLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'furnaceNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> furnaceNoBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'furnaceNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> hasAbnormalEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasAbnormal',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> heatNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'heatNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> heatNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'heatNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> heatNoEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'heatNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> heatNoGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'heatNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> heatNoLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'heatNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> heatNoBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'heatNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> innerCoverNoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'innerCoverNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> innerCoverNoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'innerCoverNo',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> innerCoverNoEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'innerCoverNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> innerCoverNoGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'innerCoverNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> innerCoverNoLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'innerCoverNo',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> innerCoverNoBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'innerCoverNo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> isSyncedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> loadedDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'loadedDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> loadedDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'loadedDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> loadedDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'loadedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> loadedDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'loadedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> loadedDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'loadedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> loadedDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'loadedDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> numberOfCoilsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'numberOfCoils',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> numberOfCoilsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'numberOfCoils',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> numberOfCoilsEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'numberOfCoils',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> numberOfCoilsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'numberOfCoils',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> numberOfCoilsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'numberOfCoils',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> numberOfCoilsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'numberOfCoils',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> offDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'offDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> offDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'offDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> offDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'offDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> offDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'offDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> offDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'offDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> offDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'offDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predCoolTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'predCoolTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predCoolTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'predCoolTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predCoolTimeEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'predCoolTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predCoolTimeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'predCoolTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predCoolTimeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'predCoolTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predCoolTimeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'predCoolTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predHeatTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'predHeatTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predHeatTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'predHeatTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predHeatTimeEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'predHeatTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predHeatTimeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'predHeatTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predHeatTimeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'predHeatTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> predHeatTimeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'predHeatTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> purgeDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'purgeDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> purgeDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'purgeDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> purgeDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'purgeDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> purgeDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'purgeDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> purgeDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'purgeDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> purgeDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'purgeDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawTelemetry',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawTelemetry',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawTelemetry',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawTelemetry',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawTelemetry',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawTelemetry',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawTelemetry',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawTelemetry',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawTelemetry',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> rawTelemetryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawTelemetry',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revCoolTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'revCoolTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revCoolTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'revCoolTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revCoolTimeEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'revCoolTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revCoolTimeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'revCoolTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revCoolTimeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'revCoolTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revCoolTimeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'revCoolTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revHeatTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'revHeatTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revHeatTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'revHeatTime',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revHeatTimeEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'revHeatTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revHeatTimeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'revHeatTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revHeatTimeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'revHeatTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> revHeatTimeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'revHeatTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> standbyDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'standbyDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> standbyDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'standbyDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> standbyDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'standbyDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> standbyDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'standbyDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> standbyDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'standbyDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> standbyDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'standbyDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusEqualTo(
    ChargeStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusGreaterThan(
    ChargeStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusLessThan(
    ChargeStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusBetween(
    ChargeStatus lower,
    ChargeStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> unloadedDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'unloadedDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> unloadedDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'unloadedDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> unloadedDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unloadedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> unloadedDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unloadedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> unloadedDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unloadedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> unloadedDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unloadedDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedAtBetween(
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

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedBy',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedBy',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'updatedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'updatedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedBy',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedBy',
        value: '',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedDate',
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedDateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedDate',
        value: value,
      ));
    });
  }

  QueryBuilder<Charge, Charge, QAfterFilterCondition> updatedDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChargeQueryObject on QueryBuilder<Charge, Charge, QFilterCondition> {}

extension ChargeQueryLinks on QueryBuilder<Charge, Charge, QFilterCondition> {}

extension ChargeQuerySortBy on QueryBuilder<Charge, Charge, QSortBy> {
  QueryBuilder<Charge, Charge, QAfterSortBy> sortByBaseNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByBaseNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByBuildMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buildMode', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByBuildModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buildMode', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByBuiltDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'builtDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByBuiltDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'builtDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByChargeNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCoilsInBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coilsInBase', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCoilsInBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coilsInBase', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByColdDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coldDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByColdDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coldDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCoolDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coolDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCoolDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coolDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCycleType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cycleType', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByCycleTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cycleType', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByFireDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fireDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByFireDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fireDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByForceCoolerNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forceCoolerNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByForceCoolerNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forceCoolerNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByFurnaceNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'furnaceNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByFurnaceNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'furnaceNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByHasAbnormal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAbnormal', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByHasAbnormalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAbnormal', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByHeatNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heatNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByHeatNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heatNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByInnerCoverNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'innerCoverNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByInnerCoverNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'innerCoverNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByLoadedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loadedDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByLoadedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loadedDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByNumberOfCoils() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numberOfCoils', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByNumberOfCoilsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numberOfCoils', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByOffDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByOffDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByPredCoolTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predCoolTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByPredCoolTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predCoolTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByPredHeatTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predHeatTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByPredHeatTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predHeatTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByPurgeDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'purgeDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByPurgeDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'purgeDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByRawTelemetry() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawTelemetry', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByRawTelemetryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawTelemetry', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByRevCoolTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revCoolTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByRevCoolTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revCoolTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByRevHeatTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revHeatTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByRevHeatTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revHeatTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByStandbyDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'standbyDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByStandbyDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'standbyDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUnloadedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unloadedDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUnloadedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unloadedDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUpdatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUpdatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUpdatedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> sortByUpdatedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedDate', Sort.desc);
    });
  }
}

extension ChargeQuerySortThenBy on QueryBuilder<Charge, Charge, QSortThenBy> {
  QueryBuilder<Charge, Charge, QAfterSortBy> thenByBaseNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByBaseNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByBuildMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buildMode', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByBuildModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buildMode', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByBuiltDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'builtDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByBuiltDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'builtDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByChargeNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCoilsInBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coilsInBase', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCoilsInBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coilsInBase', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByColdDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coldDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByColdDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coldDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCoolDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coolDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCoolDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coolDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCycleType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cycleType', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByCycleTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cycleType', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByFireDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fireDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByFireDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fireDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByForceCoolerNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forceCoolerNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByForceCoolerNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forceCoolerNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByFurnaceNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'furnaceNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByFurnaceNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'furnaceNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByHasAbnormal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAbnormal', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByHasAbnormalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAbnormal', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByHeatNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heatNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByHeatNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heatNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByInnerCoverNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'innerCoverNo', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByInnerCoverNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'innerCoverNo', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByLoadedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loadedDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByLoadedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loadedDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByNumberOfCoils() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numberOfCoils', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByNumberOfCoilsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numberOfCoils', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByOffDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByOffDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByPredCoolTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predCoolTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByPredCoolTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predCoolTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByPredHeatTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predHeatTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByPredHeatTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'predHeatTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByPurgeDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'purgeDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByPurgeDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'purgeDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByRawTelemetry() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawTelemetry', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByRawTelemetryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawTelemetry', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByRevCoolTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revCoolTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByRevCoolTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revCoolTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByRevHeatTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revHeatTime', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByRevHeatTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revHeatTime', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByStandbyDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'standbyDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByStandbyDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'standbyDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUnloadedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unloadedDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUnloadedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unloadedDate', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUpdatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUpdatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.desc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUpdatedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedDate', Sort.asc);
    });
  }

  QueryBuilder<Charge, Charge, QAfterSortBy> thenByUpdatedDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedDate', Sort.desc);
    });
  }
}

extension ChargeQueryWhereDistinct on QueryBuilder<Charge, Charge, QDistinct> {
  QueryBuilder<Charge, Charge, QDistinct> distinctByBaseNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseNo');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByBuildMode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'buildMode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByBuiltDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'builtDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByChargeNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNo');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByCoilsInBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coilsInBase');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByColdDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coldDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByCoolDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coolDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByCycleType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cycleType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByFireDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fireDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByFirestoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByForceCoolerNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'forceCoolerNo');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByFurnaceNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'furnaceNo');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByHasAbnormal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasAbnormal');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByHeatNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heatNo');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByInnerCoverNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'innerCoverNo');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByLoadedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loadedDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByNumberOfCoils() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'numberOfCoils');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByOffDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'offDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByPredCoolTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'predCoolTime');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByPredHeatTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'predHeatTime');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByPurgeDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'purgeDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByRawTelemetry(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawTelemetry', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByRevCoolTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revCoolTime');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByRevHeatTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revHeatTime');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByStandbyDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'standbyDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByUnloadedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unloadedDate');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByUpdatedBy(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Charge, Charge, QDistinct> distinctByUpdatedDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedDate');
    });
  }
}

extension ChargeQueryProperty on QueryBuilder<Charge, Charge, QQueryProperty> {
  QueryBuilder<Charge, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> baseNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseNo');
    });
  }

  QueryBuilder<Charge, BuildMode, QQueryOperations> buildModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'buildMode');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> builtDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'builtDate');
    });
  }

  QueryBuilder<Charge, int, QQueryOperations> chargeNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNo');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> coilsInBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coilsInBase');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> coldDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coldDate');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> coolDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coolDate');
    });
  }

  QueryBuilder<Charge, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Charge, String?, QQueryOperations> cycleTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cycleType');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> fireDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fireDate');
    });
  }

  QueryBuilder<Charge, String?, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> forceCoolerNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'forceCoolerNo');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> furnaceNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'furnaceNo');
    });
  }

  QueryBuilder<Charge, bool, QQueryOperations> hasAbnormalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasAbnormal');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> heatNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heatNo');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> innerCoverNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'innerCoverNo');
    });
  }

  QueryBuilder<Charge, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> loadedDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loadedDate');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> numberOfCoilsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'numberOfCoils');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> offDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'offDate');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> predCoolTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'predCoolTime');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> predHeatTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'predHeatTime');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> purgeDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'purgeDate');
    });
  }

  QueryBuilder<Charge, String, QQueryOperations> rawTelemetryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawTelemetry');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> revCoolTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revCoolTime');
    });
  }

  QueryBuilder<Charge, int?, QQueryOperations> revHeatTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revHeatTime');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> standbyDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'standbyDate');
    });
  }

  QueryBuilder<Charge, ChargeStatus, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> unloadedDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unloadedDate');
    });
  }

  QueryBuilder<Charge, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<Charge, String?, QQueryOperations> updatedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedBy');
    });
  }

  QueryBuilder<Charge, DateTime?, QQueryOperations> updatedDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedDate');
    });
  }
}
